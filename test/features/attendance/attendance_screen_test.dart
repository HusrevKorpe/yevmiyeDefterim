/// Yoklama ekranı widget testi — satır-başına (per-tile) `.select` refaktörünü
/// doğrular: bir işçiye dokunmak durumu kaydeder ve YALNIZ o satırı günceller.
///
/// `_List` artık yoklama akışını izlemez (StatelessWidget); her satır kendi
/// kaydını `attendanceByWorkerForDateProvider.select` ile dinler. Bu test, o
/// yolun uçtan uca çalıştığını (setStatus/clearStatus tetiklenir, segment doğru
/// seçilir, çift kayıt olmaz) ve istisna atmadığını sabitler.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/core/date/app_date.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/attendance/data/field.dart';
import 'package:yevmiye_defterim/features/attendance/presentation/attendance_screen.dart';
import 'package:yevmiye_defterim/features/attendance/presentation/widgets/field_chips.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/application/fields_providers.dart';
import 'package:yevmiye_defterim/features/auth/application/user_access.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_providers.dart';
import 'package:yevmiye_defterim/features/settings/data/app_settings.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../../support/fake_attendance_repository.dart';
import '../../support/fake_field_repository.dart';
import '../../support/fake_settings_repository.dart';
import '../../support/fake_worker_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  Worker worker(String id, String name, Gender gender) => Worker(
        id: id,
        name: name,
        type: WorkerType.gundelik,
        gender: gender,
      );

  Future<(Widget, FakeAttendanceRepository)> buildApp(
      {List<Field> fields = const []}) async {
    final workerRepo = FakeWorkerRepository();
    await workerRepo.add(worker('m1', 'Ahmet', Gender.male));
    await workerRepo.add(worker('f1', 'Ayşe', Gender.female));

    final attRepo = FakeAttendanceRepository();
    final settingsRepo = FakeSettingsRepository(const AppSettings(
      defaultWageMaleKurus: 200000,
      defaultWageFemaleKurus: 180000,
      defaultCrewRateKurus: 150000,
    ));

    final app = ProviderScope(
      overrides: [
        workerRepositoryProvider.overrideWithValue(workerRepo),
        attendanceRepositoryProvider.overrideWithValue(attRepo),
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        // Tarla çipleri bu depodan beslenir; Firebase'e uzanmasın diye fake.
        fieldRepositoryProvider.overrideWithValue(FakeFieldRepository(fields)),
        // Yevmiye tutarı gösterimi bu provider'a bağlı; testte auth/Firebase'e
        // uzanmasın diye doğrudan "para görebilir" olarak sabitlenir.
        canSeeMoneyProvider.overrideWithValue(true),
      ],
      child: const MaterialApp(
        locale: Locale('tr', 'TR'),
        supportedLocales: [Locale('tr', 'TR')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: AttendanceScreen(),
      ),
    );
    return (app, attRepo);
  }

  testWidgets('bir işçiye "Tam" dokununca kayıt kaydedilir (per-tile yol)',
      (tester) async {
    final (app, attRepo) = await buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    // Erkekler sekmesi (varsayılan) açık → Ahmet satırı görünür, Ayşe değil.
    expect(find.text('Ahmet'), findsOneWidget);
    expect(find.text('Ayşe'), findsNothing);
    // Henüz hiçbir kayıt yok.
    expect(attRepo.count, 0);

    // "Tam" segmentine dokun → setStatus → tek kayıt yazılır (full).
    await tester.tap(find.text('Tam'));
    await tester.pumpAndSettle();

    expect(attRepo.count, 1);
    final rec = attRepo.all.single;
    expect(rec, isA<IndividualAttendance>());
    expect(rec.workerId, 'm1');
    expect((rec as IndividualAttendance).status, AttendanceStatus.full);
    expect(tester.takeException(), isNull);
  });

  testWidgets('aynı işçide "Yarım"a geçince kayıt ezilir (çift kayıt olmaz)',
      (tester) async {
    final (app, attRepo) = await buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yarım'));
    await tester.pumpAndSettle();

    // Deterministik ID (gün+işçi) → üzerine yazılır, tek kayıt kalır.
    expect(attRepo.count, 1);
    expect(
      (attRepo.all.single as IndividualAttendance).status,
      AttendanceStatus.half,
    );
    expect(tester.takeException(), isNull);
  });

  // --- Tarla çipleri ("kim nerede çalıştı" — isteğe bağlı seçim) ---

  testWidgets('tarla tanımlı değilse çip satırı hiç görünmez', (tester) async {
    final (app, _) = await buildApp(); // tarla yok
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tam'));
    await tester.pumpAndSettle();

    expect(find.byType(FieldChips), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tam seçilince çipler çıkar; çipe dokununca tarla kaydedilir',
      (tester) async {
    const tarla = Field(id: 't1', name: 'Aşağı Tarla');
    final (app, attRepo) = await buildApp(fields: const [tarla]);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    // Yoklama alınmamışken çip yok (durum seçilmeden tarla sorulmaz).
    expect(find.byType(FieldChips), findsNothing);

    await tester.tap(find.text('Tam'));
    await tester.pumpAndSettle();

    // Çip satırı göründü; tarla seç → kayda yazılır (ad denormalize).
    expect(find.byType(FieldChips), findsOneWidget);
    await tester.tap(find.text('Aşağı Tarla'));
    await tester.pumpAndSettle();

    expect(attRepo.count, 1); // tarla seçimi çift kayıt açmaz
    final rec = attRepo.all.single as IndividualAttendance;
    expect(rec.status, AttendanceStatus.full);
    expect(rec.fieldId, 't1');
    expect(rec.fieldName, 'Aşağı Tarla');

    // Seçili çipe tekrar dokunmak seçimi kaldırır (durum bozulmaz).
    await tester.tap(find.text('Aşağı Tarla'));
    await tester.pumpAndSettle();
    final cleared = attRepo.all.single as IndividualAttendance;
    expect(cleared.fieldId, isNull);
    expect(cleared.status, AttendanceStatus.full);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Yok" seçilince çipler gizlenir ama tarla kayıtta korunur',
      (tester) async {
    const tarla = Field(id: 't1', name: 'Aşağı Tarla');
    final (app, attRepo) = await buildApp(fields: const [tarla]);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aşağı Tarla'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yok'));
    await tester.pumpAndSettle();

    // "Yok" gününde "nerede çalıştı" sorusu anlamsız → çipler gizli; ama
    // seçim silinmez (yanlış dokunuş geri alınınca tarla kaybolmasın).
    expect(find.byType(FieldChips), findsNothing);
    final rec = attRepo.all.single as IndividualAttendance;
    expect(rec.status, AttendanceStatus.absent);
    expect(rec.fieldId, 't1');
    expect(tester.takeException(), isNull);
  });

  // --- Geçmiş gün koruması (yanlışlıkla dokunma onayı) ---

  testWidgets('geçmiş günde ilk dokunuş onay ister; Vazgeç hiçbir şey yazmaz',
      (tester) async {
    final (app, attRepo) = await buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    // Önceki güne geç → artık geçmiş bir gün seçili.
    await tester.tap(find.byTooltip('Önceki gün'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tam'));
    await tester.pumpAndSettle();

    // Onay diyaloğu çıktı, henüz hiçbir kayıt yazılmadı.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(attRepo.count, 0);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(attRepo.count, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('geçmiş günde onaylanınca yazılır ve aynı gün tekrar sorulmaz',
      (tester) async {
    final (app, attRepo) = await buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Önceki gün'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Değiştir'));
    await tester.pumpAndSettle();

    // Onaylanan değişiklik geçmiş güne (düne) yazıldı.
    expect(attRepo.count, 1);
    expect(attRepo.all.single.date, shiftIsoDate(todayIso(), -1));

    // Gün kilidi açıldı → ikinci dokunuş diyalogsuz doğrudan yazar.
    await tester.tap(find.text('Yarım'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      (attRepo.all.single as IndividualAttendance).status,
      AttendanceStatus.half,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('bugüne dokunmak onay sormaz (diyalog hiç çıkmaz)',
      (tester) async {
    final (app, attRepo) = await buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tam'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(attRepo.count, 1);
    expect(tester.takeException(), isNull);
  });
}

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
import 'package:yevmiye_defterim/features/attendance/data/job.dart';
import 'package:yevmiye_defterim/features/attendance/data/plot.dart';
import 'package:yevmiye_defterim/features/attendance/presentation/attendance_screen.dart';
import 'package:yevmiye_defterim/features/attendance/presentation/widgets/tag_chips.dart';
import 'package:yevmiye_defterim/features/attendance/presentation/widgets/overtime_chips.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/application/jobs_providers.dart';
import 'package:yevmiye_defterim/features/attendance/application/plots_providers.dart';
import 'package:yevmiye_defterim/features/auth/application/user_access.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_providers.dart';
import 'package:yevmiye_defterim/features/settings/data/app_settings.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../../support/fake_attendance_repository.dart';
import '../../support/fake_job_repository.dart';
import '../../support/fake_plot_repository.dart';
import '../../support/fake_settings_repository.dart';
import '../../support/fake_worker_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  Worker worker(String id, String name, Gender gender,
          {int? overtimeHourlyKurus}) =>
      Worker(
        id: id,
        name: name,
        type: WorkerType.gundelik,
        gender: gender,
        overtimeHourlyKurus: overtimeHourlyKurus,
      );

  Future<(Widget, FakeAttendanceRepository)> buildApp({
    List<Job> jobs = const [],
    List<Plot> plots = const [],
    int? overtimeHourlyKurus,
  }) async {
    final workerRepo = FakeWorkerRepository();
    await workerRepo.add(worker('m1', 'Ahmet', Gender.male,
        overtimeHourlyKurus: overtimeHourlyKurus));
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
        // İki çip şeridi bu depolardan beslenir; Firebase'e uzanmasın diye fake.
        jobRepositoryProvider.overrideWithValue(FakeJobRepository(jobs)),
        plotRepositoryProvider.overrideWithValue(FakePlotRepository(plots)),
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

    expect(find.byType(TagChips<Plot>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tam seçilince çipler çıkar; çipe dokununca tarla kaydedilir',
      (tester) async {
    const tarla = Plot(id: 't1', name: 'Aşağı Tarla');
    final (app, attRepo) = await buildApp(plots: const [tarla]);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    // Yoklama alınmamışken çip yok (durum seçilmeden tarla sorulmaz).
    expect(find.byType(TagChips<Plot>), findsNothing);

    await tester.tap(find.text('Tam'));
    await tester.pumpAndSettle();

    // Çip satırı göründü; tarla seç → kayda yazılır (ad denormalize).
    expect(find.byType(TagChips<Plot>), findsOneWidget);
    await tester.tap(find.text('Aşağı Tarla'));
    await tester.pumpAndSettle();

    expect(attRepo.count, 1); // tarla seçimi çift kayıt açmaz
    final rec = attRepo.all.single as IndividualAttendance;
    expect(rec.status, AttendanceStatus.full);
    expect(rec.plotId, 't1');
    expect(rec.plotName, 'Aşağı Tarla');

    // Seçili çipe tekrar dokunmak seçimi kaldırır (durum bozulmaz).
    await tester.tap(find.text('Aşağı Tarla'));
    await tester.pumpAndSettle();
    final cleared = attRepo.all.single as IndividualAttendance;
    expect(cleared.plotId, isNull);
    expect(cleared.status, AttendanceStatus.full);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iki şerit birlikte çıkar ve birbirinden bağımsız yazar',
      (tester) async {
    final (app, attRepo) = await buildApp(
      plots: const [Plot(id: 't1', name: 'Aşağı Tarla')],
      jobs: const [Job(id: 'i1', name: 'Çapa')],
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tam'));
    await tester.pumpAndSettle();

    // Tarla ve iş ayrı şeritler (2026-08-07 ayrımı).
    expect(find.byType(TagChips<Plot>), findsOneWidget);
    expect(find.byType(TagChips<Job>), findsOneWidget);

    await tester.tap(find.text('Aşağı Tarla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Çapa'));
    await tester.pumpAndSettle();

    expect(attRepo.count, 1); // iki seçim de aynı kayda gider
    final rec = attRepo.all.single as IndividualAttendance;
    expect(rec.plotId, 't1');
    expect(rec.plotName, 'Aşağı Tarla');
    expect(rec.jobId, 'i1');
    expect(rec.jobName, 'Çapa');

    // Tarlayı kaldırmak işi silmez.
    await tester.tap(find.text('Aşağı Tarla'));
    await tester.pumpAndSettle();
    final after = attRepo.all.single as IndividualAttendance;
    expect(after.plotId, isNull);
    expect(after.jobId, 'i1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('yalnız iş tanımlıysa tek şerit (iş) görünür', (tester) async {
    // Tarla listesi boş → tarla şeridi hiç çizilmez, iş şeridi çalışır.
    final (app, attRepo) =
        await buildApp(jobs: const [Job(id: 'i1', name: 'Çapa')]);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tam'));
    await tester.pumpAndSettle();

    expect(find.byType(TagChips<Plot>), findsNothing);
    expect(find.byType(TagChips<Job>), findsOneWidget);

    await tester.tap(find.text('Çapa'));
    await tester.pumpAndSettle();
    final rec = attRepo.all.single as IndividualAttendance;
    expect(rec.jobId, 'i1');
    expect(rec.plotId, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Yok" seçilince çipler gizlenir ama tarla kayıtta korunur',
      (tester) async {
    const tarla = Plot(id: 't1', name: 'Aşağı Tarla');
    final (app, attRepo) = await buildApp(plots: const [tarla]);
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
    expect(find.byType(TagChips<Plot>), findsNothing);
    final rec = attRepo.all.single as IndividualAttendance;
    expect(rec.status, AttendanceStatus.absent);
    expect(rec.plotId, 't1');
    expect(tester.takeException(), isNull);
  });

  // --- Mesai çipleri (fazla çalışma — isteğe bağlı) ---

  testWidgets('yoklama alınmadan mesai şeridi görünmez; Tam seçilince çıkar',
      (tester) async {
    final (app, _) = await buildApp(overtimeHourlyKurus: 10000);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.byType(OvertimeChips), findsNothing);

    await tester.tap(find.text('Tam'));
    await tester.pumpAndSettle();

    expect(find.byType(OvertimeChips), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"2 s" çipi: saat ve dondurulmuş saat ücreti kayda yazılır',
      (tester) async {
    final (app, attRepo) = await buildApp(overtimeHourlyKurus: 10000);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 s'));
    await tester.pumpAndSettle();

    expect(attRepo.count, 1); // mesai çift kayıt açmaz
    final rec = attRepo.all.single as IndividualAttendance;
    expect(rec.overtimeHours, 2);
    expect(rec.overtimeRateSnapshotKurus, 10000);
    expect(rec.earningKurus, 200000 + 20000);
    // Özet satırı tutarı gösterir (para görebilen hesap).
    expect(find.textContaining('2 saat mesai'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seçili saat çipine tekrar dokunmak mesaiyi kaldırır',
      (tester) async {
    final (app, attRepo) = await buildApp(overtimeHourlyKurus: 10000);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 s'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 s'));
    await tester.pumpAndSettle();

    final rec = attRepo.all.single as IndividualAttendance;
    expect(rec.overtimeHours, 0);
    expect(rec.status, AttendanceStatus.full); // durum bozulmadı
    expect(rec.earningKurus, 200000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saat ücreti girilmemişse şerit uyarır, tutar eklenmez',
      (tester) async {
    final (app, attRepo) = await buildApp(); // mesai saat ücreti yok
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 s'));
    await tester.pumpAndSettle();

    final rec = attRepo.all.single as IndividualAttendance;
    expect(rec.overtimeHours, 3);
    expect(rec.earningKurus, 200000); // mesai ₺0
    expect(find.textContaining('saat ücreti girilmemiş'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Yok" seçilince mesai şeridi gizlenir ve mesai temizlenir',
      (tester) async {
    final (app, attRepo) = await buildApp(overtimeHourlyKurus: 10000);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 s'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yok'));
    await tester.pumpAndSettle();

    // Gelmeyen işçinin mesaisi olamaz → saat sıfırlanır (görünmeyen hayalet
    // mesai ücreti kazançta kalmaz).
    expect(find.byType(OvertimeChips), findsNothing);
    final rec = attRepo.all.single as IndividualAttendance;
    expect(rec.status, AttendanceStatus.absent);
    expect(rec.overtimeHours, 0);
    expect(rec.earningKurus, 0);
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

  // --- "Kaydet" sonrası koruma (gece yarısı beklenmez) ---

  testWidgets('"Kaydet"ten sonra BUGÜNE dokunmak da onay ister', (tester) async {
    final (app, attRepo) = await buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    // Kaydetmeden önce: serbest giriş, diyalog yok.
    await tester.tap(find.text('Tam'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    // "Kaydet" → gün işaretlenir (diyalogsuz, henüz koruma yoktu).
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(attRepo.markedDays, [todayIso()]);

    // Artık bugün korumalı: sonraki değişiklik önce sorar, Vazgeç yazmaz.
    await tester.tap(find.text('Yarım'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Yoklama kaydedilmiş'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(
      (attRepo.all.single as IndividualAttendance).status,
      AttendanceStatus.full, // değişmedi
    );

    // Onaylanınca yazılır.
    await tester.tap(find.text('Yarım'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Değiştir'));
    await tester.pumpAndSettle();
    expect(
      (attRepo.all.single as IndividualAttendance).status,
      AttendanceStatus.half,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('kaydedilmiş günde kilit bir düzeltme turu açık kalır, '
      'yeniden "Kaydet" ile kapanır', (tester) async {
    final (app, attRepo) = await buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    // İlk düzeltme onaydan geçer → kilit açılır.
    await tester.tap(find.text('Yarım'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Değiştir'));
    await tester.pumpAndSettle();

    // Aynı turdaki ikinci düzeltme tekrar sormaz (diyalog yağmuru olmasın).
    await tester.tap(find.text('Tam'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      (attRepo.all.single as IndividualAttendance).status,
      AttendanceStatus.full,
    );

    // Tekrar "Kaydet" (kilit açıkken diyalog sormaz) → kilit geri kapanır.
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    // Sonraki düzeltme yeniden sorar.
    await tester.tap(find.text('Yarım'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kaydedilmiş güne yeniden "Kaydet" onay ister', (tester) async {
    final (app, attRepo) = await buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(attRepo.markedDays.length, 1);

    // İkinci "Kaydet" korumalı güne düşer → onay diyaloğu (onay butonu "Kaydet").
    await tester.tap(find.text('Kaydet').first);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(attRepo.markedDays.length, 1); // yeniden işaretlenmedi
    expect(tester.takeException(), isNull);
  });
}

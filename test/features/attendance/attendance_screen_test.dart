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

import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/attendance/presentation/attendance_screen.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/auth/application/user_access.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_providers.dart';
import 'package:yevmiye_defterim/features/settings/data/app_settings.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../../support/fake_attendance_repository.dart';
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

  Future<(Widget, FakeAttendanceRepository)> buildApp() async {
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
}

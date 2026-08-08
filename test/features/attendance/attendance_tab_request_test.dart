/// Ana Sayfa özet kartından gelen sekme isteği ([attendanceTabRequestProvider])
/// — "Kadın/Erkek/Elebaşı kartına dokun → yoklamada o grup açılsın" (2026-08-07).
///
/// İki yol da sabitlenir: Yoklama İLK KEZ açılıyorsa istek `initialIndex` olur;
/// zaten açıksa (alt sekme değişimi) sekmeye kayılır. İstek her iki durumda da
/// TÜKETİLİR → kullanıcı sekmeyi elle değiştirince geri zıplamaz.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/application/jobs_providers.dart';
import 'package:yevmiye_defterim/features/attendance/application/plots_providers.dart';
import 'package:yevmiye_defterim/features/attendance/presentation/attendance_screen.dart';
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

  Worker individual(String id, String name, Gender gender) => Worker(
        id: id,
        name: name,
        type: WorkerType.gundelik,
        gender: gender,
        dailyWageOverrideKurus: 100000,
      );

  /// Yoklama ekranını kurar. [initialTab] verilirse ekran MOUNT EDİLMEDEN önce
  /// istek yazılır (Ana Sayfa'dan gelme senaryosu).
  Future<ProviderContainer> pumpAttendance(
    WidgetTester tester, {
    AttendanceTab? initialTab,
    bool withCrew = false,
  }) async {
    final workerRepo = FakeWorkerRepository();
    await workerRepo.add(individual('m1', 'Ahmet', Gender.male));
    await workerRepo.add(individual('f1', 'Ayşe', Gender.female));
    if (withCrew) {
      await workerRepo.add(const Worker(
        id: 'c1',
        name: 'Veli Usta',
        type: WorkerType.elebasi,
        gender: Gender.male,
      ));
    }

    final container = ProviderContainer(
      overrides: [
        workerRepositoryProvider.overrideWithValue(workerRepo),
        attendanceRepositoryProvider
            .overrideWithValue(FakeAttendanceRepository()),
        settingsRepositoryProvider.overrideWithValue(
          FakeSettingsRepository(const AppSettings(
            defaultWageMaleKurus: 200000,
            defaultWageFemaleKurus: 180000,
            defaultCrewRateKurus: 150000,
          )),
        ),
        jobRepositoryProvider.overrideWithValue(FakeJobRepository(const [])),
        plotRepositoryProvider.overrideWithValue(FakePlotRepository(const [])),
        canSeeMoneyProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);

    if (initialTab != null) {
      container.read(attendanceTabRequestProvider.notifier).request(initialTab);
    }

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
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
    ));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('istek yokken varsayılan sekme Erkekler kalır', (tester) async {
    await pumpAttendance(tester);

    expect(find.text('Ahmet'), findsOneWidget);
    expect(find.text('Ayşe'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kadınlar isteğiyle açılınca ekran Kadınlar sekmesiyle gelir',
      (tester) async {
    final container =
        await pumpAttendance(tester, initialTab: AttendanceTab.females);

    expect(find.text('Ayşe'), findsOneWidget);
    expect(find.text('Ahmet'), findsNothing);
    // İstek tüketildi → sekmeyi elle değiştirince geri zıplamaz.
    expect(container.read(attendanceTabRequestProvider), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ekran zaten açıkken gelen istek sekmeyi değiştirir',
      (tester) async {
    final container = await pumpAttendance(tester);
    expect(find.text('Ahmet'), findsOneWidget);

    container
        .read(attendanceTabRequestProvider.notifier)
        .request(AttendanceTab.females);
    await tester.pumpAndSettle();

    expect(find.text('Ayşe'), findsOneWidget);
    expect(find.text('Ahmet'), findsNothing);
    expect(container.read(attendanceTabRequestProvider), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Elebaşılar isteği elebaşı sekmesini açar', (tester) async {
    final container = await pumpAttendance(
      tester,
      initialTab: AttendanceTab.crews,
      withCrew: true,
    );

    expect(find.text('Veli Usta'), findsOneWidget);
    expect(find.text('Ahmet'), findsNothing);
    expect(container.read(attendanceTabRequestProvider), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('elebaşı yokken elebaşı isteği ilk sekmede bırakır',
      (tester) async {
    // Elebaşı sekmesi hiç yok (aktif elebaşı işçi yok) → istek sessizce yutulur,
    // ekran patlamaz.
    await pumpAttendance(tester, initialTab: AttendanceTab.crews);

    expect(find.text('Ahmet'), findsOneWidget);
    expect(find.text('Elebaşılar (0)'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

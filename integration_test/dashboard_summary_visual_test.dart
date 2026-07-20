/// Görsel doğrulama: Ana Sayfa "Bugün Özeti" — para YOK; kaç işçi çalıştı,
/// kaç kadın/erkek, kaç elebaşı ve toplam kaç kişi getirdiği gösterilir.
/// Degrade "çalışan" kartındaki sayı + cinsiyet rozetleri ve kutucuklar büyük
/// sistem yazısında taşmamalı. `flutter test` gerçek font metriklerini tam
/// yakalamaz → simülatörde ekran görüntüsüyle doğrulanır.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/app/theme.dart';
import 'package:yevmiye_defterim/core/date/app_date.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/dashboard/presentation/dashboard_screen.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../test/support/fake_attendance_repository.dart';
import '../test/support/fake_worker_repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final today = todayIso();

  Worker w(String id, String name, WorkerType type, Gender gender,
          {int? headcount}) =>
      Worker(
        id: id,
        name: name,
        type: type,
        gender: gender,
        defaultHeadcount: headcount,
      );

  AttendanceRecord ind(Worker worker, AttendanceStatus status) =>
      AttendanceRecord.individual(
        id: '${today}_${worker.id}',
        date: today,
        workerId: worker.id,
        workerName: worker.name,
        workerType: worker.type,
        status: status,
        wageSnapshotKurus: 200000,
      );

  AttendanceRecord crew(Worker worker, int headcount) =>
      AttendanceRecord.crew(
        id: '${today}_${worker.id}',
        date: today,
        workerId: worker.id,
        workerName: worker.name,
        headcount: headcount,
        crewRateSnapshotKurus: 150000,
      );

  // Zengin bir gün: 3 kadın (2 tam, 1 yarım) + 3 erkek gelen (2 tam, 1 yarım)
  // + 1 erkek gelmeyen; 2 elebaşı toplam 10 kişi.
  final workers = <Worker>[
    w('f1', 'Fatma', WorkerType.gundelik, Gender.female),
    w('f2', 'Ayşe', WorkerType.sabit, Gender.female),
    w('f3', 'Zeynep', WorkerType.gundelik, Gender.female),
    w('m1', 'Ahmet', WorkerType.sabit, Gender.male),
    w('m2', 'Mehmet', WorkerType.gundelik, Gender.male),
    w('m3', 'Ali', WorkerType.gundelik, Gender.male),
    w('m4', 'Veli', WorkerType.gundelik, Gender.male),
    w('e1', 'Hasan Usta', WorkerType.elebasi, Gender.male, headcount: 6),
    w('e2', 'Mustafa Usta', WorkerType.elebasi, Gender.male, headcount: 4),
  ];

  Future<ProviderScope> app({required double scale}) async {
    final workerRepo = FakeWorkerRepository();
    for (final worker in workers) {
      await workerRepo.add(worker);
    }
    final attRepo = FakeAttendanceRepository();
    await attRepo.save(ind(workers[0], AttendanceStatus.full)); // Fatma
    await attRepo.save(ind(workers[1], AttendanceStatus.full)); // Ayşe
    await attRepo.save(ind(workers[2], AttendanceStatus.half)); // Zeynep
    await attRepo.save(ind(workers[3], AttendanceStatus.full)); // Ahmet
    await attRepo.save(ind(workers[4], AttendanceStatus.full)); // Mehmet
    await attRepo.save(ind(workers[5], AttendanceStatus.half)); // Ali
    await attRepo.save(ind(workers[6], AttendanceStatus.absent)); // Veli
    await attRepo.save(crew(workers[7], 6)); // Hasan Usta
    await attRepo.save(crew(workers[8], 4)); // Mustafa Usta

    return ProviderScope(
      overrides: [
        workerRepositoryProvider.overrideWithValue(workerRepo),
        attendanceRepositoryProvider.overrideWithValue(attRepo),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: scale,
          maxScaleFactor: scale,
          child: child!,
        ),
        home: const DashboardScreen(),
      ),
    );
  }

  testWidgets('Ana Sayfa özeti — para yok, işçi/cinsiyet/elebaşı sayıları',
      (tester) async {
    await initializeDateFormatting('tr_TR', null);

    for (final scale in const [1.0, 1.3, 2.0]) {
      await tester.pumpWidget(await app(scale: scale));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('dashboard-summary-x$scale');
    }

    // Beklenen içerik görünür; para/işçilik ifadesi görünmez.
    expect(find.text('Bugün çalışan'), findsOneWidget);
    expect(find.text('6 işçi'), findsOneWidget); // 3 kadın + 3 erkek gelen
    expect(find.text('Kadın'), findsOneWidget);
    expect(find.text('Erkek'), findsOneWidget);
    expect(find.text('2 elebaşı'), findsOneWidget);
    expect(find.text('Toplam 10 kişi getirdi'), findsOneWidget);
    expect(find.textContaining('işçilik'), findsNothing);
    expect(find.textContaining('₺'), findsNothing);

    // Hard RenderFlex taşması olmamalı.
    expect(tester.takeException(), isNull);
  });
}

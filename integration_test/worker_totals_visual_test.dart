/// Görsel doğrulama: Çalışma Özeti (takvimsiz toplam cetveli).
///
/// Aylık cetvelin sağ üstündeki tablo ikonundan açılır: her işçi tek satır —
/// ad + gün dökümü, "Gün" ve "Kazanç" sütunları, altta genel toplam. Uzun
/// isim, büyük tutar ve büyük sistem yazısında hiçbir şey taşmamalı
/// (`flutter test` gerçek font metriklerini tam yakalamaz → simülatörde
/// ekran görüntüsüyle doğrulanır).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/app/theme.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/attendance/presentation/worker_totals_screen.dart';
import 'package:yevmiye_defterim/features/auth/application/user_access.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../test/support/fake_advance_repository.dart';
import '../test/support/fake_attendance_repository.dart';
import '../test/support/fake_worker_repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Worker w(String id, String name, WorkerType type, Gender gender) =>
      Worker(id: id, name: name, type: type, gender: gender);

  AttendanceRecord ind(
    Worker worker,
    String date,
    AttendanceStatus status, {
    int wage = 200000,
    int overtimeHours = 0,
  }) =>
      AttendanceRecord.individual(
        id: '${date}_${worker.id}',
        date: date,
        workerId: worker.id,
        workerName: worker.name,
        workerType: worker.type,
        status: status,
        wageSnapshotKurus: wage,
        overtimeHours: overtimeHours,
        overtimeRateSnapshotKurus: 25000,
      );

  AttendanceRecord crew(Worker worker, String date, int headcount) =>
      AttendanceRecord.crew(
        id: '${date}_${worker.id}',
        date: date,
        workerId: worker.id,
        workerName: worker.name,
        headcount: headcount,
        crewRateSnapshotKurus: 150000,
      );

  final workers = <Worker>[
    w('s1', 'Ahmet Yılmaz', WorkerType.sabit, Gender.male),
    w('g1', 'Ayşe Kahramanoğulları', WorkerType.gundelik, Gender.female),
    w('g2', 'Mehmet Kaya', WorkerType.gundelik, Gender.male),
    w('e1', 'Hasan Usta', WorkerType.elebasi, Gender.male),
  ];

  Future<ProviderScope> app({
    required double scale,
    bool canSeeMoney = true,
  }) async {
    final workerRepo = FakeWorkerRepository();
    for (final worker in workers) {
      await workerRepo.add(worker);
    }
    final attRepo = FakeAttendanceRepository();

    // BİLEREK üç ayrı aya yayılmış kayıtlar: ekran ay seçmez, hepsini toplar.
    for (var d = 1; d <= 22; d++) {
      final date = '2026-06-${d.toString().padLeft(2, '0')}';
      await attRepo.save(ind(workers[0], date, AttendanceStatus.full,
          wage: 250000, overtimeHours: d.isEven ? 2 : 0));
    }
    for (var d = 1; d <= 18; d++) {
      final date = '2026-07-${d.toString().padLeft(2, '0')}';
      await attRepo.save(ind(workers[1], date,
          d.isOdd ? AttendanceStatus.full : AttendanceStatus.half));
    }
    for (var d = 1; d <= 7; d++) {
      final date = '2026-08-${d.toString().padLeft(2, '0')}';
      await attRepo.save(ind(workers[2], date, AttendanceStatus.full));
      await attRepo.save(crew(workers[3], date, 12 + d));
    }

    // Hesabı görülen iki işçi (uzun adlı biri dahil) → satırları yeşil şeritli,
    // alt satırda kapanış tarihi. Öteki ikisi işaretsiz kalır.
    final advRepo = FakeAdvanceRepository([
      Advance(
        id: 'adv-g1',
        workerId: 'g1',
        workerName: 'Ayşe Kahramanoğulları',
        amountKurus: 60000,
        date: '2026-07-10',
        settledPayrollId: Advance.manualSettlementId('2026-07-18'),
      ),
      Advance(
        id: 'adv-e1',
        workerId: 'e1',
        workerName: 'Hasan Usta',
        amountKurus: 120000,
        date: '2026-08-03',
        settledPayrollId: Advance.manualSettlementId('2026-08-07'),
      ),
    ]);

    return ProviderScope(
      overrides: [
        workerRepositoryProvider.overrideWithValue(workerRepo),
        attendanceRepositoryProvider.overrideWithValue(attRepo),
        advanceRepositoryProvider.overrideWithValue(advRepo),
        canSeeMoneyProvider.overrideWithValue(canSeeMoney),
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
        home: const WorkerTotalsScreen(),
      ),
    );
  }

  testWidgets('Çalışma Özeti — işçi · gün · kazanç', (tester) async {
    await initializeDateFormatting('tr_TR', null);

    for (final scale in const [1.0, 1.3, 2.0]) {
      await tester.pumpWidget(await app(scale: scale));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('worker-totals-x$scale');
    }

    expect(find.text('Çalışma Özeti'), findsOneWidget);
    expect(find.text('Gün'), findsOneWidget);
    expect(find.text('Kazanç'), findsOneWidget);
    // Ayşe: 9 tam + 9 yarım = 13,5 gün.
    expect(find.text('13,5'), findsOneWidget);
    // Hesabı görülen iki satır: onay işareti + kapanış tarihi yazısı.
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    expect(find.text('hesap görüldü • 18 Temmuz'), findsOneWidget);
    expect(find.text('hesap görüldü • 7 Ağustos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Çalışma Özeti — para kısıtlı hesap (Kazanç sütunu yok)',
      (tester) async {
    await initializeDateFormatting('tr_TR', null);

    await tester.pumpWidget(await app(scale: 1.0, canSeeMoney: false));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('worker-totals-kisitli');

    expect(find.text('Kazanç'), findsNothing);
    expect(find.textContaining('₺'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

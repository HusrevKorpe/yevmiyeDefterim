/// Faz 4 akışı — GERÇEK uygulamayı çalıştırır (router, shell, ViewModel'lar),
/// yalnız veri katmanı bellek-içi seed'li fake'lerle değiştirilir. Rapor ekranı,
/// işçi geçmişi ekranı ve ödenmiş-gün kilidi görsel olarak doğrulanır.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/app/app.dart';
import 'package:yevmiye_defterim/core/constants/categories.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/auth/application/auth_providers.dart';
import 'package:yevmiye_defterim/features/auth/data/app_user.dart';
import 'package:yevmiye_defterim/features/ledger/application/ledger_providers.dart';
import 'package:yevmiye_defterim/features/ledger/data/ledger_entry.dart';
import 'package:yevmiye_defterim/features/payroll/application/payroll_providers.dart';
import 'package:yevmiye_defterim/features/payroll/data/payroll.dart';
import 'package:yevmiye_defterim/features/reports/application/report_providers.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_providers.dart';
import 'package:yevmiye_defterim/features/settings/data/app_settings.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../test/support/fake_advance_repository.dart';
import '../test/support/fake_attendance_repository.dart';
import '../test/support/fake_auth_repository.dart';
import '../test/support/fake_ledger_repository.dart';
import '../test/support/fake_payroll_repository.dart';
import '../test/support/fake_settings_repository.dart';
import '../test/support/fake_worker_repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const ahmet = Worker(
      id: 'w1', name: 'Ahmet Yılmaz', type: WorkerType.gundelik, gender: Gender.male);
  const zehra = Worker(
      id: 'w2', name: 'Zehra Kaya', type: WorkerType.sabit, gender: Gender.female);
  const usta = Worker(
      id: 'e1', name: 'Usta Mehmet', type: WorkerType.elebasi, gender: Gender.male);

  AttendanceRecord ind(String date, AttendanceStatus s,
          {int wage = 200000, String? paid}) =>
      AttendanceRecord.individual(
        id: '${date}_w1',
        date: date,
        workerId: 'w1',
        workerName: ahmet.name,
        workerType: WorkerType.gundelik,
        status: s,
        wageSnapshotKurus: wage,
        paidPayrollId: paid,
      );

  testWidgets('Faz 4 — Rapor, işçi geçmişi ve ödenmiş-gün kilidi',
      (tester) async {
    await initializeDateFormatting('tr_TR', null);

    // İşçiler.
    final workers = FakeWorkerRepository();
    await workers.add(ahmet);
    await workers.add(zehra);
    await workers.add(usta);

    // Yoklama — Temmuz 2026; 2026-07-15 Ahmet ödenmiş (kilitli).
    final attendance = FakeAttendanceRepository();
    await attendance.save(ind('2026-07-13', AttendanceStatus.full));
    await attendance.save(ind('2026-07-14', AttendanceStatus.half));
    await attendance.save(ind('2026-07-15', AttendanceStatus.full, paid: 'pay1'));
    await attendance.save(AttendanceRecord.individual(
      id: '2026-07-13_w2',
      date: '2026-07-13',
      workerId: 'w2',
      workerName: zehra.name,
      workerType: WorkerType.sabit,
      status: AttendanceStatus.full,
      wageSnapshotKurus: 180000,
    ));
    await attendance.save(AttendanceRecord.crew(
      id: '2026-07-14_e1',
      date: '2026-07-14',
      workerId: 'e1',
      workerName: usta.name,
      headcount: 5,
      crewRateSnapshotKurus: 150000,
    ));

    // Ahmet'e açık avans.
    final advances = FakeAdvanceRepository([
      const Advance(
          id: 'a1',
          workerId: 'w1',
          workerName: 'Ahmet Yılmaz',
          amountKurus: 50000,
          date: '2026-07-10'),
    ]);

    // Ödenmiş hakediş (Ahmet, 2026-07-15).
    final payrolls = FakePayrollRepository()
      ..payrolls.add(const Payroll(
        id: 'pay1',
        workerId: 'w1',
        workerName: 'Ahmet Yılmaz',
        workerType: WorkerType.gundelik,
        periodStart: '2026-07-01',
        periodEnd: '2026-07-15',
        paidDate: '2026-07-15',
        grossKurus: 200000,
        advancesDeductedKurus: 50000,
        netPaidKurus: 150000,
      ));

    // Kasa — gelir + gider.
    final ledger = FakeLedgerRepository([
      const LedgerEntry(
          id: 'l1',
          type: LedgerType.income,
          category: LedgerCategory.genel,
          amountKurus: 1200000,
          date: '2026-07-12',
          source: LedgerSource.manual,
          note: 'Buğday satışı'),
      const LedgerEntry(
          id: 'l2',
          type: LedgerType.expense,
          category: LedgerCategory.mazot,
          amountKurus: 150000,
          date: '2026-07-10',
          source: LedgerSource.manual),
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(const AppUser(uid: 'u1', email: 'demo@ciftlik.tr')),
        ),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository(
          const AppSettings(
            defaultWageMaleKurus: 200000,
            defaultWageFemaleKurus: 180000,
            defaultCrewRateKurus: 150000,
          ),
        )),
        workerRepositoryProvider.overrideWithValue(workers),
        attendanceRepositoryProvider.overrideWithValue(attendance),
        advanceRepositoryProvider.overrideWithValue(advances),
        payrollRepositoryProvider.overrideWithValue(payrolls),
        ledgerRepositoryProvider.overrideWithValue(ledger),
      ],
      child: const YevmiyeApp(),
    ));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(YevmiyeApp)),
      listen: false,
    );
    // Deterministik dönem + yoklama günü (makine saatinden bağımsız).
    container.read(reportPeriodProvider.notifier).setStart('2026-07-01');
    container.read(reportPeriodProvider.notifier).setEnd('2026-07-31');
    container.read(selectedDateProvider.notifier).set('2026-07-15');
    await tester.pumpAndSettle();
    await binding.takeScreenshot('01-ana-sayfa');

    // Ana Sayfa app bar → Rapor.
    await tester.tap(find.byTooltip('Rapor'));
    await tester.pumpAndSettle();
    expect(find.text('Tahakkuk eden brüt'), findsOneWidget);
    await binding.takeScreenshot('02-rapor');

    // Rapordan geri dön.
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();

    // İşçiler sekmesi → Ahmet → geçmiş/detay.
    await tester.tap(find.text('İşçiler').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ahmet Yılmaz').first);
    await tester.pumpAndSettle();
    expect(find.text('Yoklama Geçmişi (3)'), findsOneWidget);
    await binding.takeScreenshot('03-isci-gecmisi');

    // İşçi detayından geri dön.
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();

    // Yoklama sekmesi → 2026-07-15. Ödeme kilidi rafta (hakediş ile birlikte):
    // "Ödendi" rozeti görünmez, ödenmiş gün de artık düzenlenebilir.
    await tester.tap(find.text('Yoklama').last);
    await tester.pumpAndSettle();
    expect(find.text('Ödendi'), findsNothing);
    await binding.takeScreenshot('04-yoklama-duzenlenebilir');
  });
}

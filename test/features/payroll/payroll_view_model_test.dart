import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/core/constants/categories.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/ledger/data/ledger_entry.dart';
import 'package:yevmiye_defterim/features/payroll/application/payroll_calculator.dart';
import 'package:yevmiye_defterim/features/payroll/application/payroll_providers.dart';
import 'package:yevmiye_defterim/features/payroll/application/payroll_view_model.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../../support/fake_advance_repository.dart';
import '../../support/fake_attendance_repository.dart';
import '../../support/fake_payroll_repository.dart';

/// "Öde" akışı: ViewModel doğru payroll + kasa gideri + avans mahsup planı +
/// ödenen gün listesini kurup depoya tek çağrı yapar (kural §4, §6).
void main() {
  AttendanceRecord ind(String date, int wage, {String? paid}) =>
      AttendanceRecord.individual(
        id: '${date}_w1',
        date: date,
        workerId: 'w1',
        workerName: 'Ahmet',
        workerType: WorkerType.gundelik,
        status: AttendanceStatus.full,
        wageSnapshotKurus: wage,
        paidPayrollId: paid,
      );

  AttendanceRecord crew(String date, int headcount) => AttendanceRecord.crew(
        id: '${date}_e1',
        date: date,
        workerId: 'e1',
        workerName: 'Usta',
        headcount: headcount,
        crewRateSnapshotKurus: 150000,
      );

  Advance adv(String id, int amount, String date) => Advance(
        id: id,
        workerId: 'w1',
        workerName: 'Ahmet',
        amountKurus: amount,
        date: date,
      );

  late FakeAttendanceRepository attendance;
  late FakeAdvanceRepository advances;
  late FakePayrollRepository payroll;
  late ProviderContainer container;

  Future<void> boot({
    required List<AttendanceRecord> att,
    List<Advance> adv = const [],
  }) async {
    attendance = FakeAttendanceRepository();
    for (final r in att) {
      await attendance.save(r);
    }
    advances = FakeAdvanceRepository(adv);
    payroll = FakePayrollRepository();
    container = ProviderContainer(overrides: [
      attendanceRepositoryProvider.overrideWithValue(attendance),
      advanceRepositoryProvider.overrideWithValue(advances),
      payrollRepositoryProvider.overrideWithValue(payroll),
    ]);
    // Dönemi sabitle (varsayılan "bu ay" gerçek tarihe bağlı olmasın).
    container.read(payrollPeriodProvider.notifier).setStart('2026-07-01');
    container.read(payrollPeriodProvider.notifier).setEnd('2026-07-31');
    container.listen(attendanceInPeriodProvider, (_, _) {});
    container.listen(advancesStreamProvider, (_, _) {});
    await container.read(attendanceInPeriodProvider.future);
    await container.read(advancesStreamProvider.future);
  }

  PayrollLine lineFor(String workerId) => container
      .read(payrollLinesProvider)
      .firstWhere((l) => l.workerId == workerId);

  PayrollViewModel vm() => container.read(payrollViewModelProvider.notifier);

  tearDown(() => container.dispose());

  test('işçi ödeme: payroll + kasa(maas) + avans kapanır + günler işaretlenir',
      () async {
    await boot(
      att: [
        ind('2026-07-01', 200000),
        ind('2026-07-02', 200000),
        ind('2026-07-03', 200000),
      ],
      adv: [adv('a1', 200000, '2026-07-02'), adv('a2', 100000, '2026-07-04')],
    );

    await vm().pay(lineFor('w1'));
    final call = payroll.lastCall!;

    expect(payroll.payCount, 1);
    expect(call.payroll.grossKurus, 600000);
    expect(call.payroll.advancesDeductedKurus, 300000);
    expect(call.payroll.netPaidKurus, 300000);
    expect(call.payroll.carryoverKurus, 0);
    expect(call.payroll.workerType, WorkerType.gundelik);

    // Kasa gideri = net, kategori maas, kaynak payroll.
    expect(call.ledgerEntry, isNotNull);
    expect(call.ledgerEntry!.type, LedgerType.expense);
    expect(call.ledgerEntry!.category, LedgerCategory.maas);
    expect(call.ledgerEntry!.amountKurus, 300000);
    expect(call.ledgerEntry!.source, LedgerSource.payroll);
    expect(call.ledgerEntry!.payrollId, call.payroll.id);

    // Her iki avans kapanır, kısmi yok.
    expect(call.settledAdvanceIds.toSet(), {'a1', 'a2'});
    expect(call.partialAdvance, isNull);

    // 3 gün işaretlenir (yalnız w1).
    expect(call.paidAttendanceIds.toSet(),
        {'2026-07-01_w1', '2026-07-02_w1', '2026-07-03_w1'});

    expect(container.read(payrollViewModelProvider).paidWorkerId, 'w1');
  });

  test('net 0: kasa gideri YAZILMAZ, sınır avansı kısmi devreder', () async {
    await boot(
      att: [ind('2026-07-01', 200000)],
      adv: [adv('a1', 300000, '2026-07-01')],
    );

    await vm().pay(lineFor('w1'));
    final call = payroll.lastCall!;

    expect(call.payroll.netPaidKurus, 0);
    expect(call.payroll.advancesDeductedKurus, 200000);
    expect(call.payroll.carryoverKurus, 100000);
    expect(call.ledgerEntry, isNull); // net 0 → gider yok
    expect(call.payroll.ledgerEntryId, isNull);
    expect(call.settledAdvanceIds, isEmpty);
    expect(call.partialAdvance?.id, 'a1');
    expect(call.partialAdvance?.remainingKurus, 100000);
  });

  test('elebaşı ödeme: kategori/kaynak elebasi, avans yok', () async {
    await boot(att: [crew('2026-07-05', 4), crew('2026-07-06', 4)]);

    await vm().pay(lineFor('e1'));
    final call = payroll.lastCall!;

    expect(call.payroll.workerType, WorkerType.elebasi);
    expect(call.payroll.grossKurus, 1200000);
    expect(call.payroll.netPaidKurus, 1200000);
    expect(call.ledgerEntry!.category, LedgerCategory.elebasi);
    expect(call.ledgerEntry!.source, LedgerSource.elebasi);
    expect(call.settledAdvanceIds, isEmpty);
    expect(call.paidAttendanceIds.toSet(), {'2026-07-05_e1', '2026-07-06_e1'});
  });

  test('zaten ödenmiş gün yeni ödemeye girmez (çifte ödeme engeli)', () async {
    await boot(att: [
      ind('2026-07-01', 200000, paid: 'p0'), // zaten ödendi
      ind('2026-07-02', 200000),
    ]);

    await vm().pay(lineFor('w1'));
    final call = payroll.lastCall!;
    expect(call.payroll.grossKurus, 200000); // yalnız ödenmemiş gün
    expect(call.paidAttendanceIds, ['2026-07-02_w1']);
  });
}

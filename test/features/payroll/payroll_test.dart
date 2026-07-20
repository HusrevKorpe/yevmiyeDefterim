import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/payroll/data/payroll.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

void main() {
  Payroll make({
    WorkerType type = WorkerType.gundelik,
    int carryover = 0,
    String? ledgerId = 'l1',
  }) =>
      Payroll(
        id: 'p1',
        workerId: 'w1',
        workerName: 'Ahmet',
        workerType: type,
        periodStart: '2026-07-01',
        periodEnd: '2026-07-15',
        paidDate: '2026-07-16',
        grossKurus: 500000,
        advancesDeductedKurus: 100000,
        netPaidKurus: 400000,
        carryoverKurus: carryover,
        ledgerEntryId: ledgerId,
      );

  test('isCrew', () {
    expect(make().isCrew, isFalse);
    expect(make(type: WorkerType.elebasi).isCrew, isTrue);
  });

  group('fromDoc / toMap', () {
    test('round-trip (işçi)', () {
      final p = make(carryover: 50000);
      expect(Payroll.fromDoc(p.id, p.toMap()), p);
    });

    test('round-trip (elebaşı, ledger null)', () {
      final p = make(type: WorkerType.elebasi, ledgerId: null);
      expect(Payroll.fromDoc(p.id, p.toMap()), p);
    });

    test('eksik alanlar güvenli varsayılana düşer', () {
      final p = Payroll.fromDoc('x', const {});
      expect(p.grossKurus, 0);
      expect(p.netPaidKurus, 0);
      expect(p.carryoverKurus, 0);
      expect(p.status, PayrollStatus.paid);
      expect(p.ledgerEntryId, isNull);
    });

    test('status her zaman paid (Faz 2)', () {
      expect(make().status, PayrollStatus.paid);
      expect(make().toMap()['status'], 'paid');
    });
  });
}

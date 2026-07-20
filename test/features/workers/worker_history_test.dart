import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/payroll/data/payroll.dart';
import 'package:yevmiye_defterim/features/workers/application/worker_history.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

/// İşçi geçmişi saf özet testleri (kural §11): gün sayıları, brüt kazanç,
/// avans (açık/toplam), ödenen net.
void main() {
  AttendanceRecord ind(String date, AttendanceStatus status, {int wage = 200000}) =>
      AttendanceRecord.individual(
        id: '${date}_w1',
        date: date,
        workerId: 'w1',
        workerName: 'Ahmet',
        workerType: WorkerType.gundelik,
        status: status,
        wageSnapshotKurus: wage,
      );

  Advance adv(int amount, String date, {String? settled}) => Advance(
        id: 'a-$date',
        workerId: 'w1',
        workerName: 'Ahmet',
        amountKurus: amount,
        date: date,
        settledPayrollId: settled,
      );

  Payroll pay(int net, String paidDate) => Payroll(
        id: 'p-$paidDate',
        workerId: 'w1',
        workerName: 'Ahmet',
        workerType: WorkerType.gundelik,
        periodStart: '2026-07-01',
        periodEnd: '2026-07-31',
        paidDate: paidDate,
        grossKurus: net,
        advancesDeductedKurus: 0,
        netPaidKurus: net,
      );

  test('boş geçmiş → tüm toplamlar sıfır', () {
    final s = buildWorkerHistorySummary(
      attendance: const [],
      advances: const [],
      payrolls: const [],
    );
    expect(s.workedDays, 0);
    expect(s.grossEarnedKurus, 0);
    expect(s.advancesTotalKurus, 0);
    expect(s.openAdvancesKurus, 0);
    expect(s.netPaidKurus, 0);
  });

  test('yoklama: tam/yarım gün sayıları + brüt kazanç (absent hariç)', () {
    final s = buildWorkerHistorySummary(
      attendance: [
        ind('2026-07-02', AttendanceStatus.full), // 200000
        ind('2026-07-03', AttendanceStatus.full), // 200000
        ind('2026-07-04', AttendanceStatus.half), // 100000
        ind('2026-07-05', AttendanceStatus.absent), // 0
      ],
      advances: const [],
      payrolls: const [],
    );
    expect(s.fullDays, 2);
    expect(s.halfDays, 1);
    expect(s.workedDays, 3); // absent sayılmaz
    expect(s.grossEarnedKurus, 500000);
  });

  test('elebaşı: kişi-gün ve gün sayısı', () {
    final s = buildWorkerHistorySummary(
      attendance: [
        AttendanceRecord.crew(
          id: '2026-07-02_e1',
          date: '2026-07-02',
          workerId: 'e1',
          workerName: 'Usta',
          headcount: 4,
          crewRateSnapshotKurus: 150000,
        ),
        AttendanceRecord.crew(
          id: '2026-07-03_e1',
          date: '2026-07-03',
          workerId: 'e1',
          workerName: 'Usta',
          headcount: 0, // gün girilmemiş → sayılmaz
          crewRateSnapshotKurus: 150000,
        ),
      ],
      advances: const [],
      payrolls: const [],
    );
    expect(s.crewDays, 1);
    expect(s.crewHeadcountTotal, 4);
    expect(s.grossEarnedKurus, 600000);
  });

  test('avans: toplam ve açık ayrı; ödenen net toplanır', () {
    final s = buildWorkerHistorySummary(
      attendance: const [],
      advances: [
        adv(50000, '2026-07-10'), // açık
        adv(30000, '2026-06-20', settled: 'p1'), // kapanmış
      ],
      payrolls: [
        pay(400000, '2026-07-15'),
        pay(200000, '2026-06-30'),
      ],
    );
    expect(s.advancesTotalKurus, 80000);
    expect(s.openAdvancesKurus, 50000);
    expect(s.netPaidKurus, 600000);
  });
}

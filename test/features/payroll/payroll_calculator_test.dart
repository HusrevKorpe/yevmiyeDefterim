import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/payroll/application/payroll_calculator.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

/// Hakediş hesabı — SAF fonksiyon testleri (kural §4, §6, §11).
/// Özellikle: avans mahsubu, negatif net → 0 + devir, kısmi mahsup, çifte
/// ödeme engeli (ödenen gün brüte katılmaz), elebaşı (avans yok).
void main() {
  AdvanceRef adv(String id, int amount, String date) =>
      AdvanceRef(id: id, amountKurus: amount, date: date);

  group('computePayroll — avans yokken', () {
    test('net = brüt, mahsup ve devir 0', () {
      final c = computePayroll(grossKurus: 200000, advances: const []);
      expect(c.netPaidKurus, 200000);
      expect(c.advancesDeductedKurus, 0);
      expect(c.carryoverKurus, 0);
      expect(c.settledAdvanceIds, isEmpty);
      expect(c.partialAdvance, isNull);
    });

    test('brüt 0 → net 0', () {
      final c = computePayroll(grossKurus: 0, advances: const []);
      expect(c.netPaidKurus, 0);
      expect(c.carryoverKurus, 0);
    });
  });

  group('computePayroll — avans < brüt (hepsi kapanır)', () {
    test('net = brüt - avans, hepsi mahsup, devir yok', () {
      final c = computePayroll(
        grossKurus: 500000,
        advances: [adv('a1', 200000, '2026-07-01'), adv('a2', 100000, '2026-07-03')],
      );
      expect(c.advancesTotalKurus, 300000);
      expect(c.advancesDeductedKurus, 300000);
      expect(c.netPaidKurus, 200000);
      expect(c.carryoverKurus, 0);
      expect(c.settledAdvanceIds, ['a1', 'a2']);
      expect(c.partialAdvance, isNull);
    });
  });

  group('computePayroll — avans = brüt', () {
    test('net 0, hepsi kapanır, devir yok, kısmi yok', () {
      final c = computePayroll(
        grossKurus: 300000,
        advances: [adv('a1', 300000, '2026-07-01')],
      );
      expect(c.netPaidKurus, 0);
      expect(c.advancesDeductedKurus, 300000);
      expect(c.carryoverKurus, 0);
      expect(c.settledAdvanceIds, ['a1']);
      expect(c.partialAdvance, isNull);
    });

    test('sınırda tam tüketim → sonraki avans kısmi olmaz, tam devreder', () {
      // brüt 300000; a1 tam kapanır, a2 hiç dokunulmaz (tam devreder).
      final c = computePayroll(
        grossKurus: 300000,
        advances: [adv('a1', 300000, '2026-07-01'), adv('a2', 100000, '2026-07-02')],
      );
      expect(c.netPaidKurus, 0);
      expect(c.advancesDeductedKurus, 300000);
      expect(c.settledAdvanceIds, ['a1']);
      expect(c.partialAdvance, isNull);
      expect(c.carryoverKurus, 100000); // a2 tümü devreder
    });
  });

  group('computePayroll — avans > brüt (negatif → net 0 + devir)', () {
    test('kalan avans devreder, net 0 (plan §4)', () {
      final c = computePayroll(
        grossKurus: 200000,
        advances: [adv('a1', 200000, '2026-07-01'), adv('a2', 100000, '2026-07-03')],
      );
      expect(c.netPaidKurus, 0);
      expect(c.advancesDeductedKurus, 200000);
      expect(c.carryoverKurus, 100000);
      expect(c.settledAdvanceIds, ['a1']);
      expect(c.partialAdvance, isNull); // a2 tümü devreder
    });

    test('tek büyük avans → kısmi mahsup, kalan tutar devreder', () {
      final c = computePayroll(
        grossKurus: 250000,
        advances: [adv('a1', 300000, '2026-07-01')],
      );
      expect(c.netPaidKurus, 0);
      expect(c.advancesDeductedKurus, 250000);
      expect(c.carryoverKurus, 50000);
      expect(c.settledAdvanceIds, isEmpty);
      expect(c.partialAdvance?.id, 'a1');
      expect(c.partialAdvance?.remainingKurus, 50000);
    });

    test('bir avans kapanır + biri kısmi', () {
      // brüt 250000; a1 (200000) kapanır, a2 (100000) 50000 kısmi mahsup.
      final c = computePayroll(
        grossKurus: 250000,
        advances: [adv('a1', 200000, '2026-07-01'), adv('a2', 100000, '2026-07-02')],
      );
      expect(c.advancesDeductedKurus, 250000);
      expect(c.netPaidKurus, 0);
      expect(c.settledAdvanceIds, ['a1']);
      expect(c.partialAdvance?.id, 'a2');
      expect(c.partialAdvance?.remainingKurus, 50000);
      expect(c.carryoverKurus, 50000);
    });

    test('brüt 0 ama açık avans var → mahsup 0, tümü devreder', () {
      final c = computePayroll(
        grossKurus: 0,
        advances: [adv('a1', 100000, '2026-07-01')],
      );
      expect(c.netPaidKurus, 0);
      expect(c.advancesDeductedKurus, 0);
      expect(c.carryoverKurus, 100000);
      expect(c.settledAdvanceIds, isEmpty);
      expect(c.partialAdvance, isNull);
    });
  });

  group('computePayroll — mahsup eskiden yeniye', () {
    test('sırasız gelen avanslar tarihe göre (eski önce) kapanır', () {
      // brüt yalnız en eskisini karşılar → eski kapanır, yeni devreder.
      final c = computePayroll(
        grossKurus: 100000,
        advances: [adv('yeni', 100000, '2026-07-10'), adv('eski', 100000, '2026-07-01')],
      );
      expect(c.settledAdvanceIds, ['eski']); // eski önce mahsup
      expect(c.carryoverKurus, 100000); // yeni devreder
    });
  });

  // --- buildPayrollLines ---

  AttendanceRecord ind(
    String workerId,
    String name,
    String date,
    AttendanceStatus status,
    int wage, {
    WorkerType type = WorkerType.gundelik,
    String? paidPayrollId,
  }) =>
      AttendanceRecord.individual(
        id: '${date}_$workerId',
        date: date,
        workerId: workerId,
        workerName: name,
        workerType: type,
        status: status,
        wageSnapshotKurus: wage,
        paidPayrollId: paidPayrollId,
      );

  AttendanceRecord crew(
    String workerId,
    String name,
    String date,
    int headcount,
    int rate, {
    String? paidPayrollId,
  }) =>
      AttendanceRecord.crew(
        id: '${date}_$workerId',
        date: date,
        workerId: workerId,
        workerName: name,
        headcount: headcount,
        crewRateSnapshotKurus: rate,
        paidPayrollId: paidPayrollId,
      );

  Advance advance(String id, String workerId, int amount, String date,
          {String? settled}) =>
      Advance(
        id: id,
        workerId: workerId,
        workerName: workerId,
        amountKurus: amount,
        date: date,
        settledPayrollId: settled,
      );

  group('buildPayrollLines — brüt toplama', () {
    test('karışık tam/yarım günler toplanır; yok günü katmaz', () {
      final lines = buildPayrollLines(
        periodStart: '2026-07-01',
        periodEnd: '2026-07-31',
        attendance: [
          ind('w1', 'Ahmet', '2026-07-01', AttendanceStatus.full, 200000),
          ind('w1', 'Ahmet', '2026-07-02', AttendanceStatus.half, 200000),
          ind('w1', 'Ahmet', '2026-07-03', AttendanceStatus.absent, 200000),
        ],
        advances: const [],
      );
      expect(lines, hasLength(1));
      final l = lines.single;
      expect(l.fullDays, 1);
      expect(l.halfDays, 1);
      expect(l.grossKurus, 300000); // 200000 + 100000
      expect(l.netPaidKurus, 300000);
    });

    test('brütü 0 olan işçi (hep yok) listelenmez', () {
      final lines = buildPayrollLines(
        periodStart: '2026-07-01',
        periodEnd: '2026-07-31',
        attendance: [
          ind('w1', 'Ahmet', '2026-07-01', AttendanceStatus.absent, 200000),
        ],
        advances: const [],
      );
      expect(lines, isEmpty);
    });

    test('dönem dışı kayıtlar hariç', () {
      final lines = buildPayrollLines(
        periodStart: '2026-07-08',
        periodEnd: '2026-07-14',
        attendance: [
          ind('w1', 'Ahmet', '2026-07-01', AttendanceStatus.full, 200000), // dışı
          ind('w1', 'Ahmet', '2026-07-10', AttendanceStatus.full, 200000), // içi
        ],
        advances: const [],
      );
      expect(lines.single.grossKurus, 200000);
    });
  });

  group('buildPayrollLines — çifte ödeme engeli', () {
    test('ödenmiş (paidPayrollId dolu) gün brüte katılmaz', () {
      final lines = buildPayrollLines(
        periodStart: '2026-07-01',
        periodEnd: '2026-07-31',
        attendance: [
          ind('w1', 'Ahmet', '2026-07-01', AttendanceStatus.full, 200000,
              paidPayrollId: 'p0'), // zaten ödendi
          ind('w1', 'Ahmet', '2026-07-02', AttendanceStatus.full, 200000),
        ],
        advances: const [],
      );
      expect(lines.single.grossKurus, 200000); // yalnız ödenmemiş gün
    });

    test('tüm günler ödenmişse işçi listelenmez', () {
      final lines = buildPayrollLines(
        periodStart: '2026-07-01',
        periodEnd: '2026-07-31',
        attendance: [
          ind('w1', 'Ahmet', '2026-07-01', AttendanceStatus.full, 200000,
              paidPayrollId: 'p0'),
        ],
        advances: const [],
      );
      expect(lines, isEmpty);
    });
  });

  group('buildPayrollLines — avans filtreleme', () {
    test('kapanmış avans mahsup edilmez', () {
      final lines = buildPayrollLines(
        periodStart: '2026-07-01',
        periodEnd: '2026-07-31',
        attendance: [
          ind('w1', 'Ahmet', '2026-07-01', AttendanceStatus.full, 200000),
        ],
        advances: [
          advance('a1', 'w1', 100000, '2026-07-01', settled: 'p0'), // kapanmış
        ],
      );
      expect(lines.single.advancesDeductedKurus, 0);
      expect(lines.single.netPaidKurus, 200000);
    });

    test('dönem sonundan sonraki avans mahsup edilmez', () {
      final lines = buildPayrollLines(
        periodStart: '2026-07-01',
        periodEnd: '2026-07-15',
        attendance: [
          ind('w1', 'Ahmet', '2026-07-01', AttendanceStatus.full, 200000),
        ],
        advances: [
          advance('a1', 'w1', 100000, '2026-07-20'), // dönem sonrası
        ],
      );
      expect(lines.single.advancesDeductedKurus, 0);
      expect(lines.single.netPaidKurus, 200000);
    });

    test('dönem öncesi açık avans (devir) mahsup edilir', () {
      final lines = buildPayrollLines(
        periodStart: '2026-07-08',
        periodEnd: '2026-07-14',
        attendance: [
          ind('w1', 'Ahmet', '2026-07-10', AttendanceStatus.full, 200000),
        ],
        advances: [
          advance('a1', 'w1', 100000, '2026-07-01'), // dönemden önce, açık
        ],
      );
      expect(lines.single.advancesDeductedKurus, 100000);
      expect(lines.single.netPaidKurus, 100000);
    });
  });

  group('buildPayrollLines — elebaşı', () {
    test('elebaşı: avans uygulanmaz, net = brüt, gün/kişi sayılır', () {
      final lines = buildPayrollLines(
        periodStart: '2026-07-01',
        periodEnd: '2026-07-31',
        attendance: [
          crew('e1', 'Usta', '2026-07-01', 5, 150000),
          crew('e1', 'Usta', '2026-07-02', 3, 150000),
          crew('e1', 'Usta', '2026-07-03', 0, 150000), // kişi 0 → gün sayılmaz
        ],
        advances: [
          // Elebaşıya avans olmamalı; olsa bile mahsup edilmez.
          advance('a1', 'e1', 100000, '2026-07-01'),
        ],
      );
      final l = lines.single;
      expect(l.isCrew, isTrue);
      expect(l.crewDays, 2); // kişi>0 olan günler
      expect(l.crewHeadcountTotal, 8);
      expect(l.grossKurus, 1200000); // (5+3)*150000
      expect(l.advancesDeductedKurus, 0);
      expect(l.netPaidKurus, 1200000);
    });
  });

  group('buildPayrollLines — sıralama', () {
    test('bireysel işçiler önce (ada göre), elebaşılar sonra', () {
      final lines = buildPayrollLines(
        periodStart: '2026-07-01',
        periodEnd: '2026-07-31',
        attendance: [
          crew('e1', 'Usta', '2026-07-01', 2, 150000),
          ind('w2', 'Zehra', '2026-07-01', AttendanceStatus.full, 180000),
          ind('w1', 'Ahmet', '2026-07-01', AttendanceStatus.full, 200000),
        ],
        advances: const [],
      );
      expect(lines.map((l) => l.workerName).toList(),
          ['Ahmet', 'Zehra', 'Usta']);
    });
  });

  group('buildPayrollLines — devir zinciri (dönemler arası)', () {
    test('1. dönem kısmi/kapanma → 2. dönem kalanı mahsup eder', () {
      // 1. dönem: brüt 200000, avans a1=200000 + a2=100000 → a1 kapanır,
      // a2 (100000) tümü devreder.
      final p1 = buildPayrollLines(
        periodStart: '2026-07-01',
        periodEnd: '2026-07-07',
        attendance: [
          ind('w1', 'Ahmet', '2026-07-02', AttendanceStatus.full, 200000),
        ],
        advances: [
          advance('a1', 'w1', 200000, '2026-07-01'),
          advance('a2', 'w1', 100000, '2026-07-03'),
        ],
      ).single;
      expect(p1.computation.settledAdvanceIds, ['a1']);
      expect(p1.carryoverKurus, 100000);
      expect(p1.netPaidKurus, 0);

      // Ödeme sonrası: a1 kapandı, a2 açık kaldı, 1. dönem günü ödendi.
      // 2. dönem: yeni bir gün, a2 (100000) mahsup edilir.
      final p2 = buildPayrollLines(
        periodStart: '2026-07-08',
        periodEnd: '2026-07-14',
        attendance: [
          ind('w1', 'Ahmet', '2026-07-02', AttendanceStatus.full, 200000,
              paidPayrollId: 'p1'), // 1. dönemde ödendi
          ind('w1', 'Ahmet', '2026-07-10', AttendanceStatus.full, 200000),
        ],
        advances: [
          advance('a1', 'w1', 200000, '2026-07-01', settled: 'p1'), // kapandı
          advance('a2', 'w1', 100000, '2026-07-03'), // açık, devreden
        ],
      ).single;
      expect(p2.grossKurus, 200000); // yalnız ödenmemiş gün
      expect(p2.advancesDeductedKurus, 100000); // a2 mahsup
      expect(p2.netPaidKurus, 100000);
      expect(p2.computation.settledAdvanceIds, ['a2']);
      expect(p2.carryoverKurus, 0);
    });
  });
}

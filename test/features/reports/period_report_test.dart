import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/core/constants/categories.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/ledger/data/ledger_entry.dart';
import 'package:yevmiye_defterim/features/reports/application/period_report.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

/// Dönem raporu saf builder testleri (kural §11). Kasa/işçilik ayrı metrikler,
/// aralık süzme, işçi bazında döküm ve sıralama.
void main() {
  const start = '2026-07-01';
  const end = '2026-07-31';

  AttendanceRecord ind(
    String worker,
    String date,
    AttendanceStatus status, {
    int wage = 200000,
    Gender gender = Gender.male,
    String? paidPayrollId,
    String? jobId,
    String? jobName,
  }) =>
      AttendanceRecord.individual(
        id: '${date}_$worker',
        date: date,
        workerId: worker,
        workerName: worker,
        workerType: WorkerType.gundelik,
        status: status,
        wageSnapshotKurus: wage,
        paidPayrollId: paidPayrollId,
        jobId: jobId,
        jobName: jobName,
      );

  AttendanceRecord crew(String worker, String date, int headcount,
          {int rate = 150000}) =>
      AttendanceRecord.crew(
        id: '${date}_$worker',
        date: date,
        workerId: worker,
        workerName: worker,
        headcount: headcount,
        crewRateSnapshotKurus: rate,
      );

  LedgerEntry ledger(String category, int amount, String date,
          {String source = LedgerSource.manual}) =>
      LedgerEntry(
        id: '$date-$category-$amount',
        category: category,
        amountKurus: amount,
        date: date,
        source: source,
      );

  Advance advance(String worker, int amount, String date) => Advance(
        id: '$worker-$date',
        workerId: worker,
        workerName: worker,
        amountKurus: amount,
        date: date,
      );

  PeriodReport build({
    List<AttendanceRecord> attendance = const [],
    List<Advance> advances = const [],
    List<LedgerEntry> ledgerEntries = const [],
  }) =>
      buildPeriodReport(
        startIso: start,
        endIso: end,
        attendance: attendance,
        advances: advances,
        ledger: ledgerEntries,
      );

  test('boş girdi → isEmpty', () {
    final r = build();
    expect(r.isEmpty, isTrue);
    expect(r.expenseKurus, 0);
    expect(r.workerEarnings, isEmpty);
  });

  test('kasa: toplam gider + kategori kırılımı + mazot/tamir/bakkal', () {
    final r = build(ledgerEntries: [
      ledger(LedgerCategory.mazot, 120000, '2026-07-06'),
      ledger(LedgerCategory.tamir, 50000, '2026-07-06'),
      ledger(LedgerCategory.bakkal, 30000, '2026-07-07'),
      ledger(LedgerCategory.genel, 80000, '2026-07-07'),
    ]);
    expect(r.expenseKurus, 280000);
    expect(r.mazotKurus, 120000);
    expect(r.tamirKurus, 50000);
    expect(r.bakkalKurus, 30000);
    expect(r.expenseByCategory[LedgerCategory.genel], 80000);
  });

  test('kasa: tahsilat rapor toplamlarına girmez (çifte sayım olmaz)', () {
    final r = build(ledgerEntries: [
      ledger(LedgerCategory.mazot, 120000, '2026-07-06'),
      // 50.000 TL önden verilen para — yalnız kategori ekranı bakiyesi.
      ledger(LedgerCategory.mazot, 5000000, '2026-07-05')
          .copyWith(kind: LedgerKind.tahsilat),
    ]);
    expect(r.expenseKurus, 120000);
    expect(r.mazotKurus, 120000);
  });

  test('işçilik brütü = dönemdeki tüm yoklama kazançları (tam+yarım+elebaşı)',
      () {
    final r = build(attendance: [
      ind('a', '2026-07-02', AttendanceStatus.full), // 200000
      ind('a', '2026-07-03', AttendanceStatus.half), // 100000
      crew('e', '2026-07-02', 4), // 600000
    ]);
    expect(r.grossLaborKurus, 900000);
  });

  test('işçi bazında döküm: gün sayıları, kişi-gün, brütle azalan sıralama', () {
    final r = build(attendance: [
      ind('a', '2026-07-02', AttendanceStatus.full),
      ind('a', '2026-07-03', AttendanceStatus.full),
      ind('a', '2026-07-04', AttendanceStatus.half),
      ind('b', '2026-07-02', AttendanceStatus.full),
      crew('e', '2026-07-02', 3),
      crew('e', '2026-07-03', 5),
    ]);
    // Sıralama brüte göre: e=1.2M, a=500k, b=200k
    expect(r.workerEarnings.map((w) => w.workerId).toList(), ['e', 'a', 'b']);

    final a = r.workerEarnings.firstWhere((w) => w.workerId == 'a');
    expect(a.fullDays, 2);
    expect(a.halfDays, 1);
    expect(a.grossKurus, 500000);

    final e = r.workerEarnings.firstWhere((w) => w.workerId == 'e');
    expect(e.isCrew, isTrue);
    expect(e.crewDays, 2);
    expect(e.crewHeadcountTotal, 8);
    expect(e.grossKurus, 1200000);
  });

  test('sürekli gelmeyen (absent) işçi dökümde görünmez', () {
    final r = build(attendance: [
      ind('a', '2026-07-02', AttendanceStatus.absent),
      ind('a', '2026-07-03', AttendanceStatus.absent),
    ]);
    expect(r.workerEarnings, isEmpty);
    expect(r.grossLaborKurus, 0);
  });

  test('avans: yalnız dönem içindeki tarihler toplanır', () {
    final r = build(advances: [
      advance('a', 50000, '2026-07-10'), // içeride
      advance('a', 30000, '2026-06-25'), // dönem dışı
      advance('b', 20000, '2026-07-31'), // sınır (dahil)
    ]);
    expect(r.advancesGivenKurus, 70000);
  });

  test('avans: devir (carryover) "Verilen avans"a girmez (çifte sayım yok)', () {
    final r = build(advances: [
      advance('a', 50000, '2026-07-10'), // gerçek nakit avans
      Advance(
        id: Advance.carryoverId('2026-07-20', 'u1'), // 'devir-...'
        workerId: 'a',
        workerName: 'a',
        amountKurus: 30000,
        date: '2026-07-20', // dönem içi ama gerçek nakit değil
        note: 'Önceki hesaptan devir',
      ),
    ]);
    expect(r.advancesGivenKurus, 50000,
        reason: 'devir kaydı gerçek nakit değil; kapanıştan taşınan bakiye');
  });

  test('aralık dışı yoklama süzülür (grösse ve dökümden çıkar)', () {
    final r = build(attendance: [
      ind('a', '2026-07-02', AttendanceStatus.full), // içeride
      ind('a', '2026-08-05', AttendanceStatus.full), // dönem dışı
    ]);
    expect(r.grossLaborKurus, 200000);
    expect(r.workerEarnings.single.fullDays, 1);
  });

  test('tarla kırılımı toplamı = dönem işçilik brütü (para kaybolmaz)', () {
    final r = build(attendance: [
      ind('a', '2026-07-02', AttendanceStatus.full,
          jobId: 'f1', jobName: 'Dere'),
      ind('b', '2026-07-02', AttendanceStatus.half), // tarlasız
      crew('e', '2026-07-03', 4),
    ]);
    expect(r.hasWorkCosts, isTrue);
    final toplam =
        r.jobCosts.fold<int>(0, (sum, f) => sum + f.grossKurus);
    expect(toplam, r.grossLaborKurus);
  });

  test('hiç tarla seçilmemişse hasWorkCosts false (bölüm gizlenir)', () {
    final r = build(attendance: [
      ind('a', '2026-07-02', AttendanceStatus.full),
    ]);
    expect(r.jobCosts.single.isUnassigned, isTrue);
    expect(r.hasWorkCosts, isFalse);
  });

  test('ödenmiş gün de brüt işçiliğe dahildir (tahakkuk metriği)', () {
    // grossLabor tahakkuktur; ödeme durumundan bağımsız (kasa ayrı metrik).
    final r = build(attendance: [
      ind('a', '2026-07-02', AttendanceStatus.full, paidPayrollId: 'p1'),
    ]);
    expect(r.grossLaborKurus, 200000);
  });

  group('mesai kırılımı (brütün içinde, ayrıca gösterilir)', () {
    AttendanceRecord withOvertime(
      String worker,
      String date, {
      AttendanceStatus status = AttendanceStatus.full,
      int hours = 0,
      int rate = 10000,
    }) =>
        AttendanceRecord.individual(
          id: '${date}_$worker',
          date: date,
          workerId: worker,
          workerName: worker,
          workerType: WorkerType.gundelik,
          status: status,
          wageSnapshotKurus: 200000,
          overtimeHours: hours,
          overtimeRateSnapshotKurus: rate,
        );

    test('mesai brüte eklenir ve ayrı toplamda da görünür', () {
      final r = build(attendance: [
        withOvertime('a', '2026-07-02', hours: 2), // 200000 + 20000
        withOvertime('b', '2026-07-02', hours: 3), // 200000 + 30000
      ]);
      expect(r.grossLaborKurus, 450000);
      expect(r.overtimeKurus, 50000);
      expect(r.overtimeHours, 5);
      expect(r.hasOvertime, isTrue);
    });

    test('işçi dökümünde mesai saati/tutarı işçi bazında toplanır', () {
      final r = build(attendance: [
        withOvertime('a', '2026-07-02', hours: 2),
        withOvertime('a', '2026-07-03', hours: 1),
        ind('b', '2026-07-02', AttendanceStatus.full),
      ]);
      final a = r.workerEarnings.firstWhere((e) => e.workerId == 'a');
      final b = r.workerEarnings.firstWhere((e) => e.workerId == 'b');
      expect(a.overtimeHours, 3);
      expect(a.overtimeKurus, 30000);
      expect(a.grossKurus, 400000 + 30000); // brüt mesai dahil
      expect(b.overtimeHours, 0);
      expect(b.overtimeKurus, 0);
    });

    test('"Yok" günündeki mesai sayılmaz', () {
      final r = build(attendance: [
        withOvertime('a', '2026-07-02',
            status: AttendanceStatus.absent, hours: 4),
      ]);
      expect(r.grossLaborKurus, 0);
      expect(r.overtimeKurus, 0);
      expect(r.overtimeHours, 0);
      expect(r.hasOvertime, isFalse);
    });

    test('dönem dışı mesai süzülür', () {
      final r = build(attendance: [
        withOvertime('a', '2026-06-30', hours: 5), // dönem dışı
        withOvertime('a', '2026-07-02', hours: 1),
      ]);
      expect(r.overtimeHours, 1);
      expect(r.overtimeKurus, 10000);
    });

    test('mesai girilmemişse hasOvertime false (kırılım satırı gizlenir)', () {
      final r = build(attendance: [
        ind('a', '2026-07-02', AttendanceStatus.full),
        crew('e', '2026-07-02', 4),
      ]);
      expect(r.hasOvertime, isFalse);
      expect(r.overtimeKurus, 0);
    });

    test('mesai tarla maliyetine de girer (tarla toplamı brüte eşit kalır)', () {
      final r = build(attendance: [
        AttendanceRecord.individual(
          id: '2026-07-02_a',
          date: '2026-07-02',
          workerId: 'a',
          workerName: 'a',
          workerType: WorkerType.gundelik,
          status: AttendanceStatus.full,
          wageSnapshotKurus: 200000,
          overtimeHours: 2,
          overtimeRateSnapshotKurus: 10000,
          jobId: 't1',
          jobName: 'Aşağı Tarla',
        ),
      ]);
      final toplam =
          r.jobCosts.fold<int>(0, (sum, f) => sum + f.grossKurus);
      expect(toplam, r.grossLaborKurus);
      expect(toplam, 220000);
    });
  });
}

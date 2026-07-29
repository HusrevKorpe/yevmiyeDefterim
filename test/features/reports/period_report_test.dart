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
    String? fieldId,
    String? fieldName,
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
        fieldId: fieldId,
        fieldName: fieldName,
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
          fieldId: 'f1', fieldName: 'Dere'),
      ind('b', '2026-07-02', AttendanceStatus.half), // tarlasız
      crew('e', '2026-07-03', 4),
    ]);
    expect(r.hasFieldCosts, isTrue);
    final toplam =
        r.fieldCosts.fold<int>(0, (sum, f) => sum + f.grossKurus);
    expect(toplam, r.grossLaborKurus);
  });

  test('hiç tarla seçilmemişse hasFieldCosts false (bölüm gizlenir)', () {
    final r = build(attendance: [
      ind('a', '2026-07-02', AttendanceStatus.full),
    ]);
    expect(r.fieldCosts.single.isUnassigned, isTrue);
    expect(r.hasFieldCosts, isFalse);
  });

  test('ödenmiş gün de brüt işçiliğe dahildir (tahakkuk metriği)', () {
    // grossLabor tahakkuktur; ödeme durumundan bağımsız (kasa ayrı metrik).
    final r = build(attendance: [
      ind('a', '2026-07-02', AttendanceStatus.full, paidPayrollId: 'p1'),
    ]);
    expect(r.grossLaborKurus, 200000);
  });
}

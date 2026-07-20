/// Hakediş hesabı — SAF fonksiyon (Firestore'suz → unit test, kural §4, §11).
///
/// - Brüt = Σ yoklama snapshot kazançları (geçmiş ücret yeniden türetilmez).
/// - Avans mahsubu **eskiden yeniye** (tarih, sonra id): dönemde kapatılabilen
///   avanslar mahsup edilir.
/// - `net = max(0, brüt - avans)`. Avans brütü aşarsa net=0, kalan avans bir
///   sonraki döneme **devreder** (plan §4).
/// - Sınırdaki avans **kısmi** mahsup edilir; kalan tutarı devreder.
/// - Elebaşı: avans/yarım gün/cinsiyet yok → net = brüt (kural §10).
library;

import '../../advances/data/advance.dart';
import '../../attendance/data/attendance_record.dart';
import '../../workers/data/worker.dart';

/// Bir avansın hesaplayıcıya giren sade görünümü (id + tutar + tarih).
class AdvanceRef {
  const AdvanceRef({
    required this.id,
    required this.amountKurus,
    required this.date,
  });

  final String id;
  final int amountKurus;
  final String date; // 'yyyy-MM-dd'
}

/// Bir işçi için hesaplanan hakediş sonucu (henüz ödenmedi).
class PayrollComputation {
  const PayrollComputation({
    required this.grossKurus,
    required this.advancesTotalKurus,
    required this.advancesDeductedKurus,
    required this.netPaidKurus,
    required this.carryoverKurus,
    required this.settledAdvanceIds,
    required this.partialAdvance,
  });

  /// Dönemde hak edilen brüt (kuruş).
  final int grossKurus;

  /// Kapatılabilir avansların toplamı (kuruş).
  final int advancesTotalKurus;

  /// Bu ödemede fiilen mahsup edilen avans (kuruş) = min(brüt, avansToplam).
  final int advancesDeductedKurus;

  /// Fiilen ödenen net (kuruş) = max(0, brüt - avansToplam).
  final int netPaidKurus;

  /// Bu dönemde kapatılamayıp devreden avans kalanı (kuruş).
  final int carryoverKurus;

  /// Tamamen kapanan (mahsup edilen) avans ID'leri → `settledPayrollId` yazılır.
  final List<String> settledAdvanceIds;

  /// Sınırdaki kısmi avans: tutarı [remainingKurus]'a düşürülür, kapanmaz
  /// (kalan devreder). Yoksa null.
  final ({String id, int remainingKurus})? partialAdvance;
}

/// Tek işçinin hakedişini hesaplar. [advances] kapatılabilir (kapanmamış,
/// tarih ≤ dönem sonu) avanslar; sıra içeride eskiden yeniye kurulur.
PayrollComputation computePayroll({
  required int grossKurus,
  required List<AdvanceRef> advances,
}) {
  assert(grossKurus >= 0, 'Brüt negatif olamaz');

  final sorted = [...advances]..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });

  final total = sorted.fold<int>(0, (sum, a) => sum + a.amountKurus);
  final deducted = grossKurus < total ? grossKurus : total;

  final settled = <String>[];
  ({String id, int remainingKurus})? partial;
  var remaining = deducted;
  for (final a in sorted) {
    if (remaining <= 0) break;
    if (remaining >= a.amountKurus) {
      // Tamamen mahsup edildi → kapanır.
      settled.add(a.id);
      remaining -= a.amountKurus;
    } else {
      // Kısmen mahsup edildi → kalanı devreder (tutarı düşürülür, kapanmaz).
      partial = (id: a.id, remainingKurus: a.amountKurus - remaining);
      remaining = 0;
    }
  }

  return PayrollComputation(
    grossKurus: grossKurus,
    advancesTotalKurus: total,
    advancesDeductedKurus: deducted,
    netPaidKurus: grossKurus - deducted,
    carryoverKurus: total - deducted,
    settledAdvanceIds: settled,
    partialAdvance: partial,
  );
}

/// Bir işçinin/elebaşının dönem hakediş satırı (ekranda gösterilir, ödenmemiş).
class PayrollLine {
  const PayrollLine({
    required this.workerId,
    required this.workerName,
    required this.workerType,
    required this.fullDays,
    required this.halfDays,
    required this.crewDays,
    required this.crewHeadcountTotal,
    required this.computation,
  });

  final String workerId;
  final String workerName;
  final WorkerType workerType;

  /// Bireysel: tam gün sayısı.
  final int fullDays;

  /// Bireysel: yarım gün sayısı.
  final int halfDays;

  /// Elebaşı: kişi sayısı > 0 olan gün sayısı.
  final int crewDays;

  /// Elebaşı: toplam kişi-gün.
  final int crewHeadcountTotal;

  final PayrollComputation computation;

  bool get isCrew => workerType == WorkerType.elebasi;
  int get grossKurus => computation.grossKurus;
  int get advancesDeductedKurus => computation.advancesDeductedKurus;
  int get netPaidKurus => computation.netPaidKurus;
  int get carryoverKurus => computation.carryoverKurus;
}

/// Dönem hakediş satırlarını kurar (SAF). Yoklama kayıtları işçiye göre
/// gruplanır; kapanmamış + tarih ≤ dönem sonu avanslar mahsup edilir.
///
/// Yalnız brütü > 0 olan işçiler döner (çalışması olmayan işçi listelenmez).
/// Bireysel işçiler önce (ada göre), sonra elebaşılar (ada göre) sıralanır.
List<PayrollLine> buildPayrollLines({
  required String periodStart,
  required String periodEnd,
  required List<AttendanceRecord> attendance,
  required List<Advance> advances,
}) {
  bool inRange(String date) =>
      date.compareTo(periodStart) >= 0 && date.compareTo(periodEnd) <= 0;

  // Yoklamaları işçiye göre grupla (yalnız dönem içi + henüz ödenmemiş).
  // Ödenen günler brüte tekrar katılmaz (çifte ödeme engeli — kural §6).
  final byWorker = <String, List<AttendanceRecord>>{};
  for (final r in attendance) {
    if (!inRange(r.date)) continue;
    if (r.isPaid) continue;
    (byWorker[r.workerId] ??= []).add(r);
  }

  // Kapatılabilir avansları işçiye göre grupla (kapanmamış + tarih ≤ dönem sonu).
  final advByWorker = <String, List<AdvanceRef>>{};
  for (final a in advances) {
    if (!a.isOpen) continue;
    if (a.date.compareTo(periodEnd) > 0) continue;
    (advByWorker[a.workerId] ??= []).add(
      AdvanceRef(id: a.id, amountKurus: a.amountKurus, date: a.date),
    );
  }

  final lines = <PayrollLine>[];
  byWorker.forEach((workerId, records) {
    final gross = records.fold<int>(0, (sum, r) => sum + r.earningKurus);
    if (gross <= 0) return; // kazanç yoksa ödeme/mahsup yok

    final isCrew = records.first is CrewAttendance;
    final name = records.first.workerName;

    if (isCrew) {
      var crewDays = 0;
      var headcount = 0;
      for (final r in records.cast<CrewAttendance>()) {
        headcount += r.headcount;
        if (r.headcount > 0) crewDays++;
      }
      lines.add(PayrollLine(
        workerId: workerId,
        workerName: name,
        workerType: WorkerType.elebasi,
        fullDays: 0,
        halfDays: 0,
        crewDays: crewDays,
        crewHeadcountTotal: headcount,
        // Elebaşıda avans yok (kural §10).
        computation: computePayroll(grossKurus: gross, advances: const []),
      ));
    } else {
      var full = 0, half = 0;
      var type = WorkerType.gundelik;
      for (final r in records.cast<IndividualAttendance>()) {
        type = r.workerType;
        switch (r.status) {
          case AttendanceStatus.full:
            full++;
          case AttendanceStatus.half:
            half++;
          case AttendanceStatus.absent:
            break;
        }
      }
      lines.add(PayrollLine(
        workerId: workerId,
        workerName: name,
        workerType: type,
        fullDays: full,
        halfDays: half,
        crewDays: 0,
        crewHeadcountTotal: 0,
        computation: computePayroll(
          grossKurus: gross,
          advances: advByWorker[workerId] ?? const [],
        ),
      ));
    }
  });

  lines.sort((a, b) {
    // Bireysel işçiler önce, elebaşılar sonra; grup içinde ada göre.
    if (a.isCrew != b.isCrew) return a.isCrew ? 1 : -1;
    return a.workerName.toLowerCase().compareTo(b.workerName.toLowerCase());
  });
  return lines;
}

/// İşçi geçmişi özeti — saf fonksiyon (Firestore'suz → unit test, kural §11).
///
/// Bir işçinin TÜM zamanki yoklama/avans/hakediş toplamları (dönemden bağımsız).
/// Rapor dönem-bazlıyken bu işçi-detay ekranı içindir. Çifte sayım yok: her
/// metrik ayrı kaynaktan (kural §6).
library;

import '../../advances/data/advance.dart';
import '../../attendance/data/attendance_record.dart';
import '../../payroll/data/payroll.dart';

class WorkerHistorySummary {
  const WorkerHistorySummary({
    this.fullDays = 0,
    this.halfDays = 0,
    this.crewDays = 0,
    this.crewHeadcountTotal = 0,
    this.grossEarnedKurus = 0,
    this.advancesTotalKurus = 0,
    this.openAdvancesKurus = 0,
    this.netPaidKurus = 0,
  });

  /// Bireysel: tam / yarım gün sayısı.
  final int fullDays;
  final int halfDays;

  /// Elebaşı: kişi girilen gün sayısı ve toplam kişi-gün.
  final int crewDays;
  final int crewHeadcountTotal;

  /// Tüm zamanki brüt kazanç (kuruş).
  final int grossEarnedKurus;

  /// Verilen tüm avanslar (kapanmış + açık) toplamı (kuruş).
  final int advancesTotalKurus;

  /// Açık (henüz mahsup edilmemiş) avans toplamı (kuruş).
  final int openAdvancesKurus;

  /// Ödenen hakediş neti toplamı (kuruş).
  final int netPaidKurus;

  /// Çalışılan (gün girilen) gün sayısı.
  int get workedDays => fullDays + halfDays + crewDays;
}

/// İşçinin geçmiş toplamlarını saf biçimde türetir.
WorkerHistorySummary buildWorkerHistorySummary({
  required List<AttendanceRecord> attendance,
  required List<Advance> advances,
  required List<Payroll> payrolls,
}) {
  var fullDays = 0;
  var halfDays = 0;
  var crewDays = 0;
  var crewHeadcountTotal = 0;
  var gross = 0;
  for (final r in attendance) {
    gross += r.earningKurus;
    switch (r) {
      case IndividualAttendance(:final status):
        if (status == AttendanceStatus.full) {
          fullDays++;
        } else if (status == AttendanceStatus.half) {
          halfDays++;
        }
      case CrewAttendance(:final headcount):
        if (headcount > 0) {
          crewDays++;
          crewHeadcountTotal += headcount;
        }
    }
  }

  var advancesTotal = 0;
  var openAdvances = 0;
  for (final a in advances) {
    advancesTotal += a.amountKurus;
    if (a.isOpen) openAdvances += a.amountKurus;
  }

  var netPaid = 0;
  for (final p in payrolls) {
    netPaid += p.netPaidKurus;
  }

  return WorkerHistorySummary(
    fullDays: fullDays,
    halfDays: halfDays,
    crewDays: crewDays,
    crewHeadcountTotal: crewHeadcountTotal,
    grossEarnedKurus: gross,
    advancesTotalKurus: advancesTotal,
    openAdvancesKurus: openAdvances,
    netPaidKurus: netPaid,
  );
}

/// İşçi geçmişi özeti — saf fonksiyon (Firestore'suz → unit test, kural §11).
///
/// Bir işçinin TÜM zamanki yoklama/avans toplamları (dönemden bağımsız).
/// Rapor dönem-bazlıyken bu işçi-detay ekranı içindir. Çifte sayım yok: her
/// metrik ayrı kaynaktan (kural §6).
library;

import '../../advances/data/advance.dart';
import '../../attendance/data/attendance_record.dart';

class WorkerHistorySummary {
  const WorkerHistorySummary({
    this.fullDays = 0,
    this.halfDays = 0,
    this.crewDays = 0,
    this.crewHeadcountTotal = 0,
    this.grossEarnedKurus = 0,
    this.unreconciledGrossKurus = 0,
    this.advancesTotalKurus = 0,
    this.openAdvancesKurus = 0,
  });

  /// Bireysel: tam / yarım gün sayısı.
  final int fullDays;
  final int halfDays;

  /// Elebaşı: kişi girilen gün sayısı ve toplam kişi-gün.
  final int crewDays;
  final int crewHeadcountTotal;

  /// Tüm zamanki brüt kazanç (kuruş).
  final int grossEarnedKurus;

  /// Net bakiyeye giren brüt kazanç: en son "hesap görüldü" kapanışından SONRA
  /// (o tarihten büyük günlerde) kazanılan tutar; kapanış yoksa = tüm brüt.
  /// Kapanış o güne kadarki kazanç+avansı denkleştirdiğinden bakiye yalnız
  /// sonrasını sayar (bkz. [netBalanceKurus]).
  final int unreconciledGrossKurus;

  /// Verilen tüm avanslar (kapanmış + açık) toplamı (kuruş).
  final int advancesTotalKurus;

  /// Açık (henüz mahsup edilmemiş) avans toplamı (kuruş).
  final int openAdvancesKurus;

  /// Çalışılan (gün girilen) gün sayısı.
  int get workedDays => fullDays + halfDays + crewDays;

  /// Net bakiye (kuruş): (denkleşmemiş) brüt kazanç − AÇIK avans.
  /// Pozitif → işçinin bizden ALACAĞI var; negatif → işçinin bize BORCU (vereceği).
  ///
  /// "Hesap görüldü" bir KAPANIŞTIR: o güne kadarki kazanç ve avanslar
  /// denkleştirilmiş sayılır — kapanan avanslar artık açık değildir ([openAdvancesKurus]
  /// dışıdır) ve kapanış öncesi kazanç [unreconciledGrossKurus] dışıdır → bakiye
  /// 0'a döner. Kapanışta girilen devir (aynı tarihli YENİ açık avans) kadar
  /// negatife (işçinin borcu) geçer. Kapanış sonrası yeni kazanç/avans normal
  /// işler; "Geri Al" kapanışı kaldırınca bakiye eski hâline döner.
  int get netBalanceKurus => unreconciledGrossKurus - openAdvancesKurus;
}

/// İşçinin geçmiş toplamlarını saf biçimde türetir.
WorkerHistorySummary buildWorkerHistorySummary({
  required List<AttendanceRecord> attendance,
  required List<Advance> advances,
}) {
  // En son "hesap görüldü" kapanış tarihi (geçerli tarihli, elle kapatılmış
  // avanslardan). O gün ve öncesindeki kazanç+avans denkleştirilmiş sayılır →
  // net bakiyeye yalnız sonrası girer. Kapanış yoksa tüm kazanç denkleşmemiştir.
  String? reconciledThrough;
  for (final a in advances) {
    if (!a.isManuallySettled) continue;
    final d = a.settledDate;
    if (d != null &&
        (reconciledThrough == null || d.compareTo(reconciledThrough) > 0)) {
      reconciledThrough = d;
    }
  }

  var fullDays = 0;
  var halfDays = 0;
  var crewDays = 0;
  var crewHeadcountTotal = 0;
  var gross = 0;
  var unreconciledGross = 0;
  for (final r in attendance) {
    gross += r.earningKurus;
    // Kapanış tarihinden SONRAKİ (o günden büyük) kazanç bakiyeye girer. ISO
    // tarih → sözlüksel karşılaştırma = kronolojik. Kapanış yoksa hepsi girer.
    if (reconciledThrough == null || r.date.compareTo(reconciledThrough) > 0) {
      unreconciledGross += r.earningKurus;
    }
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
    // Devir (carryover) kaydı gerçek nakit avans değil (kapanıştan taşınan
    // bakiye) → "Verilen avans toplamı"nda çifte saymayız. AMA hâlâ AÇIK bir
    // avanstır → net bakiyeye ([openAdvances]) normal girer.
    if (!a.id.startsWith(Advance.carryoverIdPrefix)) {
      advancesTotal += a.amountKurus;
    }
    if (a.isOpen) openAdvances += a.amountKurus;
  }

  return WorkerHistorySummary(
    fullDays: fullDays,
    halfDays: halfDays,
    crewDays: crewDays,
    crewHeadcountTotal: crewHeadcountTotal,
    grossEarnedKurus: gross,
    unreconciledGrossKurus: unreconciledGross,
    advancesTotalKurus: advancesTotal,
    openAdvancesKurus: openAdvances,
  );
}

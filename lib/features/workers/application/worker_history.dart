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

  /// Net bakiyeye giren açık (henüz mahsup edilmemiş) avans toplamı (kuruş):
  /// kapanış GÜNÜ HARİÇ tüm açık avanslar + (her zaman) devir kayıtları; kapanış
  /// yoksa tüm açık avanslar. Yalnız kapanış GÜNÜNE ait açık avans —devir hariç—
  /// denkleşmiş sayılıp dışarıda kalır; kapanıştan ÖNCEye tarihlenip hâlâ açık
  /// duran avans (sonradan geçmiş tarihle girilen) gerçek borçtur → sayılır.
  final int openAdvancesKurus;

  /// Çalışılan (gün girilen) gün sayısı.
  int get workedDays => fullDays + halfDays + crewDays;

  /// Net bakiye (kuruş): (denkleşmemiş) brüt kazanç − AÇIK avans.
  /// Pozitif → işçinin bizden ALACAĞI var; negatif → işçinin bize BORCU (vereceği).
  ///
  /// "Hesap görüldü" bir KAPANIŞTIR. Kazanç tarafında kapanış GÜNÜ ve öncesi
  /// denkleşmiş sayılır → [unreconciledGrossKurus] yalnız kapanıştan SONRAKİ
  /// günleri alır (geçmiş yoklama denkleşmiş tarihtir, yeniden açılmaz).
  ///
  /// Avans tarafında ise yalnız kapanış GÜNÜNE ait açık avans denkleşmiş sayılır
  /// (o an tüm açık avanslar kapatıldığından, kapanış günü açık kalan avans ancak
  /// kapanıştan sonra girilmiş demektir → denkleşmiş kabul). Kapanıştan ÖNCEye
  /// tarihlenip hâlâ açık avans (unutulup sonradan geçmiş tarihle girilen) GERÇEK
  /// borçtur ve [openAdvancesKurus]'a girer — Avanslar ekranı da onu "açık"
  /// gösterdiğinden iki ekran çelişmesin. Kapanışta girilen devir (aynı tarihli
  /// YENİ açık avans) her zaman sayılır → o kadar negatife (işçinin borcu) geçer.
  ///
  /// Bu asimetri (geçmiş kazanç denkleşmiş ↔ geçmiş açık avans borç) bilinçlidir:
  /// avansın kendi açık/kapalı yaşam döngüsü ve ekranı var, kazancın yok. Sadece
  /// kapanış GÜNÜNÜN kendisinde iki taraf da denkleşmiş sayılır (gün-bazlı veride
  /// kapanış "anı" ayrıştırılamaz); o güne iş/avans gerekirse "Geri Al" ile
  /// kapanış kaldırılıp tekrar kapatılır.
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
    final isCarryover = a.id.startsWith(Advance.carryoverIdPrefix);
    // Devir (carryover) kaydı gerçek nakit avans değil (kapanıştan taşınan
    // bakiye) → "Verilen avans toplamı"nda çifte saymayız.
    if (!isCarryover) {
      advancesTotal += a.amountKurus;
    }
    if (!a.isOpen) continue;
    // Kapanış (Hesap Görüldü) YALNIZ kapanış GÜNÜNE ait açık avansı denkleşmiş
    // sayar: o an tüm açık avanslar kapatıldığından, kapanış günü hâlâ açık kalan
    // bir avans ancak kapanıştan SONRA o güne girilmiştir → denkleşmiş kabul
    // (kapanış "anı" gün-bazlı veride ayrıştırılamaz). Kapanıştan ÖNCEye
    // tarihlenip hâlâ açık avans (unutulup sonradan geçmiş tarihle girilen)
    // GERÇEK borçtur → sayılır; Avanslar ekranı da onu "açık" gösterir, iki ekran
    // çelişmesin. Devir kaydı İSTİSNADIR: kapanış gününde oluşur ama taşınan
    // gerçek borçtur → her zaman sayılır. Kapanış yoksa tüm açık avanslar sayılır.
    // (Kazanç tarafı geçmiş TAMAMINI denkleşmiş sayar; bu asimetri bilinçli —
    // bkz. [netBalanceKurus].)
    if (reconciledThrough == null || isCarryover || a.date != reconciledThrough) {
      openAdvances += a.amountKurus;
    }
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

/// "Hesabı Görülenler" gruplaması (kural §6, §7): elle kapatılmış avansları tek
/// tek "hesap görüldü" olaylarına toplar ve her grubun GERİ ALINABİLİR olup
/// olmadığını işaretler. Ekranın çizim dışı tüm kararı burada (saf, test edilebilir).
library;

import '../data/advance.dart';

/// Tek bir "hesap görüldü" olayı: aynı işçi + aynı kapanış ([settlementKey]).
class SettlementGroup {
  const SettlementGroup({
    required this.key,
    required this.workerId,
    required this.settledDate,
    required this.advances,
    required this.reopenable,
  });

  /// Grup anahtarı `'<workerId>|<settlementKey>'` (ekranda liste kimliği).
  final String key;
  final String workerId;

  /// Kapanış tarihi (`'yyyy-MM-dd'`); bozuk/eksik işarette `''`.
  final String settledDate;

  /// Bu kapanışta kapatılan avanslar.
  final List<Advance> advances;

  /// Yalnız işçinin EN SON kapanışı geri alınabilir. Devir (carryover) zinciri
  /// newest-first çözülür: daha ESKİ bir kapanışı geri almak, arada (daha yeni
  /// kapanışta) kapanmış devir kaydını "açık" listede bulamaz → silemez;
  /// orijinal avans yeniden açılır ama devir kapalı kalır → net bakiye ÇİFT
  /// sayardı. Eski gruplarda Geri Al gizlenir ("önce yenisini geri alın").
  final bool reopenable;
}

/// Elle kapatılmış ([Advance.isManuallySettled]) avansları olaylara gruplar,
/// kapanış tarihine göre AZALAN (en yeni önce) sıralar ve her işçi için yalnız
/// en son kapanışı [SettlementGroup.reopenable] işaretler. Eski hakediş
/// mahsupları (manuel olmayan) burada YER ALMAZ — ekran onları ayrı gösterir.
List<SettlementGroup> buildSettlementGroups(Iterable<Advance> settled) {
  final byKey = <String, List<Advance>>{};
  for (final a in settled) {
    if (!a.isManuallySettled) continue;
    (byKey['${a.workerId}|${a.settlementKey}'] ??= []).add(a);
  }

  // İşçi başına en son kapanış tarihi (geri-alınabilirlik ölçütü).
  final latestByWorker = <String, String>{};
  for (final entry in byKey.values) {
    final wid = entry.first.workerId;
    final sd = entry.first.settledDate ?? '';
    final cur = latestByWorker[wid];
    if (cur == null || sd.compareTo(cur) > 0) latestByWorker[wid] = sd;
  }

  final groups = [
    for (final e in byKey.entries)
      SettlementGroup(
        key: e.key,
        workerId: e.value.first.workerId,
        settledDate: e.value.first.settledDate ?? '',
        advances: e.value,
        reopenable: (e.value.first.settledDate ?? '') ==
            latestByWorker[e.value.first.workerId],
      ),
  ]..sort((a, b) => b.settledDate.compareTo(a.settledDate));
  return groups;
}

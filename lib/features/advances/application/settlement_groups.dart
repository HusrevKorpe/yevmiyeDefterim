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
///
/// Geri-alınabilirlik iki ölçüte dayanır (yalnız tarih YETMEZ):
/// 1. Kapanış tarihi işçinin en son kapanış tarihi olmalı (farklı günlerde en son).
/// 2. Bu kapanış "aşılmamış" olmalı: ürettiği devir kaydı DAHA SONRAKİ bir
///    kapanışta yeniden kapatılmış olmamalı. AYNI GÜN zincirlenen kapanışlarda
///    (C1'i kapatırsın → devir; aynı gün C1'in devrini de kapatırsın) ikisinin de
///    tarihi aynıdır → yalnız tarihe bakınca ikisi de "en son" görünür ve ikisi de
///    geri-alınabilir olurdu. Eskisini geri almak devir kaydını "açık" listede
///    bulamaz → çift devir (net bakiye çift sayardı). Devir zinciri bunu ayırır.
List<SettlementGroup> buildSettlementGroups(Iterable<Advance> settled) {
  final all = settled.toList();
  final byKey = <String, List<Advance>>{};
  for (final a in all) {
    if (!a.isManuallySettled) continue;
    (byKey['${a.workerId}|${a.settlementKey}'] ??= []).add(a);
  }

  // İşçi başına en son kapanış tarihi (birincil geri-alınabilirlik ölçütü).
  final latestByWorker = <String, String>{};
  for (final entry in byKey.values) {
    final wid = entry.first.workerId;
    final sd = entry.first.settledDate ?? '';
    final cur = latestByWorker[wid];
    if (cur == null || sd.compareTo(cur) > 0) latestByWorker[wid] = sd;
  }

  // İşçi başına, YENİDEN KAPATILMIŞ (kapanmış) devir kayıtları. Bir kapanışın
  // ürettiği devir kaydı burada varsa o kapanış "aşılmıştır" → artık en son
  // değildir. (Açık duran devir listeye gelmez → aşılmamış = zincirin ucu.)
  final closedCarryoversByWorker = <String, List<Advance>>{};
  for (final a in all) {
    if (a.id.startsWith(Advance.carryoverIdPrefix)) {
      (closedCarryoversByWorker[a.workerId] ??= []).add(a);
    }
  }
  bool superseded(String workerId, String? settlementKey) {
    if (settlementKey == null) return false;
    final carry = closedCarryoversByWorker[workerId];
    return carry != null && carry.any((a) => a.isCarryoverOf(settlementKey));
  }

  final groups = [
    for (final e in byKey.entries)
      SettlementGroup(
        key: e.key,
        workerId: e.value.first.workerId,
        settledDate: e.value.first.settledDate ?? '',
        advances: e.value,
        reopenable: (e.value.first.settledDate ?? '') ==
                latestByWorker[e.value.first.workerId] &&
            !superseded(
                e.value.first.workerId, e.value.first.settlementKey),
      ),
  ]..sort((a, b) => b.settledDate.compareTo(a.settledDate));
  return groups;
}

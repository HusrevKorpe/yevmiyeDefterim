/// İşçi arama — saf süzme + sıralama (kural §7).
///
/// Ekran yalnız sonucu gösterir; eşleşme mantığı burada ve
/// `core/search/fuzzy_search.dart` içindedir → unit test edilir.
library;

import '../../../core/search/fuzzy_search.dart';
import '../data/worker.dart';

/// Etiket ("Elebaşı", "Kadın") eşleşmesi ada göre daima geride kalsın diye
/// düşük puan verilir.
const int _labelScore = 300;

/// Etiketle arama için en az harf sayısı — "e" yazınca tüm elebaşıların
/// dökülmemesi için.
const int _minLabelQueryLength = 3;

/// [query] ile eşleşen işçiler, en iyi eşleşme başta.
///
/// Sorgu boşsa liste olduğu gibi döner. Ad üzerinde bulanık eşleşme yapılır
/// (Türkçe harf ve yazım hatası toleranslı); 3 harften uzun sorgularda tür
/// ("elebaşı") ve cinsiyet ("kadın") etiketleri de düşük puanla aranır.
/// Pasif işçiler de aranır (eşit puanda aktiflerin arkasına düşerler).
List<Worker> searchWorkers(List<Worker> workers, String query) {
  if (query.trim().isEmpty) return List<Worker>.of(workers);

  final List<_Scored> hits = <_Scored>[];
  for (final w in workers) {
    final int? score = scoreWorker(w, query);
    if (score != null) hits.add(_Scored(score, w));
  }
  hits.sort((a, b) {
    final int byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    if (a.worker.active != b.worker.active) return a.worker.active ? -1 : 1;
    return compareWorkers(a.worker, b.worker);
  });
  return <Worker>[for (final h in hits) h.worker];
}

/// Tek bir işçinin sorguya uygunluk puanı; eşleşme yoksa `null`.
int? scoreWorker(Worker worker, String query) {
  final int? byName = fuzzyScore(query, worker.name);
  if (byName != null) return byName;

  if (normalizeForSearch(query).length < _minLabelQueryLength) return null;
  if (_labelMatches(query, worker.type.label)) return _labelScore;
  // Elebaşı cinsiyetle takip edilmez (kural §10) → yalnız bireysel işçide.
  if (worker.type.isIndividual && _labelMatches(query, worker.gender.label)) {
    return _labelScore;
  }
  return null;
}

/// Etikette yalnız GÜÇLÜ eşleşme sayılır (başı tutuyor ya da içinde geçiyor);
/// yazım hatası toleransı burada kapalı — "kadin" ile "sabit"i karıştırmayalım.
bool _labelMatches(String query, String label) {
  final int? score = fuzzyScore(query, label);
  return score != null && score >= 780;
}

class _Scored {
  const _Scored(this.score, this.worker);
  final int score;
  final Worker worker;
}

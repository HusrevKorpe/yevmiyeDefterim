/// Türkçe-duyarlı, yazım hatasına toleranslı ("bulanık") arama — saf fonksiyon
/// (kural §7: hesap/eşleşme mantığı Firestore'suz, test edilebilir).
///
/// Amaç: kullanıcı klavyede Türkçe harf kullanmasa ("sukru" → "Şükrü") ya da
/// harfi yanlış yazsa ("ahmte" → "Ahmet") bile aradığını bulsun. Arama
/// Firestore'a SORU SORMAZ: listeler zaten cihazda (offline-öncelikli, kural §3)
/// → süzme tamamen bellekte yapılır.
library;

/// Türkçe/aksanlı harflerin ASCII karşılığı. `toLowerCase()` bunları doğru
/// çeviremez ('İ' → 'i' + birleşik nokta, 'I' → 'i') → elle eşlenir.
const Map<String, String> _folds = <String, String>{
  'ı': 'i', 'I': 'i', 'İ': 'i', 'i': 'i',
  'ş': 's', 'Ş': 's',
  'ğ': 'g', 'Ğ': 'g',
  'ç': 'c', 'Ç': 'c',
  'ö': 'o', 'Ö': 'o',
  'ü': 'u', 'Ü': 'u',
  'â': 'a', 'Â': 'a',
  'î': 'i', 'Î': 'i',
  'û': 'u', 'Û': 'u',
  'ê': 'e', 'Ê': 'e', 'é': 'e', 'É': 'e',
};

final RegExp _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Karşılaştırma öncesi sadeleştirme: Türkçe harfler ASCII'ye düşer, noktalama
/// boşluğa çevrilir, baştaki/sondaki ve tekrar eden boşluklar atılır.
///
/// "Şükrü  Yılmaz-Oğlu" → "sukru yilmaz oglu"
String normalizeForSearch(String input) {
  final buffer = StringBuffer();
  var pendingSpace = false;
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    final folded = _folds[ch] ?? ch.toLowerCase();
    if (!_letterOrDigit.hasMatch(folded)) {
      // Harf/rakam değilse (boşluk, tire, nokta…) kelime ayracı sayılır.
      if (buffer.isNotEmpty) pendingSpace = true;
      continue;
    }
    if (pendingSpace) {
      buffer.write(' ');
      pendingSpace = false;
    }
    buffer.write(folded);
  }
  return buffer.toString();
}

/// Sorgu uzunluğuna göre hoş görülen yazım hatası sayısı. Kısa sorguda tolerans
/// gürültü yapar (2 harfte her şey benzer) → 0'dan başlar. Eli de sıkı tutulur:
/// 6 harfe kadar tek hata, çünkü "Mehmet" ile "Ahmet" arasında yalnız 2 harf
/// var — cömert tolerans aramayı çöpe çevirir.
int allowedTypos(int queryLength) {
  if (queryLength <= 2) return 0;
  if (queryLength <= 6) return 1;
  if (queryLength <= 9) return 2;
  return 3;
}

/// İki metin arasındaki en az düzenleme sayısı: ekleme, silme, değiştirme ve
/// **komşu harf yer değiştirmesi** ("ahmte" → "ahmet" = 1 hata).
///
/// [maxDistance] aşılırsa hesap erken biter ve `maxDistance + 1` döner (yani
/// "çok uzak"); tam değer gerekmediğinden bu yeterli ve hızlıdır.
int editDistance(String a, String b, {int maxDistance = 1 << 30}) {
  if (identical(a, b) || a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  if ((a.length - b.length).abs() > maxDistance) return maxDistance + 1;

  final int n = b.length;
  // Üç satır dönüşümlü kullanılır: prevPrev (i-2) yer değiştirme için gerekir.
  List<int> prevPrev = List<int>.filled(n + 1, 0);
  List<int> prev = List<int>.generate(n + 1, (j) => j);
  List<int> current = List<int>.filled(n + 1, 0);

  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    var rowMin = i;
    for (var j = 1; j <= n; j++) {
      final bool same = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1);
      var best = prev[j - 1] + (same ? 0 : 1); // değiştir
      final int insert = current[j - 1] + 1;
      if (insert < best) best = insert;
      final int delete = prev[j] + 1;
      if (delete < best) best = delete;
      if (i > 1 &&
          j > 1 &&
          a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
          a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
        final int swap = prevPrev[j - 2] + 1; // komşu harf yer değiştirmesi
        if (swap < best) best = swap;
      }
      current[j] = best;
      if (best < rowMin) rowMin = best;
    }
    if (rowMin > maxDistance) return maxDistance + 1;
    final List<int> recycled = prevPrev;
    prevPrev = prev;
    prev = current;
    current = recycled;
  }
  return prev[n];
}

/// [query] [target] içinde ne kadar iyi eşleşiyor? Büyük puan = daha iyi
/// eşleşme; eşleşme yoksa `null`.
///
/// Puan basamakları (yüksekten alçağa): birebir aynı → metnin başı → kelime
/// başı → içinde geçiyor → çok kelimeli sorguda hepsi tutuyor → baş harfler →
/// yazım hatalı kelime → harf sırası korunmuş ("ahmtylmz" → "Ahmet Yılmaz").
int? fuzzyScore(String query, String target) {
  final String q = normalizeForSearch(query);
  final String t = normalizeForSearch(target);
  if (q.isEmpty || t.isEmpty) return null;

  if (t == q) return 1000;
  if (t.startsWith(q)) return 920;

  final List<String> words = t.split(' ');
  for (var i = 0; i < words.length; i++) {
    if (words[i] == q) return 900 - i;
  }
  for (var i = 0; i < words.length; i++) {
    if (words[i].startsWith(q)) return 860 - i;
  }
  // Tek harflik sorguda "içinde geçiyor" aramayı işe yaramaz hâle getirir
  // (içinde 'a' geçen herkes) → yalnız 2+ harfte bakılır.
  if (q.length >= 2 && t.contains(q)) return 780;

  // Çok kelimeli sorgu: sıra önemsiz, her parça bir kelimeyi tutmalı
  // ("yilmaz ahmet" → "Ahmet Yılmaz").
  final List<String> qWords = q.split(' ');
  if (qWords.length > 1 &&
      qWords.every((tok) => words.any((w) => _wordMatches(tok, w)))) {
    return 760;
  }

  // Baş harfler: "ay" → "Ahmet Yılmaz".
  if (qWords.length == 1 && q.length >= 2 && words.length >= 2) {
    final String initials = words.map((w) => w[0]).join();
    if (initials.startsWith(q)) return 740;
  }

  // Yazım hatası toleransı — kelime kelime bakılır (tüm ada bakmak uzun
  // adlarda anlamsız uzaklık verir).
  if (qWords.length == 1) {
    final int tolerance = allowedTypos(q.length);
    if (tolerance > 0) {
      var best = -1;
      for (var i = 0; i < words.length; i++) {
        final int d = _wordDistance(q, words[i], tolerance);
        if (d <= tolerance) {
          final int score = 700 - d * 90 - i;
          if (score > best) best = score;
        }
      }
      if (best >= 0) return best;
    }
  }

  // Son çare: harfler sırayla geçiyor mu ("mhmt" → "Mehmet"). Kısa sorguda
  // rastgele eşleşir → en az 4 harf.
  if (q.length >= 4 && !q.contains(' ') && _isSubsequence(q, t)) return 420;
  return null;
}

/// Tek kelime eşleşmesi: başı tutuyor ya da tolerans içinde yazım hatası var.
bool _wordMatches(String token, String word) {
  if (word.startsWith(token)) return true;
  final int tolerance = allowedTypos(token.length);
  return tolerance > 0 && _wordDistance(token, word, tolerance) <= tolerance;
}

/// Sorgunun kelimeye uzaklığı. Kullanıcı adı yazarken henüz bitirmemiş
/// olabilir → kelimenin sorgu boyundaki başına da bakılır ("mehmed" hem
/// "mehmet" hem "mehmetali" için 1 hata).
int _wordDistance(String token, String word, int tolerance) {
  var d = editDistance(token, word, maxDistance: tolerance);
  if (word.length > token.length) {
    final int dPrefix = editDistance(
      token,
      word.substring(0, token.length),
      maxDistance: tolerance,
    );
    if (dPrefix < d) d = dPrefix;
  }
  return d;
}

/// [q] harfleri [t] içinde aynı sırayla (arada boşluk olabilir) geçiyor mu.
bool _isSubsequence(String q, String t) {
  var i = 0;
  for (var j = 0; j < t.length && i < q.length; j++) {
    if (q.codeUnitAt(i) == t.codeUnitAt(j)) i++;
  }
  return i == q.length;
}

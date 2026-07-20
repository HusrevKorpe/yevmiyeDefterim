/// Tarih yardımcıları (kural.md §2).
///
/// İş günü = kullanıcının seçtiği **yerel** tarih, `'yyyy-MM-dd'` string.
/// Kullanıcı tarihi için `serverTimestamp()` kullanılmaz (offline'da null gelir).
library;

import 'package:intl/intl.dart';

final DateFormat _isoDate = DateFormat('yyyy-MM-dd');
final DateFormat _humanDate = DateFormat('d MMMM y, EEEE', 'tr_TR');
final DateFormat _humanDateNoWeekday = DateFormat('d MMMM y', 'tr_TR');
final DateFormat _weekday = DateFormat('EEEE', 'tr_TR');
final DateFormat _shortDate = DateFormat('d MMMM', 'tr_TR');

/// Yerel tarihten `'yyyy-MM-dd'` üretir (UTC gece yarısı değil).
String toIsoDate(DateTime date) =>
    _isoDate.format(DateTime(date.year, date.month, date.day));

/// Bugünün yerel iş günü (`'yyyy-MM-dd'`). Test için [now] verilebilir.
String todayIso([DateTime? now]) => toIsoDate(now ?? DateTime.now());

/// `'yyyy-MM-dd'` string'ini yerel [DateTime]'a çevirir (gün başı 00:00).
DateTime parseIsoDate(String iso) => _isoDate.parseStrict(iso);

/// Gösterim için TR insancıl tarih: "18 Temmuz 2026, Cuma".
String formatHumanDate(String iso) => _humanDate.format(parseIsoDate(iso));

/// Gün adı olmadan insancıl tarih: "18 Temmuz 2026". Dar/iki satırlı başlıklar
/// için — uzun gün adı ("Cumartesi") ayrı satıra alınır ki tarih taşmasın.
String formatHumanDateNoWeekday(String iso) =>
    _humanDateNoWeekday.format(parseIsoDate(iso));

/// Yalnız gün adı: "Cuma" / "Cumartesi".
String formatWeekday(String iso) => _weekday.format(parseIsoDate(iso));

/// Kompakt TR tarih (dönem pili için): "18 Temmuz".
String formatShortDate(String iso) => _shortDate.format(parseIsoDate(iso));

/// [iso] tarihine [days] gün ekler/çıkarır, yeni `'yyyy-MM-dd'` döner.
String shiftIsoDate(String iso, int days) =>
    toIsoDate(parseIsoDate(iso).add(Duration(days: days)));

/// İçinde bulunulan ayın ilk günü (`'yyyy-MM-dd'`) — hakediş dönem varsayılanı.
String firstDayOfMonthIso([DateTime? now]) {
  final n = now ?? DateTime.now();
  return toIsoDate(DateTime(n.year, n.month, 1));
}

/// İçinde bulunulan haftanın Pazartesi'si (`'yyyy-MM-dd'`) — hafta preseti.
String startOfWeekIso([DateTime? now]) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  return toIsoDate(today.subtract(Duration(days: today.weekday - 1)));
}

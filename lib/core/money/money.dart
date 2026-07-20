/// Para birimi yardımcıları (kural.md §1 — EN ÖNEMLİ).
///
/// - Giriş TL cinsindendir: "2000" => 2000 TL.
/// - Virgül = ondalık (kuruş): "2000,50" => 2000 TL 50 kuruş.
/// - Nokta = binlik ayırıcı: "2.000,50" => 2000,50 TL.
/// - İç depolama HER ZAMAN tam sayı **kuruş** (TL * 100).
/// - Asla `double`/`float` ile para HESABI yapılmaz; double yalnız gösterimde.
library;

import 'package:intl/intl.dart';

final NumberFormat _currencyFormat = NumberFormat.currency(
  locale: 'tr_TR',
  symbol: '₺',
  decimalDigits: 2,
);

final NumberFormat _plainFormat = NumberFormat('#,##0.00', 'tr_TR');

/// TR formatlı para girişini tam sayı **kuruşa** çevirir.
///
/// Örnekler:
///   "2000"      -> 200000   (2000 TL)
///   "2000,50"   -> 200050
///   "2.000,50"  -> 200050
///   "2.000"     -> 200000
///   "2000,5"    -> 200050   (tek ondalık = 50 kuruş)
///   "₺ 1.234,5" -> 123450
///
/// Geçersizse `null` döner: boş, harf içeren, 2'den fazla ondalık,
/// birden fazla virgül veya yalnızca ayraçtan oluşan giriş.
int? parseTlToKurus(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;

  // Para sembolü ve tüm boşlukları (NBSP dahil) temizle.
  s = s.replaceAll('₺', '');
  s = s.replaceAll(RegExp(r'\s'), '');
  if (s.isEmpty) return null;

  // İşaret.
  var negative = false;
  if (s.startsWith('-')) {
    negative = true;
    s = s.substring(1);
  } else if (s.startsWith('+')) {
    s = s.substring(1);
  }
  if (s.isEmpty) return null;

  // Ondalık ayırıcı yalnız virgül; birden fazla virgül geçersiz.
  final commaCount = ','.allMatches(s).length;
  if (commaCount > 1) return null;

  String liraPart;
  String kurusPart;
  if (commaCount == 1) {
    final parts = s.split(',');
    liraPart = parts[0];
    kurusPart = parts[1];
  } else {
    liraPart = s;
    kurusPart = '';
  }

  // Yalnızca ayraç ("," veya boş) => geçersiz.
  if (liraPart.isEmpty && kurusPart.isEmpty) return null;

  // Nokta = binlik ayırıcı; yalnız lira kısmından silinir.
  liraPart = liraPart.replaceAll('.', '');
  if (liraPart.isEmpty) liraPart = '0';

  // Kuruş kısmında nokta olmamalı ve en fazla 2 hane.
  if (kurusPart.contains('.')) return null;
  if (kurusPart.length > 2) return null;

  if (!_isAllDigits(liraPart)) return null;
  if (kurusPart.isNotEmpty && !_isAllDigits(kurusPart)) return null;

  // "" -> "00", "5" -> "50", "50" -> "50".
  final kurusNormalized = kurusPart.padRight(2, '0');

  final lira = int.tryParse(liraPart);
  final kurus = int.tryParse(kurusNormalized);
  if (lira == null || kurus == null) return null;

  final total = lira * 100 + kurus;
  return negative ? -total : total;
}

/// Kuruşu gösterim için `₺` önekli TR formatına çevirir. Yalnızca gösterim.
String formatKurus(int kurus) => _currencyFormat.format(kurus / 100);

/// Kuruşu sembolsüz TR formatına çevirir (ör. giriş alanı ön dolumu).
String formatKurusPlain(int kurus) => _plainFormat.format(kurus / 100);

/// Yarım gün ücreti = tam sayı bölme (kural §1). Tam lira ücretlerde kayıpsız.
int halfWage(int wageKurus) => wageKurus ~/ 2;

bool _isAllDigits(String s) =>
    s.isNotEmpty && s.codeUnits.every((c) => c >= 0x30 && c <= 0x39);

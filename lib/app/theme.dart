/// Uygulama teması — düşük teknoloji dostu (kural.md §8).
///
/// Büyük font/kontrast, yeşil=geldi, sarı=yarım, gri=yok.
library;

import 'package:flutter/material.dart';

/// Yoklama durum renkleri (kural §8).
class StatusColors {
  StatusColors._();

  static const Color full = Color(0xFF2E7D32); // yeşil = geldi (tam gün)
  static const Color half = Color(0xFFF9A825); // sarı  = yarım gün
  static const Color absent =
      Color(0xFFE0554A); // yumuşak kırmızı = yok (trafik-ışığı üçlüsü)
}

/// Cinsiyet vurgu renkleri (Ana Sayfa özet kutucukları) — AÇIK tema tonu.
const Color kFemale = Color(0xFFD81B60); // pembe/magenta = kadın
const Color kMale = Color(0xFF1E88E5); // mavi = erkek

// Koyu tema tonları — düz koyu zeminde metin/ikon kontrastı için daha parlak.
const Color _kFemaleDark = Color(0xFFF06292); // pink.300
const Color _kMaleDark = Color(0xFF64B5F6); // blue.300
const Color _incomeLight = Color(0xFF2E7D32); // green.700 tonu (gelir/pozitif)
const Color _incomeDark = Color(0xFF66BB6A); // green.400 (koyu zeminde okunur)

/// Tema-duyarlı "kadın" vurgusu (koyu zeminde daha parlak pembe).
Color femaleColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? _kFemaleDark : kFemale;

/// Tema-duyarlı "erkek" vurgusu (koyu zeminde daha parlak mavi).
Color maleColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? _kMaleDark : kMale;

/// Gelir/ödenen/pozitif tutarlar için tema-duyarlı yeşil. Açık temada koyu
/// yeşil okunur; koyu temada `green.700` zeminde kaybolur → daha parlak ton.
Color incomeColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? _incomeDark : _incomeLight;

const Color _seed = Color(0xFF2E7D32);

/// Ortak "hero" degrade tonları (başlıklar, özet kartları). Tüm ekranlarda aynı.
const Color kHeroTop = Color(0xFF43A047);
const Color kHeroBottom = Color(0xFF1B5E20);

/// Başlık ve vurgu kartlarında kullanılan ortak degrade.
const LinearGradient kHeroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kHeroTop, kHeroBottom],
);

/// Açık tema. Büyük dokunma hedefleri ve okunaklı fontlar.
ThemeData buildLightTheme() => _buildTheme(Brightness.light);

/// Koyu tema — aynı marka tohumu, aynı buton/menü stilleri; yalnız parlaklık
/// farklı. `ColorScheme.fromSeed(dark)` yüzeyleri/metinleri otomatik uyarlar.
ThemeData buildDarkTheme() => _buildTheme(Brightness.dark);

/// Geriye dönük ad (testler ve eski çağrı yerleri açık temayı bekliyor).
ThemeData buildAppTheme() => buildLightTheme();

/// Açık/Koyu ortak gövde — tek kaynak; iki tema arasında stil sürüklenmesi olmaz.
ThemeData _buildTheme(Brightness brightness) {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: brightness,
  );
  final ThemeData base = ThemeData(colorScheme: scheme, useMaterial3: true);

  const Size bigButton = Size.fromHeight(56);

  // Not: metinler global olarak `app.dart` içindeki `textScaler` ile büyütülür
  // (M3 varsayılan bazı stillerin fontSize'ı null olduğundan textTheme.apply
  // yerine bu yol tercih edildi ve kullanıcının erişilebilirlik ayarına saygılıdır).
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: bigButton,
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: bigButton,
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: bigButton,
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 74,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

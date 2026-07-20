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
  static const Color absent = Color(0xFF9E9E9E); // gri  = yok
}

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

/// Uygulama teması. Büyük dokunma hedefleri ve okunaklı fontlar.
ThemeData buildAppTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: Brightness.light,
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

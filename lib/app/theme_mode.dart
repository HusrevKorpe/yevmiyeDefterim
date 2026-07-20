/// Tema modu (Açık / Koyu / Sistem) — cihazda kalıcı, anında uygulanır.
///
/// Tercih `SharedPreferences`'ta yerel tutulur (Firestore/ağ'a bağlı DEĞİL):
/// böylece uygulama daha ilk karede doğru temayla açılır, çevrimdışıyken de
/// çalışır. [sharedPreferencesProvider] `main`'de gerçek örnekle override edilir;
/// testlerde override edilmezse `null` döner → güvenli varsayılan [ThemeMode.system].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Prefs anahtarı — modu 'system' | 'light' | 'dark' olarak saklar.
const String kThemeModeKey = 'themeMode';

/// `main`'de `overrideWithValue(prefs)` ile bağlanır. Bağlanmazsa (testler) null.
final Provider<SharedPreferences?> sharedPreferencesProvider =
    Provider<SharedPreferences?>((ref) => null);

ThemeMode _themeModeFromString(String? s) => switch (s) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

/// Kalıcı tema modunu okuyup yazan denetleyici. Uygulama kökü bunu izler.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return _themeModeFromString(prefs?.getString(kThemeModeKey));
  }

  /// Modu değiştirir ve kalıcı yazar. UI anında yeni temaya geçer.
  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider)?.setString(kThemeModeKey, mode.name);
  }
}

final NotifierProvider<ThemeModeController, ThemeMode> themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

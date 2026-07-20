/// Uygulama ayarları — varsayılan yevmiyeler (plan §3 `settings/config`).
///
/// Para HER ZAMAN tam sayı **kuruş** (kural §1). Model saf/değişmezdir (freezed);
/// Firestore eşlemesi [fromMap]/[toMap] ile elle yapılır (Timestamp yok).
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_settings.freezed.dart';

@freezed
abstract class AppSettings with _$AppSettings {
  const AppSettings._();

  const factory AppSettings({
    required int defaultWageMaleKurus,
    required int defaultWageFemaleKurus,
    required int defaultCrewRateKurus,
  }) = _AppSettings;

  /// Ayar dokümanı henüz yokken kullanılan sıfır varsayılan.
  /// Kullanıcı ilk açılışta ücretleri girer.
  static const AppSettings empty = AppSettings(
    defaultWageMaleKurus: 0,
    defaultWageFemaleKurus: 0,
    defaultCrewRateKurus: 0,
  );

  /// Firestore verisinden okur. Eksik/bozuk alanları 0'a düşürür (offline'da
  /// kısmi doküman gelebilir — çökme yerine güvenli varsayılan).
  factory AppSettings.fromMap(Map<String, dynamic>? data) {
    final m = data ?? const {};
    return AppSettings(
      defaultWageMaleKurus: _asInt(m['defaultWageMaleKurus']),
      defaultWageFemaleKurus: _asInt(m['defaultWageFemaleKurus']),
      defaultCrewRateKurus: _asInt(m['defaultCrewRateKurus']),
    );
  }

  /// Firestore'a yazılacak alanlar (tam doküman; ayar tek config dokümanı).
  Map<String, dynamic> toMap() => {
        'defaultWageMaleKurus': defaultWageMaleKurus,
        'defaultWageFemaleKurus': defaultWageFemaleKurus,
        'defaultCrewRateKurus': defaultCrewRateKurus,
      };
}

/// Firestore'dan gelen sayıyı tam sayı kuruşa çevirir (int/double/eksik/null).
int _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return 0;
}

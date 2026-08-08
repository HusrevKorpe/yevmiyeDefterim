/// Tarla modeli (`workspaces/main/plots/{uuid}`, kural §5 soft-delete).
///
/// Yoklamada "kim NEREDE çalıştı" seçimi için kullanıcı tanımlı tarla listesi.
/// Yapılan iştan (bkz. [Job]) BAĞIMSIZDIR: bir günün kaydında ikisi de ayrı
/// ayrı, isteğe bağlı olarak seçilir.
///
/// 2026-08-07'de açıldı. O tarihe kadar tarla/iş ayrımı yoktu; tek liste vardı
/// ve içine yapılan iş yazılıyordu → o liste [Job] oldu, gerçek tarlalar bu
/// yeni koleksiyondan başlar (geçmiş kayıtlarda tarla YOKTUR, bu beklenendir).
///
/// Saf/değişmez (freezed). Firestore eşlemesi [fromDoc]/[toMap] ile elle yapılır;
/// zaman damgaları repository'de eklenir.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'plot.freezed.dart';

@freezed
abstract class Plot with _$Plot {
  const Plot._();

  const factory Plot({
    required String id,
    required String name,

    /// Soft-delete bayrağı (kural §5): silinen tarla seçim listesinden düşer;
    /// geçmiş yoklama kayıtlarındaki denormalize adı (plotName) okunur kalır.
    @Default(true) bool active,
  }) = _Plot;

  /// Firestore dokümanından okur. Eksik/bozuk alanlar güvenli varsayılana düşer.
  factory Plot.fromDoc(String id, Map<String, dynamic>? data) {
    final m = data ?? const {};
    return Plot(
      id: id,
      name: (m['name'] as String?)?.trim() ?? '',
      active: (m['active'] as bool?) ?? true,
    );
  }

  /// Domain alanları (zaman damgaları hariç — repository ekler).
  Map<String, dynamic> toMap() => {
        'name': name,
        'active': active,
      };
}

/// Liste sırası: ada göre (büyük/küçük harf duyarsız). Yönetim ekranı ve
/// yoklamadaki çipler aynı sırayı kullanır.
int comparePlots(Plot a, Plot b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

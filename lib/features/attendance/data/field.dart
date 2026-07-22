/// Tarla modeli (`workspaces/main/fields/{uuid}`, kural §5 soft-delete).
///
/// Yoklamada "kim nerede çalıştı" seçimi için kullanıcı tanımlı tarla listesi.
/// Saf/değişmez (freezed). Firestore eşlemesi [fromDoc]/[toMap] ile elle yapılır;
/// zaman damgaları repository'de eklenir.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'field.freezed.dart';

@freezed
abstract class Field with _$Field {
  const Field._();

  const factory Field({
    required String id,
    required String name,

    /// Soft-delete bayrağı (kural §5): silinen tarla seçim listesinden düşer;
    /// geçmiş yoklama kayıtlarındaki denormalize adı (fieldName) okunur kalır.
    @Default(true) bool active,
  }) = _Field;

  /// Firestore dokümanından okur. Eksik/bozuk alanlar güvenli varsayılana düşer.
  factory Field.fromDoc(String id, Map<String, dynamic>? data) {
    final m = data ?? const {};
    return Field(
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

/// Liste sırası: ada göre (büyük/küçük harf duyarsız). Tarla yönetim ekranı ve
/// yoklamadaki çipler aynı sırayı kullanır.
int compareFields(Field a, Field b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

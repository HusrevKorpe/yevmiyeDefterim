/// İşçi modeli (plan §3 `workers/{uuid}`, kural §5 soft-delete).
///
/// Saf/değişmez (freezed). Firestore eşlemesi [fromDoc]/[toMap] ile elle yapılır;
/// zaman damgaları (createdAt/updatedAt/clientUpdatedAt) repository'de eklenir.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'worker.freezed.dart';

/// İşçi türü. Enum adı = Firestore'da saklanan değer.
enum WorkerType { sabit, gundelik, elebasi }

extension WorkerTypeX on WorkerType {
  String get label => switch (this) {
        WorkerType.sabit => 'Sabit',
        WorkerType.gundelik => 'Gündelik',
        WorkerType.elebasi => 'Elebaşı',
      };

  /// Elebaşı bireysel takip edilmez (kişi sayısı + toplu ödeme — kural §10).
  bool get isCrew => this == WorkerType.elebasi;

  /// Cinsiyet ve ücret snapshot'ı yalnız bireysel işçiler için anlamlı.
  bool get isIndividual => this != WorkerType.elebasi;
}

/// Cinsiyet. Enum adı = Firestore'da saklanan değer. Ücret çözümünde kullanılır.
enum Gender { male, female }

extension GenderX on Gender {
  String get label => switch (this) {
        Gender.male => 'Erkek',
        Gender.female => 'Kadın',
      };
}

@freezed
abstract class Worker with _$Worker {
  const Worker._();

  const factory Worker({
    required String id,
    required String name,
    required WorkerType type,
    required Gender gender,

    /// İşçinin günlük ücreti (kuruş). Sabit/varsayılan yevmiye kaldırıldı →
    /// bireysel işçide bu alan TEK ücret kaynağıdır (ekle/düzenlede zorunlu).
    /// Null yalnız eski ya da kısıtlı-hesap kayıtlarında olur → yoklamada 0 sayılır.
    /// Elebaşı için anlamsız (ödeme toplu, kişi bazlı ücret yok).
    int? dailyWageOverrideKurus,

    /// Elebaşının getirdiği kişi sayısı — YALNIZCA bilgi amaçlı gösterilir.
    /// Listede/detayda "N kişilik ekip" olarak görünür; yoklama ve para
    /// hesabına GİRMEZ (günlük kişi sayısı yoklamada ayrıca tutulur). Yalnız
    /// elebaşı için anlamlı; bireysel işçide null. Null/0 => gösterilmez.
    int? defaultHeadcount,

    /// Soft-delete bayrağı (kural §5): pasif işçi listede gizli, raporda görünür.
    @Default(true) bool active,
  }) = _Worker;

  /// Firestore dokümanından okur. Eksik/bozuk alanlar güvenli varsayılana düşer.
  factory Worker.fromDoc(String id, Map<String, dynamic>? data) {
    final m = data ?? const {};
    return Worker(
      id: id,
      name: (m['name'] as String?)?.trim() ?? '',
      type: _typeFromName(m['type']),
      gender: _genderFromName(m['gender']),
      dailyWageOverrideKurus: _asIntOrNull(m['dailyWageOverrideKurus']),
      defaultHeadcount: _asIntOrNull(m['defaultHeadcount']),
      active: (m['active'] as bool?) ?? true,
    );
  }

  /// Gösterilecek ekip mevcudu (yalnız elebaşı, >0). Aksi halde 0 => gösterme.
  int get crewSize =>
      (type.isCrew && defaultHeadcount != null && defaultHeadcount! > 0)
          ? defaultHeadcount!
          : 0;

  /// Domain alanları (zaman damgaları hariç — repository ekler).
  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type.name,
        'gender': gender.name,
        'dailyWageOverrideKurus': dailyWageOverrideKurus,
        'defaultHeadcount': defaultHeadcount,
        'active': active,
      };
}

/// Liste sırası: önce tür (sabit → gündelik → elebaşı), sonra ada göre.
/// Yoklama ve işçiler ekranı aynı sırayı kullanır.
int compareWorkers(Worker a, Worker b) {
  final byType = a.type.index.compareTo(b.type.index);
  if (byType != 0) return byType;
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

WorkerType _typeFromName(Object? v) => WorkerType.values.firstWhere(
      (t) => t.name == v,
      orElse: () => WorkerType.gundelik,
    );

Gender _genderFromName(Object? v) => Gender.values.firstWhere(
      (g) => g.name == v,
      orElse: () => Gender.male,
    );

int? _asIntOrNull(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return null;
}

/// Yapılan iş modeli (`workspaces/main/fields/{uuid}`, kural §5 soft-delete).
///
/// Yoklamada "o gün ne işi yapıldı" seçimi için kullanıcı tanımlı iş listesi
/// (çapa, sulama, budama…). Tarladan (bkz. [Plot]) BAĞIMSIZDIR: bir günün
/// kaydında ikisi de ayrı ayrı, isteğe bağlı olarak seçilir.
///
/// FIRESTORE ADI TARİHSELDİR: koleksiyon `fields`, yoklama alanları
/// `fieldId`/`fieldName`. 2026-08-07'ye kadar bu liste "Tarlalar" adıyla
/// kullanılıyordu ama içine hep YAPILAN İŞ yazılıyordu. Ayrım yapılırken liste
/// olduğu yerde bırakılıp anlamı düzeltildi (gerçek tarlalar yeni `plots`
/// koleksiyonuna açıldı) → tek bir dokümana dokunmadan tüm geçmiş doğru tarafa
/// geçti. Firestore adlarını değiştirmek binlerce yoklama kaydında göç
/// gerektirirdi (offline cihazlarda veri kaybı riski).
///
/// Saf/değişmez (freezed). Firestore eşlemesi [fromDoc]/[toMap] ile elle yapılır;
/// zaman damgaları repository'de eklenir.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'job.freezed.dart';

@freezed
abstract class Job with _$Job {
  const Job._();

  const factory Job({
    required String id,
    required String name,

    /// Soft-delete bayrağı (kural §5): silinen iş seçim listesinden düşer;
    /// geçmiş yoklama kayıtlarındaki denormalize adı (fieldName) okunur kalır.
    @Default(true) bool active,
  }) = _Job;

  /// Firestore dokümanından okur. Eksik/bozuk alanlar güvenli varsayılana düşer.
  factory Job.fromDoc(String id, Map<String, dynamic>? data) {
    final m = data ?? const {};
    return Job(
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
int compareJobs(Job a, Job b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

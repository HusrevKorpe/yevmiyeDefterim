/// Ana Sayfa "Bugün Özeti" sağlayıcısı (kural §7).
///
/// Bugünün yoklamasını işçi cinsiyetleriyle birleştirir. Cinsiyet yoklama
/// kaydında tutulmaz; işçi listesinden (workerId → Gender) çözülür.
///
/// **İki akış da CANLI dinlenir.** Eskiden cinsiyet haritası `watchAll().first`
/// ile TEK SEFER okunup donduruluyordu: uygulama açıkken listeye eklenen işçi
/// haritada olmadığından, o işçi bugün çalışsa bile ne kadına ne erkeğe sayılırdı
/// (28 Temmuz 2026: gün içinde eklenen 3 kadın yüzünden "9 kadın çalıştı" yerine
/// "Kadın 6" göründü — yoklama ve kazanç doğruydu, yalnız Ana Sayfa sayacı eksikti).
/// Artık işçi listesi değişince özet kendiliğinden güncellenir.
///
/// İşçi listesi (cinsiyet haritası) yüklenene kadar veri YAYINLANMAZ → "6 işçi /
/// 0 kadın" gibi yanlış ara durum görünmez; onun yerine yükleniyor göstergesi kalır.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attendance/application/attendance_providers.dart';
import '../../workers/application/workers_providers.dart';
import '../../workers/data/worker.dart';
import 'day_summary.dart';

/// Bugünün özeti (cinsiyet ayrıştırılmış). Seçili tarihten bağımsız.
///
/// Türetilmiş (Provider) — kendi Firestore dinleyicisini AÇMAZ, uygulamanın
/// zaten dinlediği işçi ve bugün-yoklaması akışlarını birleştirir.
final Provider<AsyncValue<DaySummary>> todaySummaryProvider =
    Provider<AsyncValue<DaySummary>>((ref) {
  final workers = ref.watch(workersStreamProvider);
  final attendance = ref.watch(todayAttendanceProvider);

  // Hata öncelikli: AsyncRetry "Yeniden Dene" kutusunu göstersin.
  if (workers case AsyncError(:final error, :final stackTrace)) {
    return AsyncError<DaySummary>(error, stackTrace);
  }
  if (attendance case AsyncError(:final error, :final stackTrace)) {
    return AsyncError<DaySummary>(error, stackTrace);
  }

  // İşçiler gelmeden özet yayınlama (cinsiyetler 0'dan başlamasın).
  final list = workers.asData?.value;
  if (list == null) return const AsyncLoading<DaySummary>();

  final genderById = <String, Gender>{for (final w in list) w.id: w.gender};
  return attendance.whenData(
    (records) => summarizeDay(records, genderById: genderById),
  );
});

/// Ana Sayfa "Yeniden Dene": özeti besleyen İKİ kaynağı da yeniden aboneler.
/// (Özet artık türetilmiş → kendisini invalidate etmek akışları yeniden kurmaz.)
void refreshTodaySummary(WidgetRef ref) {
  ref.invalidate(workersStreamProvider);
  ref.invalidate(todayAttendanceProvider);
}

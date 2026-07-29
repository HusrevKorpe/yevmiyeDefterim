/// Kalıntı işçi verisini temizleme (deneme kaydı silme).
///
/// Aylık yoklama tablosunun satırları **yoklama kayıtlarından** türetilir: işçi
/// İşçiler listesinden silinse bile o ayda kaydı varsa satırı kalır (geçmiş
/// kaybolmasın diye — bkz. `monthly_grid.dart`). Deneme amaçlı açılıp sonra
/// silinen işçi de böyle kalıcı bir satır bırakır; onu tablodan kaldırmanın tek
/// yolu kayıtlarının kendisini silmektir.
///
/// YIKICI ve geri alınamaz → yalnız artık kullanımda olmayan (kalıcı silinmiş
/// ya da pasif) işçilerde açıktır ve çağıran onay almakla yükümlüdür.
library;

import '../../advances/data/advance_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../data/worker_repository.dart';

/// Temizlikte silinen kayıt sayıları (kullanıcıya özet mesaj için).
class WorkerPurgeResult {
  const WorkerPurgeResult({
    required this.attendanceCount,
    required this.advanceCount,
  });

  final int attendanceCount;
  final int advanceCount;

  bool get isEmpty => attendanceCount == 0 && advanceCount == 0;

  /// "12 yoklama, 2 avans kaydı silindi" — sıfır olan tür yazılmaz.
  String get summary {
    final parts = <String>[
      if (attendanceCount > 0) '$attendanceCount yoklama',
      if (advanceCount > 0) '$advanceCount avans',
    ];
    if (parts.isEmpty) return 'Silinecek kayıt bulunamadı';
    return '${parts.join(', ')} kaydı silindi';
  }
}

/// [workerId] işçisinin TÜM yoklama ve avans kayıtlarını (her ay, her gün)
/// siler; işçi dokümanı hâlâ duruyorsa (pasif) onu da kaldırır.
///
/// Yoklama önce silinir: asıl amaç satırı tablodan düşürmek, avans silinemese
/// bile tablo temizlenmiş olur. Offline'da silmeler yerel önbelleğe anında
/// uygulanır, senkron arkaplanda tamamlanır (bkz. `deleteDocsInBatches`).
Future<WorkerPurgeResult> purgeWorkerRecords({
  required AttendanceRepository attendance,
  required AdvanceRepository advances,
  required WorkerRepository workers,
  required String workerId,
}) async {
  final attendanceCount = await attendance.deleteByWorker(workerId);
  final advanceCount = await advances.deleteByWorker(workerId);
  // Pasif işçi kaydı da gitsin — kayıtları kalmayan deneme işçisi "Pasif
  // İşçiler"de boş bir satır olarak durmasın. Doküman yoksa (kalıcı silinmişti)
  // Firestore'da no-op'tur.
  await workers.delete(workerId);
  return WorkerPurgeResult(
    attendanceCount: attendanceCount,
    advanceCount: advanceCount,
  );
}

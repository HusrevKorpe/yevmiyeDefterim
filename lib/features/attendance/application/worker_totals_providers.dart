/// Çalışma özeti (tüm zaman) sağlayıcıları (kural §7).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../advances/application/advance_providers.dart';
import '../../workers/application/workers_providers.dart';
import '../data/attendance_record.dart';
import 'attendance_providers.dart';
import 'worker_totals.dart';

/// TÜM zamanın yoklama kayıtları — yalnız Çalışma Özeti ekranı içindir.
///
/// `isAutoDispose:true` (bellek/okuma notu, §7 ölçek): bu akış koleksiyonun
/// TAMAMINI dinler. Ekran PUSH edilen bir sayfa olduğundan kapanınca (pop)
/// abonelik kapanır ve kayıtlar bellekten boşalır; aksi halde oturum boyunca
/// tüm geçmiş bellekte asılı kalırdı. Dönüşte Firestore önbelleğinden anında
/// gelir.
final allAttendanceProvider = StreamProvider<List<AttendanceRecord>>(
  isAutoDispose: true,
  (ref) => ref.watch(attendanceRepositoryProvider).watchAll(),
);

/// Hazır işçi-toplamları tablosu (memoize): [buildWorkerTotals] yalnız girdiler
/// (kayıtlar / işçiler) değişince çalışır, her yeniden çizimde değil.
///
/// Yükleme/hata durumları korunur; `.value` ile önceki veri tutulur → veri
/// yenilenirken tam-ekran spinner titremesi olmaz (aylık tablodaki desen).
final workerTotalsProvider = Provider<AsyncValue<WorkerTotalsTable>>(
  isAutoDispose: true,
  (ref) {
    final recordsAsync = ref.watch(allAttendanceProvider);
    final workersAsync = ref.watch(workersStreamProvider);
    // "Hesabı görüldü" işareti — avans yükü tabloyu BEKLETMEZ (boş harita = işaretsiz).
    final settledThrough = ref.watch(settledThroughByWorkerProvider);

    if (recordsAsync.hasError) {
      return AsyncError(
          recordsAsync.error!, recordsAsync.stackTrace ?? StackTrace.current);
    }
    if (workersAsync.hasError) {
      return AsyncError(
          workersAsync.error!, workersAsync.stackTrace ?? StackTrace.current);
    }
    final records = recordsAsync.value;
    final workers = workersAsync.value;
    if (records == null || workers == null) return const AsyncLoading();
    return AsyncData(buildWorkerTotals(
      workers: workers,
      records: records,
      settledThroughByWorker: settledThrough,
    ));
  },
);

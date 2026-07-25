/// İşçi geçmişi Riverpod sağlayıcıları (kural §7).
///
/// İşçiye özel yoklama (aralıksız, tek-alan sorgu) ve avans geçmişi.
/// Avans tüm-akıştan client-side süzülür (az kayıt). Toplamlar saf
/// [buildWorkerHistorySummary] ile türetilir.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../advances/application/advance_providers.dart';
import '../../advances/data/advance.dart';
import '../../attendance/application/attendance_providers.dart';
import '../../attendance/data/attendance_record.dart';
import 'worker_history.dart';

/// Bir işçinin tüm yoklama kayıtları, yeni→eski sıralı.
final attendanceByWorkerProvider =
    StreamProvider.family<List<AttendanceRecord>, String>((ref, workerId) {
  return ref
      .watch(attendanceRepositoryProvider)
      .watchByWorker(workerId)
      .map((records) {
    final sorted = [...records]..sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  });
});

/// Bir işçinin avansları, yeni→eski sıralı (tüm-akıştan süzülür).
final advancesByWorkerProvider =
    Provider.family<List<Advance>, String>((ref, workerId) {
  final all = ref.watch(advancesStreamProvider).asData?.value ?? const [];
  return all.where((a) => a.workerId == workerId).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
});

/// İşçi geçmiş toplamları — saf özet.
final workerHistorySummaryProvider =
    Provider.family<WorkerHistorySummary, String>((ref, workerId) {
  return buildWorkerHistorySummary(
    attendance:
        ref.watch(attendanceByWorkerProvider(workerId)).asData?.value ??
            const [],
    advances: ref.watch(advancesByWorkerProvider(workerId)),
  );
});

/// İşçi geçmişi kaynak akışlarının birleşik durumu (kural §8: sonsuz spinner /
/// yutulan hata yerine yükleniyor→veri / hata→"Yeniden Dene").
///
/// Yoklama ve avans her zaman izlenir (avans 2026-07-23'te kısıtlı hesaba da
/// açıldı). Herhangi biri hata verirse → [AsyncError]; hepsi hazır →
/// [AsyncData]; aksi → [AsyncLoading].
final workerHistoryStateProvider =
    Provider.family<AsyncValue<void>, String>((ref, workerId) {
  final attendance = ref.watch(attendanceByWorkerProvider(workerId));
  final advances = ref.watch(advancesStreamProvider);

  for (final src in [attendance, advances]) {
    if (src.hasError) {
      return AsyncError<void>(src.error!, src.stackTrace ?? StackTrace.current);
    }
  }
  if (attendance.hasValue && advances.hasValue) {
    return const AsyncData<void>(null);
  }
  return const AsyncLoading<void>();
});

/// İşçi geçmişi Riverpod sağlayıcıları (kural §7).
///
/// İşçiye özel yoklama (aralıksız, tek-alan sorgu), avans ve hakediş geçmişi.
/// Avans/hakediş tüm-akıştan client-side süzülür (az kayıt). Toplamlar saf
/// [buildWorkerHistorySummary] ile türetilir.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../advances/application/advance_providers.dart';
import '../../advances/data/advance.dart';
import '../../attendance/application/attendance_providers.dart';
import '../../attendance/data/attendance_record.dart';
import '../../payroll/application/payroll_providers.dart';
import '../../payroll/data/payroll.dart';
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

/// Bir işçinin ödenen hakedişleri, yeni→eski sıralı (tüm-akıştan süzülür).
final payrollsByWorkerProvider =
    Provider.family<List<Payroll>, String>((ref, workerId) {
  final all = ref.watch(payrollsStreamProvider).asData?.value ?? const [];
  return all.where((p) => p.workerId == workerId).toList()
    ..sort((a, b) => b.paidDate.compareTo(a.paidDate));
});

/// İşçi geçmiş toplamları — saf özet.
final workerHistorySummaryProvider =
    Provider.family<WorkerHistorySummary, String>((ref, workerId) {
  return buildWorkerHistorySummary(
    attendance:
        ref.watch(attendanceByWorkerProvider(workerId)).asData?.value ??
            const [],
    advances: ref.watch(advancesByWorkerProvider(workerId)),
    payrolls: ref.watch(payrollsByWorkerProvider(workerId)),
  );
});

/// İşçi yoklama geçmişi yükleniyor mu?
final workerHistoryLoadingProvider =
    Provider.family<bool, String>((ref, workerId) {
  return ref.watch(attendanceByWorkerProvider(workerId)).isLoading ||
      ref.watch(advancesStreamProvider).isLoading ||
      ref.watch(payrollsStreamProvider).isLoading;
});

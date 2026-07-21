/// Aylık yoklama tablosu sağlayıcıları (kural §7).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date.dart';
import '../../workers/application/workers_providers.dart';
import '../data/attendance_record.dart';
import 'attendance_providers.dart';
import 'monthly_grid.dart';

/// Aylık tablo ekranının seçili ayı (`'yyyy-MM'`), varsayılan içinde bulunulan ay.
class SelectedMonthNotifier extends Notifier<String> {
  @override
  String build() => currentMonthIso();

  void set(String monthIso) => state = monthIso;
  void shift(int months) => state = shiftMonthIso(state, months);
  void thisMonth() => state = currentMonthIso();
}

final NotifierProvider<SelectedMonthNotifier, String> selectedMonthProvider =
    NotifierProvider<SelectedMonthNotifier, String>(SelectedMonthNotifier.new);

/// Seçili ayın tüm yoklama kayıtları (ay ilk günü → son günü, uçlar dahil).
/// Tek-alan aralık sorgusu (`watchByRange`) → composite index gerekmez.
final StreamProvider<List<AttendanceRecord>> monthlyAttendanceProvider =
    StreamProvider<List<AttendanceRecord>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  return ref.watch(attendanceRepositoryProvider).watchByRange(
        firstDayOfMonthIsoFor(month),
        lastDayOfMonthIsoFor(month),
      );
});

/// Hazır işçi×gün matrisi (memoize). `buildMonthlyGrid` yalnız girdiler
/// (ay / kayıtlar / işçiler) değişince ÇALIŞIR — ekranın her yeniden çiziminde
/// (tema, scroll, vb.) değil. Böylece ağır gruplama+sıralama her build'de
/// tekrarlanmaz (kural §7; report/payroll ekranlarındaki desenle aynı).
///
/// Yükleme/hata durumları korunur: kayıtlar ya da işçiler hata verirse hata,
/// ikisi de henüz veri vermediyse yükleme; `.value` ile yeniden abonelik
/// (ay değişimi) sırasında önceki veri tutulur → tam-ekran spinner titremesi yok.
final Provider<AsyncValue<MonthlyAttendanceGrid>> monthlyGridProvider =
    Provider<AsyncValue<MonthlyAttendanceGrid>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  final recordsAsync = ref.watch(monthlyAttendanceProvider);
  final workersAsync = ref.watch(workersStreamProvider);

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
  if (records == null || workers == null) {
    return const AsyncLoading();
  }
  return AsyncData(
    buildMonthlyGrid(monthIso: month, workers: workers, records: records),
  );
});

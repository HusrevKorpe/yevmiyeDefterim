/// Aylık yoklama tablosu sağlayıcıları (kural §7).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date.dart';
import '../data/attendance_record.dart';
import 'attendance_providers.dart';

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

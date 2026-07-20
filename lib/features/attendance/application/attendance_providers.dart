/// Yoklama Riverpod sağlayıcıları (kural §7).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date.dart';
import '../../../core/firestore/firestore_providers.dart';
import '../data/attendance_record.dart';
import '../data/attendance_repository.dart';

/// Yoklama deposu. Testlerde `overrideWithValue(...)`.
final Provider<AttendanceRepository> attendanceRepositoryProvider =
    Provider<AttendanceRepository>(
  (ref) => FirestoreAttendanceRepository(ref.watch(firestoreProvider)),
);

/// Yoklama ekranının seçili günü (`'yyyy-MM-dd'`), varsayılan bugün.
class SelectedDateNotifier extends Notifier<String> {
  @override
  String build() => todayIso();

  void set(String isoDate) => state = isoDate;
  void shift(int days) => state = shiftIsoDate(state, days);
  void today() => state = todayIso();
}

final NotifierProvider<SelectedDateNotifier, String> selectedDateProvider =
    NotifierProvider<SelectedDateNotifier, String>(SelectedDateNotifier.new);

/// Seçili günün yoklama kayıtları.
final StreamProvider<List<AttendanceRecord>> attendanceForSelectedDateProvider =
    StreamProvider<List<AttendanceRecord>>((ref) {
  final date = ref.watch(selectedDateProvider);
  return ref.watch(attendanceRepositoryProvider).watchByDate(date);
});

/// Bugünün yoklama kayıtları — Ana Sayfa özeti için (seçili tarihten bağımsız).
final StreamProvider<List<AttendanceRecord>> todayAttendanceProvider =
    StreamProvider<List<AttendanceRecord>>(
  (ref) => ref.watch(attendanceRepositoryProvider).watchByDate(todayIso()),
);

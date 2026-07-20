/// Hakediş Riverpod sağlayıcıları (kural §7).
///
/// Dönem seçimi → o dönemin yoklaması (aralık sorgusu) + açık avanslar →
/// saf hesaplayıcı ile hakediş satırları türetilir.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date.dart';
import '../../../core/firestore/firestore_providers.dart';
import '../../advances/application/advance_providers.dart';
import '../../attendance/application/attendance_providers.dart';
import '../../attendance/data/attendance_record.dart';
import '../data/payroll.dart';
import '../data/payroll_repository.dart';
import 'payroll_calculator.dart';

/// Hakediş deposu. Testlerde `overrideWithValue(FakePayrollRepository(...))`.
final Provider<PayrollRepository> payrollRepositoryProvider =
    Provider<PayrollRepository>(
  (ref) => FirestorePayrollRepository(ref.watch(firestoreProvider)),
);

/// Seçili hakediş dönemi (uçlar dahil, `'yyyy-MM-dd'`).
class PayrollPeriod {
  const PayrollPeriod(this.start, this.end);

  final String start;
  final String end;

  @override
  bool operator ==(Object other) =>
      other is PayrollPeriod && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Dönem seçimi. Varsayılan: içinde bulunulan ayın 1'i → bugün.
class PayrollPeriodNotifier extends Notifier<PayrollPeriod> {
  @override
  PayrollPeriod build() => PayrollPeriod(firstDayOfMonthIso(), todayIso());

  void setStart(String iso) {
    // Başlangıç bitişten sonra olamaz.
    final end = iso.compareTo(state.end) > 0 ? iso : state.end;
    state = PayrollPeriod(iso, end);
  }

  void setEnd(String iso) {
    final start = iso.compareTo(state.start) < 0 ? iso : state.start;
    state = PayrollPeriod(start, iso);
  }

  /// Preset: içinde bulunulan ay (1'i → bugün).
  void thisMonth() =>
      state = PayrollPeriod(firstDayOfMonthIso(), todayIso());

  /// Preset: içinde bulunulan hafta (Pazartesi → bugün).
  void thisWeek() => state = PayrollPeriod(startOfWeekIso(), todayIso());
}

final NotifierProvider<PayrollPeriodNotifier, PayrollPeriod>
    payrollPeriodProvider =
    NotifierProvider<PayrollPeriodNotifier, PayrollPeriod>(
  PayrollPeriodNotifier.new,
);

/// Seçili dönemin yoklama kayıtları (aralık sorgusu).
final StreamProvider<List<AttendanceRecord>> attendanceInPeriodProvider =
    StreamProvider<List<AttendanceRecord>>((ref) {
  final period = ref.watch(payrollPeriodProvider);
  return ref
      .watch(attendanceRepositoryProvider)
      .watchByRange(period.start, period.end);
});

/// Dönem hakediş satırları — saf hesaplayıcıdan türetilir (kural §4).
/// Yoklama veya avans henüz yüklenmediyse boş liste.
final Provider<List<PayrollLine>> payrollLinesProvider =
    Provider<List<PayrollLine>>((ref) {
  final period = ref.watch(payrollPeriodProvider);
  final attendance =
      ref.watch(attendanceInPeriodProvider).asData?.value ?? const [];
  final advances = ref.watch(advancesStreamProvider).asData?.value ?? const [];
  return buildPayrollLines(
    periodStart: period.start,
    periodEnd: period.end,
    attendance: attendance,
    advances: advances,
  );
});

/// Tüm hakediş kayıtları (geçmiş) — özet/geçmiş için.
final StreamProvider<List<Payroll>> payrollsStreamProvider =
    StreamProvider<List<Payroll>>(
  (ref) => ref.watch(payrollRepositoryProvider).watchAll(),
);

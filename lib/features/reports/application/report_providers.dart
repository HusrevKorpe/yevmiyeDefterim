/// Rapor Riverpod sağlayıcıları (kural §7).
///
/// Rapor dönemi Kasa/Hakediş döneminden BAĞIMSIZDIR (kullanıcı raporu farklı
/// aralıkta görebilir). Dönem → yoklama/kasa aralık sorgusu + tüm avans/hakediş
/// akışı → saf [buildPeriodReport]. Avans/hakediş builder içinde süzülür.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date.dart';
import '../../advances/application/advance_providers.dart';
import '../../attendance/application/attendance_providers.dart';
import '../../attendance/data/attendance_record.dart';
import '../../ledger/application/ledger_providers.dart';
import '../../ledger/data/ledger_entry.dart';
import '../../payroll/application/payroll_providers.dart';
import 'period_report.dart';

/// Seçili rapor dönemi (uçlar dahil, `'yyyy-MM-dd'`).
class ReportPeriod {
  const ReportPeriod(this.start, this.end);

  final String start;
  final String end;

  @override
  bool operator ==(Object other) =>
      other is ReportPeriod && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Dönem seçimi. Varsayılan: içinde bulunulan ayın 1'i → bugün.
class ReportPeriodNotifier extends Notifier<ReportPeriod> {
  @override
  ReportPeriod build() => ReportPeriod(firstDayOfMonthIso(), todayIso());

  void setStart(String iso) {
    final end = iso.compareTo(state.end) > 0 ? iso : state.end;
    state = ReportPeriod(iso, end);
  }

  void setEnd(String iso) {
    final start = iso.compareTo(state.start) < 0 ? iso : state.start;
    state = ReportPeriod(start, iso);
  }

  /// Preset: içinde bulunulan ay (1'i → bugün).
  void thisMonth() => state = ReportPeriod(firstDayOfMonthIso(), todayIso());

  /// Preset: içinde bulunulan hafta (Pazartesi → bugün).
  void thisWeek() => state = ReportPeriod(startOfWeekIso(), todayIso());
}

final NotifierProvider<ReportPeriodNotifier, ReportPeriod> reportPeriodProvider =
    NotifierProvider<ReportPeriodNotifier, ReportPeriod>(
  ReportPeriodNotifier.new,
);

/// Seçili dönemin yoklama kayıtları (aralık sorgusu).
final StreamProvider<List<AttendanceRecord>> reportAttendanceProvider =
    StreamProvider<List<AttendanceRecord>>((ref) {
  final p = ref.watch(reportPeriodProvider);
  return ref
      .watch(attendanceRepositoryProvider)
      .watchByRange(p.start, p.end);
});

/// Seçili dönemin kasa kayıtları (aralık sorgusu).
final StreamProvider<List<LedgerEntry>> reportLedgerProvider =
    StreamProvider<List<LedgerEntry>>((ref) {
  final p = ref.watch(reportPeriodProvider);
  return ref.watch(ledgerRepositoryProvider).watchByRange(p.start, p.end);
});

/// Dönem raporu — saf [buildPeriodReport]'tan türetilir; kaynak akışların
/// durumunu tek [AsyncValue] olarak birleştirir (kural §8: sonsuz spinner /
/// yutulan hata yerine yükleniyor→veri / hata→"Yeniden Dene").
///
/// - Herhangi bir kaynak **hata** verirse → [AsyncError] (ekran hata kutusu
///   gösterir; boş dönem ile karışmaz).
/// - Hepsi değer verene kadar → [AsyncLoading] (spinner + zaman aşımı, kilitli
///   kural / erişilemez sunucu durumunda takılıp kalmaz).
/// - Hepsi hazır → [AsyncData] (aralık dışını builder süzer).
final Provider<AsyncValue<PeriodReport>> reportProvider =
    Provider<AsyncValue<PeriodReport>>((ref) {
  final p = ref.watch(reportPeriodProvider);
  final attendance = ref.watch(reportAttendanceProvider);
  final advances = ref.watch(advancesStreamProvider);
  final payrolls = ref.watch(payrollsStreamProvider);
  final ledger = ref.watch(reportLedgerProvider);

  for (final src in [attendance, advances, payrolls, ledger]) {
    if (src.hasError) {
      return AsyncError<PeriodReport>(
          src.error!, src.stackTrace ?? StackTrace.current);
    }
  }
  if (attendance.hasValue &&
      advances.hasValue &&
      payrolls.hasValue &&
      ledger.hasValue) {
    return AsyncData(buildPeriodReport(
      startIso: p.start,
      endIso: p.end,
      attendance: attendance.requireValue,
      advances: advances.requireValue,
      payrolls: payrolls.requireValue,
      ledger: ledger.requireValue,
    ));
  }
  return const AsyncLoading<PeriodReport>();
});

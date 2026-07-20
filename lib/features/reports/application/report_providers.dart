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

/// Dönem raporu — saf [buildPeriodReport]'tan türetilir. Veri yüklenmediyse
/// boş özet döner (builder aralık dışını süzer).
final Provider<PeriodReport> reportProvider = Provider<PeriodReport>((ref) {
  final p = ref.watch(reportPeriodProvider);
  return buildPeriodReport(
    startIso: p.start,
    endIso: p.end,
    attendance: ref.watch(reportAttendanceProvider).asData?.value ?? const [],
    advances: ref.watch(advancesStreamProvider).asData?.value ?? const [],
    payrolls: ref.watch(payrollsStreamProvider).asData?.value ?? const [],
    ledger: ref.watch(reportLedgerProvider).asData?.value ?? const [],
  );
});

/// Rapor verisi henüz yükleniyor mu? (Herhangi bir kaynak beklemede.)
final Provider<bool> reportLoadingProvider = Provider<bool>((ref) {
  return ref.watch(reportAttendanceProvider).isLoading ||
      ref.watch(reportLedgerProvider).isLoading ||
      ref.watch(advancesStreamProvider).isLoading ||
      ref.watch(payrollsStreamProvider).isLoading;
});

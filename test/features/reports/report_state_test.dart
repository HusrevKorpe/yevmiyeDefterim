import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/ledger/data/ledger_entry.dart';
import 'package:yevmiye_defterim/features/payroll/application/payroll_providers.dart';
import 'package:yevmiye_defterim/features/payroll/data/payroll.dart';
import 'package:yevmiye_defterim/features/reports/application/period_report.dart';
import 'package:yevmiye_defterim/features/reports/application/report_providers.dart';

/// [reportProvider] birleşik durumu (kural §8): sonsuz spinner / yutulan hata
/// yerine yükleniyor→veri, hata→AsyncError. Bu, "her sayfa dönüyor" / hatayı
/// "kayıt yok" sanma olayının regresyon kilididir.
void main() {
  /// Kaynak akışları verilen container'ı kurar, dinleyici bağlar (akışlar
  /// tüketilsin) ve olay döngüsünü birkaç tur çevirip [reportProvider]'ın son
  /// durumunu döndürür.
  Future<AsyncValue<PeriodReport>> resolveReport({
    required Stream<List<AttendanceRecord>> attendance,
    required Stream<List<LedgerEntry>> ledger,
    required Stream<List<Advance>> advances,
    required Stream<List<Payroll>> payrolls,
  }) async {
    final c = ProviderContainer(overrides: [
      reportAttendanceProvider.overrideWith((ref) => attendance),
      reportLedgerProvider.overrideWith((ref) => ledger),
      advancesStreamProvider.overrideWith((ref) => advances),
      payrollsStreamProvider.overrideWith((ref) => payrolls),
    ]);
    addTearDown(c.dispose);
    final sub = c.listen(reportProvider, (_, _) {});
    addTearDown(sub.close);
    // Stream.value emisyonları mikrotask'larda gelir; birkaç tur çevir.
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return c.read(reportProvider);
  }

  test('tüm kaynaklar değer verince → AsyncData', () async {
    final state = await resolveReport(
      attendance: Stream.value(const []),
      ledger: Stream.value(const []),
      advances: Stream.value(const []),
      payrolls: Stream.value(const []),
    );
    expect(state, isA<AsyncData<PeriodReport>>());
  });

  test('bir kaynak HATA verirse → AsyncError (hata yutulmaz, boş sanılmaz)',
      () async {
    final state = await resolveReport(
      attendance: Stream.error('izin reddedildi'),
      ledger: Stream.value(const []),
      advances: Stream.value(const []),
      payrolls: Stream.value(const []),
    );
    expect(state, isA<AsyncError<PeriodReport>>());
  });

  test('bir kaynak TAKILI kalırsa → AsyncLoading (boş veri değil)', () async {
    final stuck = StreamController<List<AttendanceRecord>>();
    addTearDown(stuck.close);
    final state = await resolveReport(
      attendance: stuck.stream, // hiç emisyon yok → sonsuz "yükleniyor"
      ledger: Stream.value(const []),
      advances: Stream.value(const []),
      payrolls: Stream.value(const []),
    );
    expect(state, isA<AsyncLoading<PeriodReport>>());
    // Kritik: takılı kaynak "veri hazır/boş" olarak DEĞERLENDİRİLMEZ.
    expect(state.hasValue, isFalse);
  });
}

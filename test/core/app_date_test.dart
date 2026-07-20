import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/core/date/app_date.dart';

void main() {
  group('toIsoDate', () {
    test('sıfır dolgulu ay/gün: 2026-01-05', () {
      expect(toIsoDate(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('çift haneli ay/gün: 2026-12-09', () {
      expect(toIsoDate(DateTime(2026, 12, 9)), '2026-12-09');
    });
  });

  group('todayIso — yerel gün (UTC kayması yok)', () {
    test('gece geç saat aynı yerel günde kalır', () {
      expect(todayIso(DateTime(2026, 7, 18, 23, 59)), '2026-07-18');
    });

    test('sabah erken saat aynı yerel günde kalır', () {
      expect(todayIso(DateTime(2026, 7, 18, 0, 1)), '2026-07-18');
    });
  });

  group('parseIsoDate', () {
    test('doğru yerel tarihi verir', () {
      final d = parseIsoDate('2026-07-18');
      expect(d.year, 2026);
      expect(d.month, 7);
      expect(d.day, 18);
    });

    test('round-trip: parse -> format aynı string', () {
      expect(toIsoDate(parseIsoDate('2026-03-01')), '2026-03-01');
    });
  });
}

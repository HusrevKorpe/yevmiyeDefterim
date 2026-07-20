import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/core/ids/ids.dart';

void main() {
  group('attendanceDocId — deterministik yoklama ID', () {
    test('"{date}_{workerId}" formatı', () {
      expect(attendanceDocId('2026-07-18', 'w1'), '2026-07-18_w1');
    });

    test('aynı giriş her zaman aynı ID (çift kayıt olmaz)', () {
      final a = attendanceDocId('2026-07-18', 'abc-123');
      final b = attendanceDocId('2026-07-18', 'abc-123');
      expect(a, b);
    });

    test('farklı işçi => farklı ID', () {
      expect(
        attendanceDocId('2026-07-18', 'w1') ==
            attendanceDocId('2026-07-18', 'w2'),
        isFalse,
      );
    });
  });
}

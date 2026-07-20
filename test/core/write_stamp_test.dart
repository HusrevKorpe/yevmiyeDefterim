import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/core/firestore/write_stamp.dart';

void main() {
  group('revOfData — sürüm ayrıştırma (çakışma tespiti)', () {
    test('alan yoksa 0', () {
      expect(revOfData(null), 0);
      expect(revOfData(const {}), 0);
      expect(revOfData(const {'baska': 1}), 0);
    });

    test('int değeri aynen döner', () {
      expect(revOfData(const {'rev': 5}), 5);
    });

    test('num (double) tam sayıya inilir — bozuk veri çökertmez', () {
      expect(revOfData(const {'rev': 7.0}), 7);
    });

    test('geçersiz tip → 0 (güvenli varsayılan)', () {
      expect(revOfData(const {'rev': 'x'}), 0);
    });
  });
}

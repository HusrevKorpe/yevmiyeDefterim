import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/attendance/application/wage.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

void main() {
  group('resolveWageKurus (kural §4)', () {
    test('erkek → maleWage', () {
      expect(
        resolveWageKurus(
          gender: Gender.male,
          maleWageKurus: 200000,
          femaleWageKurus: 180000,
        ),
        200000,
      );
    });

    test('kadın → femaleWage', () {
      expect(
        resolveWageKurus(
          gender: Gender.female,
          maleWageKurus: 200000,
          femaleWageKurus: 180000,
        ),
        180000,
      );
    });

    test('override her zaman kazanır (cinsiyetten bağımsız)', () {
      expect(
        resolveWageKurus(
          gender: Gender.female,
          overrideKurus: 250000,
          maleWageKurus: 200000,
          femaleWageKurus: 180000,
        ),
        250000,
      );
    });

    test('override 0 ise 0 döner (null değil = kasıtlı sıfır)', () {
      expect(
        resolveWageKurus(
          gender: Gender.male,
          overrideKurus: 0,
          maleWageKurus: 200000,
          femaleWageKurus: 180000,
        ),
        0,
      );
    });

    test('ücret girilmemişse (0) 0 döner', () {
      expect(
        resolveWageKurus(
          gender: Gender.male,
          maleWageKurus: 0,
          femaleWageKurus: 0,
        ),
        0,
      );
    });
  });
}

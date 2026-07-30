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

  // Mesai YEVMİYENİN TERSİ yönde çözülür: tek kaynak Yönetim ekranındaki genel
  // ücrettir; işçi kartındaki alan yalnız istisna (farklı ücret) içindir.
  group('resolveOvertimeRateKurus (mesai saat ücreti)', () {
    test('işçide ücret yoksa genel (Yönetim) ücreti geçerli', () {
      expect(
        resolveOvertimeRateKurus(defaultHourlyKurus: 10000),
        10000,
      );
    });

    test('işçinin kendi ücreti genel ücreti EZER', () {
      expect(
        resolveOvertimeRateKurus(
          workerHourlyKurus: 15000,
          defaultHourlyKurus: 10000,
        ),
        15000,
      );
    });

    // Eski kayıtlarda alan 0 kalmış olabilir; bunu "kasıtlı sıfır" saymak
    // kullanıcının yeni girdiği genel ücreti sessizce yok sayardı.
    test('işçi ücreti 0 ise girilmemiş sayılır → genele düşer', () {
      expect(
        resolveOvertimeRateKurus(
          workerHourlyKurus: 0,
          defaultHourlyKurus: 10000,
        ),
        10000,
      );
    });

    test('hiçbiri girilmemişse 0 (yoklama satırı uyarır)', () {
      expect(resolveOvertimeRateKurus(defaultHourlyKurus: 0), 0);
    });

    test('negatif genel ücret 0 sayılır (eksi para yazılmaz)', () {
      expect(resolveOvertimeRateKurus(defaultHourlyKurus: -500), 0);
    });
  });
}

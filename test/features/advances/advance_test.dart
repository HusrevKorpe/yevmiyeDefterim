import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';

void main() {
  Advance make({String? settled}) => Advance(
        id: 'a1',
        workerId: 'w1',
        workerName: 'Ahmet',
        amountKurus: 150000,
        date: '2026-07-10',
        settledPayrollId: settled,
      );

  group('isOpen', () {
    test('settledPayrollId null → açık', () {
      expect(make().isOpen, isTrue);
    });
    test('settledPayrollId dolu → kapalı', () {
      expect(make(settled: 'p1').isOpen, isFalse);
    });
  });

  group('fromDoc / toMap', () {
    test('round-trip (açık)', () {
      final a = make();
      expect(Advance.fromDoc(a.id, a.toMap()), a);
    });

    test('round-trip (kapalı)', () {
      final a = make(settled: 'p1');
      expect(Advance.fromDoc(a.id, a.toMap()), a);
    });

    test('eksik/bozuk alanlar güvenli varsayılana düşer', () {
      final a = Advance.fromDoc('x', const {});
      expect(a.workerId, '');
      expect(a.workerName, '');
      expect(a.amountKurus, 0);
      expect(a.date, '');
      expect(a.isOpen, isTrue);
    });

    test('double tutar int kuruşa iner', () {
      final a = Advance.fromDoc('x', {'amountKurus': 150000.0});
      expect(a.amountKurus, 150000);
    });
  });
}

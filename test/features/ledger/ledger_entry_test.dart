import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/core/constants/categories.dart';
import 'package:yevmiye_defterim/features/ledger/data/ledger_entry.dart';

void main() {
  LedgerEntry make({LedgerType type = LedgerType.expense, String? note}) =>
      LedgerEntry(
        id: 'l1',
        type: type,
        category: LedgerCategory.maas,
        amountKurus: 400000,
        date: '2026-07-16',
        source: LedgerSource.payroll,
        note: note,
        payrollId: 'p1',
        workerId: 'w1',
        workerName: 'Ahmet',
      );

  group('fromDoc / toMap', () {
    test('round-trip (gider)', () {
      final e = make(note: 'Yevmiye ödemesi');
      expect(LedgerEntry.fromDoc(e.id, e.toMap()), e);
    });

    test('round-trip (gelir)', () {
      final e = make(type: LedgerType.income);
      expect(LedgerEntry.fromDoc(e.id, e.toMap()), e);
    });

    test('eksik alanlar güvenli varsayılana düşer', () {
      final e = LedgerEntry.fromDoc('x', const {});
      expect(e.type, LedgerType.expense);
      expect(e.category, LedgerCategory.genel);
      expect(e.amountKurus, 0);
      expect(e.source, LedgerSource.manual);
    });

    test('bilinmeyen tür → expense', () {
      final e = LedgerEntry.fromDoc('x', {'type': 'saçma'});
      expect(e.type, LedgerType.expense);
    });

    test('elle gelir kaydı round-trip', () {
      final e = LedgerEntry(
        id: 'm1',
        type: LedgerType.income,
        category: LedgerCategory.genel,
        amountKurus: 500000,
        date: '2026-07-18',
        source: LedgerSource.manual,
        note: 'Ürün satışı',
      );
      expect(LedgerEntry.fromDoc(e.id, e.toMap()), e);
    });
  });

  group('getter', () {
    test('isManual — kaynak manual → true', () {
      expect(make().copyWith(source: LedgerSource.manual).isManual, isTrue);
    });

    test('isManual — otomatik kaynak → false', () {
      expect(make().isManual, isFalse); // seed source = payroll
      expect(make().copyWith(source: LedgerSource.elebasi).isManual, isFalse);
    });

    test('isIncome türü yansıtır', () {
      expect(make(type: LedgerType.income).isIncome, isTrue);
      expect(make().isIncome, isFalse);
    });
  });
}

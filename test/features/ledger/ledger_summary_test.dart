import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/core/constants/categories.dart';
import 'package:yevmiye_defterim/features/ledger/application/ledger_summary.dart';
import 'package:yevmiye_defterim/features/ledger/data/ledger_entry.dart';

void main() {
  LedgerEntry income(int kurus, {String cat = LedgerCategory.genel}) =>
      LedgerEntry(
        id: 'i$kurus',
        type: LedgerType.income,
        category: cat,
        amountKurus: kurus,
        date: '2026-07-10',
        source: LedgerSource.manual,
      );

  LedgerEntry expense(int kurus,
          {String cat = LedgerCategory.genel,
          String src = LedgerSource.manual}) =>
      LedgerEntry(
        id: 'e$kurus$cat',
        type: LedgerType.expense,
        category: cat,
        amountKurus: kurus,
        date: '2026-07-10',
        source: src,
      );

  group('summarizeLedger', () {
    test('boş liste → sıfır', () {
      final s = summarizeLedger(const []);
      expect(s.incomeKurus, 0);
      expect(s.expenseKurus, 0);
      expect(s.netKurus, 0);
      expect(s.mazotKurus, 0);
    });

    test('yalnız gelir', () {
      final s = summarizeLedger([income(500000), income(250000)]);
      expect(s.incomeKurus, 750000);
      expect(s.expenseKurus, 0);
      expect(s.netKurus, 750000);
    });

    test('yalnız gider', () {
      final s = summarizeLedger([expense(120000), expense(80000)]);
      expect(s.expenseKurus, 200000);
      expect(s.netKurus, -200000);
    });

    test('karışık — bakiye pozitif', () {
      final s = summarizeLedger([income(1000000), expense(400000)]);
      expect(s.incomeKurus, 1000000);
      expect(s.expenseKurus, 400000);
      expect(s.netKurus, 600000);
    });

    test('karışık — bakiye negatif', () {
      final s = summarizeLedger([income(300000), expense(500000)]);
      expect(s.netKurus, -200000);
    });

    test('kategori kırılımı + mazot toplamı', () {
      final s = summarizeLedger([
        expense(150000, cat: LedgerCategory.mazot),
        expense(90000, cat: LedgerCategory.mazot),
        expense(60000, cat: LedgerCategory.genel),
        // Otomatik maaş gideri de toplama girer (tek kaynak, kural §6).
        expense(400000, cat: LedgerCategory.maas, src: LedgerSource.payroll),
      ]);
      expect(s.mazotKurus, 240000);
      expect(s.expenseByCategory[LedgerCategory.genel], 60000);
      expect(s.expenseByCategory[LedgerCategory.maas], 400000);
      expect(s.expenseKurus, 700000);
    });

    test('gelir mazot kırılımına girmez', () {
      final s = summarizeLedger([income(500000, cat: LedgerCategory.genel)]);
      expect(s.expenseByCategory, isEmpty);
      expect(s.mazotKurus, 0);
    });
  });
}

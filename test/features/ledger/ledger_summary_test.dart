import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/core/constants/categories.dart';
import 'package:yevmiye_defterim/features/ledger/application/ledger_summary.dart';
import 'package:yevmiye_defterim/features/ledger/data/ledger_entry.dart';

void main() {
  LedgerEntry expense(int kurus,
          {String cat = LedgerCategory.genel,
          String src = LedgerSource.manual}) =>
      LedgerEntry(
        id: 'e$kurus$cat',
        category: cat,
        amountKurus: kurus,
        date: '2026-07-10',
        source: src,
      );

  group('summarizeLedger', () {
    test('boş liste → sıfır', () {
      final s = summarizeLedger(const []);
      expect(s.expenseKurus, 0);
      expect(s.mazotKurus, 0);
      expect(s.expenseByCategory, isEmpty);
    });

    test('toplam gider', () {
      final s = summarizeLedger([expense(120000), expense(80000)]);
      expect(s.expenseKurus, 200000);
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

    test('categoryKurus: tamir/bakkal ayrı toplanır, olmayan kategori 0', () {
      final s = summarizeLedger([
        expense(50000, cat: LedgerCategory.tamir),
        expense(30000, cat: LedgerCategory.tamir),
        expense(20000, cat: LedgerCategory.bakkal),
      ]);
      expect(s.categoryKurus(LedgerCategory.tamir), 80000);
      expect(s.categoryKurus(LedgerCategory.bakkal), 20000);
      expect(s.categoryKurus(LedgerCategory.mazot), 0);
      expect(s.expenseKurus, 100000);
    });
  });
}

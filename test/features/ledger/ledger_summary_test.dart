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
  });
}

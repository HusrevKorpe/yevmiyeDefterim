/// Kasa özeti — saf fonksiyon (Firestore'suz → unit test, kural §11).
///
/// Ledger tek kaynaktır: her kayıt (elle gelir/gider + otomatik maaş/elebaşı
/// gideri) tam bir kez toplanır. Avanslar burada YOK (ayrı koleksiyon, kural §6)
/// → çifte sayım olmaz.
library;

import '../../../core/constants/categories.dart';
import '../data/ledger_entry.dart';

class LedgerSummary {
  const LedgerSummary({
    this.incomeKurus = 0,
    this.expenseKurus = 0,
    this.expenseByCategory = const {},
  });

  /// Toplam gelir (kuruş).
  final int incomeKurus;

  /// Toplam gider (kuruş).
  final int expenseKurus;

  /// Gider kategorisine göre kırılım (kategori kodu → kuruş).
  final Map<String, int> expenseByCategory;

  /// Bakiye = gelir − gider (negatif olabilir).
  int get netKurus => incomeKurus - expenseKurus;

  /// Dönemdeki mazot gideri (kuruş) — mazot ayrı takip edilir.
  int get mazotKurus => expenseByCategory[LedgerCategory.mazot] ?? 0;
}

/// Kayıt listesini gelir/gider ve kategori kırılımına göre özetler.
LedgerSummary summarizeLedger(List<LedgerEntry> entries) {
  var income = 0;
  var expense = 0;
  final byCategory = <String, int>{};
  for (final e in entries) {
    if (e.isIncome) {
      income += e.amountKurus;
    } else {
      expense += e.amountKurus;
      byCategory.update(
        e.category,
        (v) => v + e.amountKurus,
        ifAbsent: () => e.amountKurus,
      );
    }
  }
  return LedgerSummary(
    incomeKurus: income,
    expenseKurus: expense,
    expenseByCategory: byCategory,
  );
}

/// Kasa özeti — saf fonksiyon (Firestore'suz → unit test, kural §11).
///
/// Ledger tek kaynaktır: her gider kaydı (elle mazot/genel + otomatik
/// maaş/elebaşı) tam bir kez toplanır. Avanslar burada YOK (ayrı koleksiyon,
/// kural §6) → çifte sayım olmaz. Uygulama gelir takip etmez.
library;

import '../../../core/constants/categories.dart';
import '../data/ledger_entry.dart';

class LedgerSummary {
  const LedgerSummary({
    this.expenseKurus = 0,
    this.expenseByCategory = const {},
  });

  /// Toplam gider (kuruş).
  final int expenseKurus;

  /// Gider kategorisine göre kırılım (kategori kodu → kuruş).
  final Map<String, int> expenseByCategory;

  /// Verilen kategorinin dönem gideri (kuruş).
  int categoryKurus(String category) => expenseByCategory[category] ?? 0;

  /// Dönemdeki mazot gideri (kuruş) — mazot ayrı takip edilir.
  int get mazotKurus => categoryKurus(LedgerCategory.mazot);
}

/// Kayıt listesini toplam gider ve kategori kırılımına göre özetler.
LedgerSummary summarizeLedger(List<LedgerEntry> entries) {
  var expense = 0;
  final byCategory = <String, int>{};
  for (final e in entries) {
    expense += e.amountKurus;
    byCategory.update(
      e.category,
      (v) => v + e.amountKurus,
      ifAbsent: () => e.amountKurus,
    );
  }
  return LedgerSummary(
    expenseKurus: expense,
    expenseByCategory: byCategory,
  );
}

/// Kasa özet kartı — sanatsal degrade "hero" toplam gider kartı (kural §8).
///
/// Dönemin toplam gideri büyük ve öne çıkar. Kendi ekranı olan kategoriler
/// (Mazot/Tamir/Bakkal) > 0 ise şerit olarak listelenir. Gelir takip edilmez.
library;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/constants/categories.dart';
import '../../../../core/money/money.dart';
import '../../../../core/widgets/category_icon.dart';
import '../../application/ledger_summary.dart';

class LedgerSummaryCard extends StatelessWidget {
  const LedgerSummaryCard({
    super.key,
    required this.summary,
    this.showBreakdown = true,
  });

  final LedgerSummary summary;

  /// Toplam giderin altında kategori şeritlerini (Mazot/Tamir/Bakkal) gösterir.
  /// Kasa sayfasında `false` verilerek yalnız toplam gider gösterilir
  /// (kategori ekranlarına app bar'dan gidilir).
  final bool showBreakdown;

  @override
  Widget build(BuildContext context) {
    final gradient = heroGradient(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: heroBottom(context).withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Derinlik için soluk dekoratif daireler (başlık diliyle uyumlu).
          Positioned(top: -30, right: -24, child: _circle(110, 0.10)),
          Positioned(top: 30, right: 40, child: _circle(52, 0.08)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance_wallet,
                        color: Colors.white, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Toplam Gider',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Öne çıkan toplam gider. Büyük sistem fontunda taşmasın diye
              // sığmazsa küçülerek tek satırda kalır.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatKurus(summary.expenseKurus),
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
              ),
              if (showBreakdown)
                for (final c in LedgerCategory.screened)
                  if (summary.categoryKurus(c) > 0) ...[
                    const SizedBox(height: 12),
                    _CategoryStrip(
                      category: c,
                      kurus: summary.categoryKurus(c),
                    ),
                  ],
            ],
          ),
        ],
      ),
    );
  }

  static Widget _circle(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: alpha),
          shape: BoxShape.circle,
        ),
      );
}

/// Bir kategorinin (Mazot/Tamir/Bakkal) toplamını gösteren şerit.
class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.category, required this.kurus});

  final String category;
  final int kurus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Icon(categoryIcon(category), color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Text(
            LedgerCategory.label(category),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                formatKurus(kurus),
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

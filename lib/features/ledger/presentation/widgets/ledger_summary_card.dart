/// Kasa özet kartı — sanatsal degrade "hero" toplam gider kartı (kural §8).
///
/// Dönemin toplam gideri büyük ve öne çıkar. Mazot varsa dokunulabilir şerit
/// olarak Mazot ekranına götürür. Uygulama gelir takip etmez.
library;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/money/money.dart';
import '../../application/ledger_summary.dart';

class LedgerSummaryCard extends StatelessWidget {
  const LedgerSummaryCard({
    super.key,
    required this.summary,
    this.onMazotTap,
    this.showBreakdown = true,
  });

  final LedgerSummary summary;

  /// Mazot şeridine dokununca (yalnız mazot > 0 iken görünür).
  final VoidCallback? onMazotTap;

  /// Toplam giderin altında Mazot şeridini gösterir. Kasa sayfasında `false`
  /// verilerek yalnız toplam gider gösterilir (mazota app bar'dan gidilir).
  final bool showBreakdown;

  @override
  Widget build(BuildContext context) {
    const gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [kHeroTop, kHeroBottom],
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kHeroBottom.withValues(alpha: 0.30),
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
              if (showBreakdown && summary.mazotKurus > 0) ...[
                const SizedBox(height: 16),
                _MazotStrip(kurus: summary.mazotKurus, onTap: onMazotTap),
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

/// Mazot toplamını gösteren, dokununca Mazot ekranını açan şerit.
class _MazotStrip extends StatelessWidget {
  const _MazotStrip({required this.kurus, this.onTap});

  final int kurus;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              const Icon(Icons.local_gas_station, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(
                'Mazot',
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
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.7), size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

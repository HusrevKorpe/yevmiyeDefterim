/// Kasa özet kartı — sanatsal degrade "hero" bakiye kartı (kural §8).
///
/// Bakiye büyük ve öne çıkar: pozitifse yeşil, negatifse kırmızı degrade.
/// Altta Gelir | Gider dikey çizgiyle ayrılır. Mazot varsa dokunulabilir şerit
/// olarak Mazot ekranına götürür.
library;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/money/money.dart';
import '../../application/ledger_summary.dart';

/// Negatif bakiyede kullanılan sıcak (uyarı) degrade tonları.
const Color _dangerTop = Color(0xFFEF5350);
const Color _dangerBottom = Color(0xFFB71C1C);

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

  /// Bakiyenin altındaki Gelir/Gider dökümü ile Mazot şeridini gösterir.
  /// Kasa sayfasında `false` verilerek yalnız toplam bakiye gösterilir.
  final bool showBreakdown;

  @override
  Widget build(BuildContext context) {
    final net = summary.netKurus;
    final positive = net >= 0;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: positive ? const [kHeroTop, kHeroBottom] : const [_dangerTop, _dangerBottom],
    );
    final glowColor = positive ? kHeroBottom : _dangerBottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.30),
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
                    'Kasa Bakiyesi',
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
              // Öne çıkan bakiye. Büyük sistem fontunda taşmasın diye
              // sığmazsa küçülerek tek satırda kalır.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatKurus(net),
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
              if (showBreakdown) ...[
                const SizedBox(height: 14),
                Container(height: 1, color: Colors.white.withValues(alpha: 0.22)),
                const SizedBox(height: 14),
                // Gelir | Gider — aralarındaki dikey çizgi ikisini ayırır.
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _MiniStat(
                          icon: Icons.arrow_upward,
                          label: 'Gelir',
                          value: summary.incomeKurus,
                        ),
                      ),
                      Container(width: 1, color: Colors.white.withValues(alpha: 0.22)),
                      Expanded(
                        child: _MiniStat(
                          icon: Icons.arrow_downward,
                          label: 'Gider',
                          value: summary.expenseKurus,
                          alignEnd: true,
                        ),
                      ),
                    ],
                  ),
                ),
                if (summary.mazotKurus > 0) ...[
                  const SizedBox(height: 16),
                  _MazotStrip(kurus: summary.mazotKurus, onTap: onMazotTap),
                ],
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

/// Degrade kart içinde Gelir/Gider mini istatistiği (beyaz, ikon + tutar).
class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final IconData icon;
  final String label;
  final int value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final cross = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final rowMain = alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start;
    return Column(
      crossAxisAlignment: cross,
      children: [
        Row(
          mainAxisAlignment: rowMain,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 15),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        // Dar sütunda büyük tutar taşmasın; sığmazsa küçülüp tek satırda kalsın.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            formatKurus(value),
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
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

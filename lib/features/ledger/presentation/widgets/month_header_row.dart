/// Giderler listesindeki ay ayracı: "Temmuz 2026 · −₺12.400" (kural §8).
///
/// Liste geçmişi de gösterdiği için ay değişince bu satır girer; sağdaki tutar
/// o AYIN toplam gideridir (tahsilat hariç). Büyük sistem yazısında taşmasın
/// diye iki taraf da FittedBox ile sığdırılır (kural: kesme yerine ölçekle).
library;

import 'package:flutter/material.dart';

import '../../../../core/date/app_date.dart';
import '../../../../core/money/money.dart';
import '../../application/ledger_month_groups.dart';

class MonthHeaderRow extends StatelessWidget {
  const MonthHeaderRow({super.key, required this.group});

  final LedgerMonthGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: double.infinity,
      color: cs.primary.withValues(alpha: 0.07),
      padding: const EdgeInsets.fromLTRB(14, 9, 16, 9),
      child: Row(
        children: [
          // Sol yeşil şerit — ayracı satırlardan ayıran sade işaret.
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatMonthTitle(group.monthIso),
                maxLines: 1,
                softWrap: false,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '−${formatKurus(group.expenseKurus)}',
                maxLines: 1,
                softWrap: false,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kasa liste satırı — gelir/gider kaydı (kural §8: ikon+yazı, büyük/kontrast).
///
/// Gelir yeşil ↑, gider kırmızı ↓. Otomatik (maaş/elebaşı) kayıtlar kilit
/// ikonuyla salt-okunur; elle kayıtlar dokununca düzenlenir.
library;

import 'package:flutter/material.dart';

import '../../../../core/constants/categories.dart';
import '../../../../core/date/app_date.dart';
import '../../../../core/money/money.dart';
import '../../data/ledger_entry.dart';

class LedgerEntryTile extends StatelessWidget {
  const LedgerEntryTile({super.key, required this.entry, this.onTap});

  final LedgerEntry entry;

  /// Dokunma (yalnız elle kayıtlarda düzenleme). Null → salt-okunur.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final income = entry.isIncome;
    final color =
        income ? Colors.green.shade700 : theme.colorScheme.error;
    final sign = income ? '+' : '−';

    // Başlık: kategori etiketi; not varsa alt satırda tarih ile birlikte.
    final title = LedgerCategory.label(entry.category);
    final subtitleParts = <String>[formatHumanDate(entry.date)];
    if (entry.note != null && entry.note!.trim().isNotEmpty) {
      subtitleParts.add(entry.note!.trim());
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(_leadingIcon(income), color: color),
      ),
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: Text(subtitleParts.join(' · ')),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$sign${formatKurus(entry.amountKurus)}',
            style: theme.textTheme.titleMedium
                ?.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
          if (!entry.isManual)
            Icon(Icons.lock_outline,
                size: 14, color: theme.colorScheme.outline),
        ],
      ),
      onTap: onTap,
    );
  }

  IconData _leadingIcon(bool income) {
    if (income) return Icons.arrow_upward;
    if (entry.category == LedgerCategory.mazot) {
      return Icons.local_gas_station;
    }
    return Icons.arrow_downward;
  }
}

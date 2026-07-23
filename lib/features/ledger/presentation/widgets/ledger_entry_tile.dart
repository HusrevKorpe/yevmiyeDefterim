/// Kasa liste satırı — gider/tahsilat kaydı (kural §8: ikon+yazı, kontrast).
///
/// Gider kırmızı ↓ (mazot/tamir/bakkal kendi ikonuyla). Tahsilat (esnafa
/// önden verilen para) yeşil `+` ile ayrışır ("Mazot Tahsilatı"). Otomatik
/// (maaş/elebaşı) kayıtlar kilit ikonuyla salt-okunur; elle kayıtlar
/// dokununca düzenlenir.
library;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/constants/categories.dart';
import '../../../../core/date/app_date.dart';
import '../../../../core/widgets/category_icon.dart';
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
    final tahsilat = entry.isTahsilat;
    final color = tahsilat ? incomeColor(context) : theme.colorScheme.error;

    // Başlık: kategori etiketi (tahsilatta "Mazot Tahsilatı" gibi ayrışır);
    // not varsa alt satırda tarih ile birlikte.
    final label = LedgerCategory.label(entry.category);
    final title = tahsilat ? '$label Tahsilatı' : label;
    final subtitleParts = <String>[formatHumanDate(entry.date)];
    if (entry.note != null && entry.note!.trim().isNotEmpty) {
      subtitleParts.add(entry.note!.trim());
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(_leadingIcon(), color: color),
      ),
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: Text(subtitleParts.join(' · ')),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${tahsilat ? '+' : '−'}${formatKurus(entry.amountKurus)}',
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

  IconData _leadingIcon() =>
      categoryIcon(entry.category, fallback: Icons.arrow_downward);
}

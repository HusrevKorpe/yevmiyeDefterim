/// İşçilik özet kartı — dönem brüt işçilik / verilen avans (§8).
library;

import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../application/period_report.dart';

class ReportLaborCard extends StatelessWidget {
  const ReportLaborCard({super.key, required this.report});

  final PeriodReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.groups, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('İşçilik', style: theme.textTheme.titleMedium),
              ],
            ),
            const Divider(height: 20),
            _Row(
              icon: Icons.receipt_long,
              label: 'Tahakkuk eden brüt',
              value: report.grossLaborKurus,
            ),
            // Mesai brütün İÇİNDEDİR; ayrı satır yalnız "bunun ne kadarı mesai"
            // sorusunu yanıtlar. Hiç mesai girilmediyse satır çıkmaz.
            if (report.hasOvertime) ...[
              const SizedBox(height: 10),
              _Row(
                icon: Icons.more_time,
                // Etiket bilerek kısa: büyük sistem yazısında (2x) uzun etiket
                // üç satıra sarıp tutarla sıkışıyordu. "Brütün içinde" anlamı
                // girinti + soluk stille veriliyor.
                label: 'Mesai (${report.overtimeHours} saat)',
                value: report.overtimeKurus,
                muted: true,
              ),
            ],
            const SizedBox(height: 10),
            _Row(
              icon: Icons.account_balance_wallet,
              label: 'Verilen avans',
              value: report.advancesGivenKurus,
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final int value;

  /// Ana satırın altındaki kırılım satırı (mesai): daha küçük/soluk yazılır ve
  /// içeri girintili durur → brütün içinde olduğu görsel olarak da anlaşılır.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = muted ? theme.colorScheme.onSurfaceVariant : null;
    return Padding(
      padding: EdgeInsets.only(left: muted ? 18 : 0),
      child: Row(
        children: [
          Icon(icon,
              size: muted ? 17 : 20,
              color: muted ? color : theme.colorScheme.outline),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: muted
                  ? theme.textTheme.bodyMedium?.copyWith(color: color)
                  : theme.textTheme.bodyLarge,
            ),
          ),
          // Etiket büyük yazıda sarınca tutara yapışmasın.
          const SizedBox(width: 8),
          Text(
            formatKurus(value),
            style: muted
                ? theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600, color: color)
                : theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

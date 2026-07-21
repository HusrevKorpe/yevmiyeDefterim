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
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.outline),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: theme.textTheme.bodyLarge),
        ),
        Text(
          formatKurus(value),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

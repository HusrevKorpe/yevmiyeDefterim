/// Hakediş satırı — bir işçi/elebaşı için özet + "Öde" (kural §8: onay, net vurgu).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../../application/payroll_calculator.dart';
import '../../application/payroll_view_model.dart';

class PayrollLineTile extends ConsumerWidget {
  const PayrollLineTile({super.key, required this.line});

  final PayrollLine line;

  String get _daysSummary {
    if (line.isCrew) {
      return '${line.crewDays} gün · ${line.crewHeadcountTotal} kişi';
    }
    final parts = <String>[];
    if (line.fullDays > 0) parts.add('${line.fullDays} tam');
    if (line.halfDays > 0) parts.add('${line.halfDays} yarım');
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  Future<void> _confirmAndPay(BuildContext context, WidgetRef ref) async {
    final comp = line.computation;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${line.workerName} — Öde'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Brüt hakediş', formatKurus(comp.grossKurus)),
            if (!line.isCrew && comp.advancesDeductedKurus > 0)
              _row('Avans mahsubu', '− ${formatKurus(comp.advancesDeductedKurus)}'),
            const Divider(),
            _row('Ödenecek net', formatKurus(comp.netPaidKurus), bold: true),
            if (comp.carryoverKurus > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Kalan ${formatKurus(comp.carryoverKurus)} avans gelecek döneme '
                'devredecek.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check),
            label: const Text('Öde'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(payrollViewModelProvider.notifier).pay(line);
    }
  }

  static Widget _row(String label, String value, {bool bold = false}) {
    final weight = bold ? FontWeight.bold : FontWeight.normal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: weight)),
          Text(value, style: TextStyle(fontWeight: weight)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final comp = line.computation;
    final saving =
        ref.watch(payrollViewModelProvider.select((s) => s.isSaving(line.workerId)));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  child: Icon(line.isCrew ? Icons.groups : Icons.person, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.workerName,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(_daysSummary, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Net', style: theme.textTheme.labelSmall),
                    Text(
                      formatKurus(comp.netPaidKurus),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _chip('Brüt ${formatKurus(comp.grossKurus)}'),
                      if (!line.isCrew && comp.advancesDeductedKurus > 0)
                        _chip('Avans − ${formatKurus(comp.advancesDeductedKurus)}'),
                      if (comp.carryoverKurus > 0)
                        _chip('Devir ${formatKurus(comp.carryoverKurus)}',
                            color: theme.colorScheme.errorContainer),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: saving ? null : () => _confirmAndPay(context, ref),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    // Tema tüm FilledButton'lara tam-genişlik min boyut verir;
                    // burada buton bir Row içinde (Expanded değil) olduğundan
                    // sonsuz genişlik dayatılmasın diye min boyut sınırlanır.
                    minimumSize: const Size(0, 44),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.payments, size: 18),
                  label: Text(saving ? 'Ödeniyor…' : 'Öde'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, {Color? color}) {
    return Chip(
      label: Text(text),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelStyle: const TextStyle(fontSize: 11),
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}

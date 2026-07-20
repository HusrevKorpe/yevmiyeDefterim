/// İşçi kazanç satırı — dönem raporunda işçi bazında brüt + gün dökümü (§8).
library;

import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../application/period_report.dart';

class WorkerEarningTile extends StatelessWidget {
  const WorkerEarningTile({super.key, required this.earning});

  final WorkerEarning earning;

  String get _subtitle {
    if (earning.isCrew) {
      return '${earning.crewDays} gün • ${earning.crewHeadcountTotal} kişi-gün';
    }
    final parts = <String>[];
    if (earning.fullDays > 0) parts.add('${earning.fullDays} tam');
    if (earning.halfDays > 0) parts.add('${earning.halfDays} yarım');
    return parts.isEmpty ? '—' : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        child: Icon(earning.isCrew ? Icons.groups : Icons.person),
      ),
      title: Text(
        earning.workerName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(_subtitle),
      trailing: Text(
        formatKurus(earning.grossKurus),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

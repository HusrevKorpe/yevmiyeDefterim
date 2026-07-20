/// Avanslar ekranı — açık avanslar (işçiye göre) + ekle (plan §4, kural §8).
///
/// Hakediş ekranından açılır. Kapanmış (mahsup edilmiş) avanslar ayrı bölümde
/// salt-okunur gösterilir (kural §6).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/date/app_date.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/async_retry.dart';
import '../../../core/widgets/gradient_header.dart';
import '../application/advance_providers.dart';
import '../data/advance.dart';
import 'advance_edit_screen.dart';

class AdvancesScreen extends ConsumerWidget {
  const AdvancesScreen({super.key});

  void _openEdit(BuildContext context, {Advance? advance}) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => AdvanceEditScreen(advance: advance),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advancesAsync = ref.watch(advancesStreamProvider);

    return Scaffold(
      appBar: GradientAppBar(
        title: 'Avanslar',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10, left: 2),
            child: _AddButton(onPressed: () => _openEdit(context)),
          ),
        ],
      ),
      body: AsyncRetry(
        value: advancesAsync,
        onRetry: () => ref.invalidate(advancesStreamProvider),
        message: 'Avanslar yüklenemedi. İnternet bağlantınızı kontrol edin.',
        data: (advances) {
          if (advances.isEmpty) return const _EmptyAdvances();
          final open = advances.where((a) => a.isOpen).toList();
          final settled = advances.where((a) => !a.isOpen).toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              ..._openSection(context, open),
              if (settled.isNotEmpty) _settledSection(context, settled),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _openSection(BuildContext context, List<Advance> open) {
    if (open.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Açık (mahsup edilmemiş) avans yok.',
            textAlign: TextAlign.center,
          ),
        ),
      ];
    }
    // İşçiye göre grupla, işçi adına göre sırala.
    final byWorker = <String, List<Advance>>{};
    for (final a in open) {
      (byWorker[a.workerId] ??= []).add(a);
    }
    final workerIds = byWorker.keys.toList()
      ..sort((x, y) => byWorker[x]!.first.workerName
          .toLowerCase()
          .compareTo(byWorker[y]!.first.workerName.toLowerCase()));

    return [
      const _Header('Açık Avanslar'),
      for (final id in workerIds)
        _WorkerAdvancesCard(
          advances: byWorker[id]!,
          onTapAdvance: (a) => _openEdit(context, advance: a),
        ),
    ];
  }

  Widget _settledSection(BuildContext context, List<Advance> settled) {
    settled.sort((a, b) => b.date.compareTo(a.date));
    return ExpansionTile(
      leading: const Icon(Icons.check_circle_outline),
      title: Text('Kapanmış Avanslar (${settled.length})'),
      children: [
        for (final a in settled)
          ListTile(
            title: Text(a.workerName),
            subtitle: Text(formatHumanDate(a.date)),
            trailing: Text(
              formatKurus(a.amountKurus),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

/// Başlıktaki küçük beyaz "Avans Ver" hapı — degrade üzerinde güçlü kontrast
/// (İşçiler/Kasa ekranlarındaki "Ekle" ile aynı desen).
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 18, color: kHeroBottom),
              SizedBox(width: 4),
              Text(
                'Avans Ver',
                style: TextStyle(
                  color: kHeroBottom,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkerAdvancesCard extends StatelessWidget {
  const _WorkerAdvancesCard({
    required this.advances,
    required this.onTapAdvance,
  });

  final List<Advance> advances;
  final void Function(Advance) onTapAdvance;

  @override
  Widget build(BuildContext context) {
    final sorted = [...advances]..sort((a, b) => b.date.compareTo(a.date));
    final total = sorted.fold<int>(0, (s, a) => s + a.amountKurus);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(sorted.first.workerName,
                style: theme.textTheme.titleMedium),
            trailing: Text(
              formatKurus(total),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const Divider(height: 1),
          for (final a in sorted)
            ListTile(
              dense: true,
              title: Text(formatHumanDate(a.date)),
              trailing: Text(formatKurus(a.amountKurus)),
              onTap: () => onTapAdvance(a),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: SectionTitle(text),
    );
  }
}

class _EmptyAdvances extends StatelessWidget {
  const _EmptyAdvances();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.account_balance_wallet_outlined,
                  size: 42, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz avans yok',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Sağ üstteki “Avans Ver” ile başlayın.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

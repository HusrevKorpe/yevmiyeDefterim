/// Mazot ekranı — yalnız mazot gider kayıtları + toplam (plan §5, kural §8).
///
/// Kasa'dan açılır. Tüm dönemlerin mazot kayıtlarını gösterir (yakıt sürekli
/// takip edilir). Kayıt eklemek/düzenlemek Kasa kayıt ekranını kullanır.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/categories.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/async_retry.dart';
import '../../../core/widgets/gradient_header.dart';
import '../application/ledger_providers.dart';
import '../data/ledger_entry.dart';
import 'ledger_edit_screen.dart';
import 'widgets/ledger_entry_tile.dart';

class MazotScreen extends ConsumerWidget {
  const MazotScreen({super.key});

  void _openEdit(BuildContext context, {LedgerEntry? entry}) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => LedgerEditScreen(
          entry: entry,
          initialCategory: LedgerCategory.mazot,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ledgerStreamProvider);
    final mazot = ref.watch(mazotEntriesProvider);
    final total = mazot.fold<int>(0, (s, e) => s + e.amountKurus);

    return Scaffold(
      appBar: const GradientAppBar(title: 'Mazot'),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-mazot',
        onPressed: () => _openEdit(context),
        icon: const Icon(Icons.add),
        label: const Text('Mazot Ekle'),
      ),
      body: AsyncRetry(
        value: async,
        onRetry: () => ref.invalidate(ledgerStreamProvider),
        message: 'Mazot kayıtları yüklenemedi. İnternet bağlantınızı kontrol edin.',
        data: (_) {
          if (mazot.isEmpty) return const _EmptyMazot();
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              _TotalCard(total: total, count: mazot.length),
              const SizedBox(height: 4),
              for (final (i, e) in mazot.indexed) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                LedgerEntryTile(
                  entry: e,
                  onTap:
                      e.isManual ? () => _openEdit(context, entry: e) : null,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total, required this.count});

  final int total;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.local_gas_station, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Toplam mazot ($count kayıt)',
                  style: theme.textTheme.titleMedium),
            ),
            const SizedBox(width: 8),
            Text(
              formatKurus(total),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMazot extends StatelessWidget {
  const _EmptyMazot();

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
              child: Icon(Icons.local_gas_station,
                  size: 42, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz mazot kaydı yok',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Sağ alttaki “Mazot Ekle” ile başlayın.',
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

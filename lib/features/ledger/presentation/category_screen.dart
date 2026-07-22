/// Kategori ekranı — tek kategorinin gider kayıtları + toplam (plan §5, kural §8).
///
/// Kasa'dan açılır (Mazot/Tamir/Bakkal — [LedgerCategory.screened]). Tüm
/// dönemlerin kayıtlarını gösterir (bu giderler sürekli takip edilir). Kayıt
/// eklemek/düzenlemek Kasa kayıt ekranını kullanır (kategori ön seçili).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/constants/categories.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/async_retry.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/gradient_header.dart';
import '../application/ledger_providers.dart';
import '../data/ledger_entry.dart';
import 'ledger_edit_screen.dart';
import 'widgets/ledger_entry_tile.dart';

class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key, required this.category});

  /// [LedgerCategory] kodu (mazot/tamir/bakkal).
  final String category;

  void _openEdit(BuildContext context, {LedgerEntry? entry}) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => LedgerEditScreen(
          entry: entry,
          initialCategory: category,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = LedgerCategory.label(category);
    final async = ref.watch(ledgerStreamProvider);
    final entries = ref.watch(categoryEntriesProvider(category));
    final total = entries.fold<int>(0, (s, e) => s + e.amountKurus);

    return Scaffold(
      appBar: GradientAppBar(
        title: label,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10, left: 2),
            child: _AddButton(onPressed: () => _openEdit(context)),
          ),
        ],
      ),
      body: AsyncRetry(
        value: async,
        onRetry: () => ref.invalidate(ledgerStreamProvider),
        message:
            '$label kayıtları yüklenemedi. İnternet bağlantınızı kontrol edin.',
        data: (_) {
          if (entries.isEmpty) return _EmptyCategory(category: category);
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              _TotalCard(
                category: category,
                total: total,
                count: entries.length,
              ),
              const SizedBox(height: 4),
              for (final (i, e) in entries.indexed) ...[
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
  const _TotalCard({
    required this.category,
    required this.total,
    required this.count,
  });

  final String category;
  final int total;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = LedgerCategory.label(category).toLowerCase();
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(categoryIcon(category), color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Toplam $label ($count kayıt)',
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

class _EmptyCategory extends StatelessWidget {
  const _EmptyCategory({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = LedgerCategory.label(category).toLowerCase();
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
              child: Icon(categoryIcon(category),
                  size: 42, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz $label kaydı yok',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Üstteki “Ekle” ile başlayın.',
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

/// Başlıktaki küçük beyaz "Ekle" hapı — degrade üzerinde güçlü kontrast.
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
                'Ekle',
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

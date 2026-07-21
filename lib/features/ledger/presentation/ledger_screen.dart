/// Kasa — dönem gider listesi + toplam + Mazot ekranı (plan §5, kural §8).
///
/// Otomatik hakediş kayıtları salt-okunur; elle kayıtlar dokununca düzenlenir.
/// Avanslar Kasa'da YOK (ayrı akış, kural §6) → çifte sayım olmaz.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/ledger_providers.dart';
import '../data/ledger_entry.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/async_retry.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/period_range_selector.dart';
import 'ledger_edit_screen.dart';
import 'mazot_screen.dart';
import 'widgets/ledger_entry_tile.dart';
import 'widgets/ledger_summary_card.dart';

class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key});

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  void _openEdit(BuildContext context, {LedgerEntry? entry}) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => LedgerEditScreen(entry: entry),
      ),
    );
  }

  void _openMazot(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => const MazotScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(ledgerPeriodProvider);
    final periodNotifier = ref.read(ledgerPeriodProvider.notifier);
    final async = ref.watch(ledgerInPeriodProvider);
    final summary = ref.watch(ledgerSummaryProvider);

    return Scaffold(
      appBar: GradientAppBar(
        actions: [
          IconButton(
            onPressed: () => _openMazot(context),
            color: Colors.white,
            tooltip: 'Mazot',
            icon: const Icon(Icons.local_gas_station),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10, left: 2),
            child: _AddButton(onPressed: () => _openEdit(context)),
          ),
        ],
      ),
      body: Column(
        children: [
          PeriodRangeSelector(
            startIso: period.start,
            endIso: period.end,
            onSetStart: periodNotifier.setStart,
            onSetEnd: periodNotifier.setEnd,
          ),
          LedgerSummaryCard(
            summary: summary,
            showBreakdown: false,
          ),
          Expanded(
            child: AsyncRetry(
              value: async,
              onRetry: () => ref.invalidate(ledgerInPeriodProvider),
              message: 'Kasa yüklenemedi. İnternet bağlantınızı kontrol edin.',
              data: (entries) {
                final visible = entries;
                if (visible.isEmpty) return const _EmptyView();
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: visible.length,
                  separatorBuilder: (context, i) => const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, i) {
                    final e = visible[i];
                    return LedgerEntryTile(
                      entry: e,
                      onTap: e.isManual
                          ? () => _openEdit(context, entry: e)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
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

class _EmptyView extends StatelessWidget {
  const _EmptyView();

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
              'Bu dönemde kayıt yok',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Üstteki “Ekle” ile gider girin ya da dönemi değiştirin.',
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

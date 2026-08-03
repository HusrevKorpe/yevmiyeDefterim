/// Kasa — gider listesi + toplam + kategori ekranları (plan §5, kural §8).
///
/// Liste TÜM kayıtları geçmişiyle beraber gösterir; ay değişince araya
/// "Temmuz 2026 · −₺X" ayracı girer (dönem süzgeci yok — dönem raporu Rapor
/// ekranında). Otomatik hakediş kayıtları salt-okunur; elle kayıtlar dokununca
/// düzenlenir. Avanslar Kasa'da YOK (ayrı akış, kural §6) → çifte sayım olmaz.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/ledger_month_groups.dart';
import '../application/ledger_providers.dart';
import '../application/ledger_summary.dart';
import '../data/ledger_entry.dart';
import '../../../app/theme.dart';
import '../../../core/constants/categories.dart';
import '../../../core/widgets/async_retry.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/gradient_header.dart';
import 'category_screen.dart';
import 'ledger_edit_screen.dart';
import 'widgets/ledger_entry_tile.dart';
import 'widgets/ledger_summary_card.dart';
import 'widgets/month_header_row.dart';

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

  void _openCategory(BuildContext context, String category) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryScreen(category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ledgerSortedProvider);

    return Scaffold(
      appBar: GradientAppBar(
        actions: [
          // Kendi ekranı olan kategoriler (Mazot/Tamir/Bakkal) kısayolları.
          for (final c in LedgerCategory.screened)
            IconButton(
              onPressed: () => _openCategory(context, c),
              color: Colors.white,
              tooltip: LedgerCategory.label(c),
              icon: Icon(categoryIcon(c)),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 10, left: 2),
            child: _AddButton(onPressed: () => _openEdit(context)),
          ),
        ],
      ),
      body: AsyncRetry(
        value: async,
        onRetry: () => ref.invalidate(ledgerStreamProvider),
        message: 'Giderler yüklenemedi. İnternet bağlantınızı kontrol edin.',
        // Özet kartı da yalnız veri hazır olunca (data closure) türetilir.
        // Yükleniyor/hata durumunda ₺0'lık "boş özet" GÖSTERİLMEZ; bunun
        // yerine spinner ya da "Yeniden Dene" çıkar (kural §8 — rapor ve
        // işçi geçmişi ekranlarıyla aynı: hata yutulmaz, boş sanılmaz).
        data: (entries) {
          final summary = summarizeLedger(entries);
          return Column(
            children: [
              LedgerSummaryCard(
                summary: summary,
                showBreakdown: false,
              ),
              Expanded(
                child: entries.isEmpty
                    ? const _EmptyView()
                    : _MonthGroupedList(
                        groups: groupLedgerByMonth(entries),
                        onEdit: (e) => _openEdit(context, entry: e),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Ay ay gruplanmış gider listesi: her ayın başında [MonthHeaderRow] ayracı,
/// altında o ayın kayıtları (yeni→eski).
class _MonthGroupedList extends StatelessWidget {
  const _MonthGroupedList({required this.groups, required this.onEdit});

  final List<LedgerMonthGroup> groups;

  /// Elle kayda dokunulunca düzenleme ekranı.
  final ValueChanged<LedgerEntry> onEdit;

  @override
  Widget build(BuildContext context) {
    // Başlık + kayıt satırları tek düz listeye açılır → ListView.builder yalnız
    // görünen satırları çizer (uzun geçmişte de akıcı kalır).
    final rows = <_Row>[];
    for (final g in groups) {
      rows.add(_HeaderRow(g));
      for (final (i, e) in g.entries.indexed) {
        rows.add(_EntryRow(e, divider: i > 0));
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        return switch (row) {
          _HeaderRow(:final group) => MonthHeaderRow(group: group),
          _EntryRow(:final entry, :final divider) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (divider)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                LedgerEntryTile(
                  entry: entry,
                  onTap: entry.isManual ? () => onEdit(entry) : null,
                ),
              ],
            ),
        };
      },
    );
  }
}

/// Düz listedeki satır: ay başlığı ya da gider kaydı.
sealed class _Row {
  const _Row();
}

class _HeaderRow extends _Row {
  const _HeaderRow(this.group);
  final LedgerMonthGroup group;
}

class _EntryRow extends _Row {
  const _EntryRow(this.entry, {required this.divider});
  final LedgerEntry entry;

  /// Ay içindeki ilk kayıt hariç satır arası çizgi.
  final bool divider;
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
              'Henüz gider kaydı yok',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Üstteki “Ekle” ile ilk gideri girin.',
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

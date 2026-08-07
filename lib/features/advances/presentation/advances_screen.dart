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
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/gradient_header.dart';
import '../application/advance_providers.dart';
import '../application/advance_view_model.dart';
import '../application/settlement_groups.dart';
import '../data/advance.dart';
import 'advance_edit_screen.dart';
import 'widgets/advance_note_chip.dart';

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
              if (settled.isNotEmpty)
                _settledSection(context, ref, open: open, settled: settled),
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
          // Kart açık/kapalı durumu işçiye bağlı kalsın (liste sırası değişince
          // durum başka işçinin kartına geçmesin).
          key: ValueKey('avans-karti-$id'),
          advances: byWorker[id]!,
          onTapAdvance: (a) => _openEdit(context, advance: a),
        ),
    ];
  }

  /// Hesabı görülen (kapatılan) işçiler — işçi + kapanış tarihine göre gruplu.
  /// Hakediş rafta olduğundan pratikte tüm kapanmışlar "hesap görüldü" yoluyla
  /// gelir; eski hakediş mahsupları (varsa) salt-okunur satır olarak gösterilir.
  Widget _settledSection(
    BuildContext context,
    WidgetRef ref, {
    required List<Advance> open,
    required List<Advance> settled,
  }) {
    final legacy = settled.where((a) => !a.isManuallySettled).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // İşçi + kapanış OLAYINA göre grupla (her grup = tek "hesap görüldü"), en yeni
    // önce sırala, yalnız işçinin EN SON kapanışını geri-alınabilir işaretle
    // (devir zinciri newest-first çözülür). Karar saf fonksiyonda (testli).
    final groups = buildSettlementGroups(settled);

    return ExpansionTile(
      leading: const Icon(Icons.check_circle_outline),
      title: Text('Hesabı Görülenler (${groups.length})'),
      children: [
        for (final g in groups)
          _SettledWorkerCard(
            advances: g.advances,
            onReopen: g.reopenable
                ? () => _reopen(
                      context,
                      ref,
                      g.advances,
                      carryoverIds: _carryoverIdsFor(g.advances, open),
                    )
                : null,
          ),
        for (final a in legacy)
          ListTile(
            title: Text(a.workerName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mahsup edildi • ${formatHumanDate(a.date)}'),
                if (a.note != null && a.note!.isNotEmpty)
                  AdvanceNoteChip(a.note!),
              ],
            ),
            trailing: Text(
              formatKurus(a.amountKurus),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  /// Grubun kapanışında oluşan ve hâlâ açık duran devir kayıtları — geri
  /// almada birlikte silinir ki aynı alacak iki kez sayılmasın. Devir, kapanış
  /// OLAYININ kimliğine ([settlementKey]) bağlıdır → aynı gün başka bir
  /// kapanışın devrine dokunulmaz.
  List<String> _carryoverIdsFor(List<Advance> group, List<Advance> open) {
    final key = group.first.settlementKey;
    if (key == null) return const [];
    final workerId = group.first.workerId;
    return [
      for (final a in open)
        if (a.workerId == workerId && a.isCarryoverOf(key)) a.id,
    ];
  }

  /// "Hesap görüldü"yü geri alır — grubun avansları yeniden açık olur;
  /// kapanışta oluşan devir kaydı (varsa) silinir.
  Future<void> _reopen(
    BuildContext context,
    WidgetRef ref,
    List<Advance> group, {
    List<String> carryoverIds = const [],
  }) async {
    final name = group.first.workerName;
    final devirText = carryoverIds.isEmpty
        ? ''
        : ' Kapanışta oluşan devir kaydı da silinecek.';
    final ok = await showConfirmDialog(
      context,
      title: 'Geri al',
      message: '$name için “hesap görüldü” geri alınsın mı? Avansları yeniden '
          'açık (devrediyor) olarak görünecek.$devirText',
      confirmLabel: 'Geri Al',
      icon: Icons.undo,
      accent: Theme.of(context).colorScheme.primary,
    );
    if (!ok) return;
    await ref
        .read(accountSettlementViewModelProvider.notifier)
        .reopen(group.map((a) => a.id).toList(), deleteIds: carryoverIds);
  }
}

/// Hesabı görülen bir işçinin kartı — "alacak kalmadı" + kapatılan avanslar +
/// Geri Al. Grup, tek bir "hesap görüldü" olayıdır (aynı işçi + aynı tarih).
class _SettledWorkerCard extends StatelessWidget {
  const _SettledWorkerCard({required this.advances, required this.onReopen});

  final List<Advance> advances;

  /// `null` → bu işçinin daha yeni bir kapanışı var; geri almak devir zincirini
  /// bozacağından Geri Al gizlenir (yerine bilgilendirme notu). Bkz. _settledSection.
  final VoidCallback? onReopen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final green = incomeColor(context);
    final sorted = [...advances]..sort((a, b) => b.date.compareTo(a.date));
    final total = sorted.fold<int>(0, (s, a) => s + a.amountKurus);
    final settledDate = sorted.first.settledDate;
    final settledText = settledDate == null
        ? 'Hesap görüldü · alacak kalmadı'
        : 'Hesap görüldü • ${formatHumanDateNoWeekday(settledDate)} · alacak kalmadı';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: green.withValues(alpha: 0.14),
              child: Icon(Icons.check, color: green),
            ),
            title: Text(sorted.first.workerName,
                style: theme.textTheme.titleMedium),
            subtitle: Text(
              settledText,
              style: theme.textTheme.bodySmall?.copyWith(color: green),
            ),
            trailing: Text(
              formatKurus(total),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          for (final a in sorted)
            ListTile(
              dense: true,
              title: Text(formatHumanDate(a.date)),
              subtitle: a.note == null || a.note!.isEmpty
                  ? null
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: AdvanceNoteChip(a.note!),
                    ),
              trailing: Text(formatKurus(a.amountKurus)),
            ),
          if (onReopen != null)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 4),
                child: TextButton.icon(
                  onPressed: onReopen,
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('Geri Al'),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 15, color: theme.hintColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Daha yeni bir hesap kapanışı var. Geri almak için önce '
                      'onu geri alın.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.hintColor),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
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

/// Bir işçinin açık avansları. Birden fazla avans varsa kart KAPALI başlar —
/// yalnız tek satır (ad + toplam + "N avans") görünür; başlığa dokununca
/// avansların tamamı açılır. Tek avanslı kart zaten kısa olduğundan hep açıktır.
class _WorkerAdvancesCard extends StatefulWidget {
  const _WorkerAdvancesCard({
    super.key,
    required this.advances,
    required this.onTapAdvance,
  });

  final List<Advance> advances;
  final void Function(Advance) onTapAdvance;

  @override
  State<_WorkerAdvancesCard> createState() => _WorkerAdvancesCardState();
}

class _WorkerAdvancesCardState extends State<_WorkerAdvancesCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.advances]
      ..sort((a, b) => b.date.compareTo(a.date));
    final total = sorted.fold<int>(0, (s, a) => s + a.amountKurus);
    final theme = Theme.of(context);
    final collapsible = sorted.length > 1;
    final showRows = !collapsible || _expanded;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(sorted.first.workerName,
                style: theme.textTheme.titleMedium),
            subtitle: collapsible
                ? Text(
                    _expanded
                        ? '${sorted.length} avans'
                        : '${sorted.length} avans • son '
                            '${formatHumanDateNoWeekday(sorted.first.date)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatKurus(total),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (collapsible)
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.expand_more, color: theme.hintColor),
                  ),
              ],
            ),
            onTap: collapsible
                ? () => setState(() => _expanded = !_expanded)
                : null,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: showRows
                ? Column(
                    children: [
                      const Divider(height: 1),
                      for (final a in sorted)
                        ListTile(
                          dense: true,
                          title: Text(formatHumanDate(a.date)),
                          subtitle: a.note == null || a.note!.isEmpty
                              ? null
                              : Align(
                                  alignment: Alignment.centerLeft,
                                  child: AdvanceNoteChip(a.note!),
                                ),
                          trailing: Text(formatKurus(a.amountKurus)),
                          onTap: () => widget.onTapAdvance(a),
                        ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
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

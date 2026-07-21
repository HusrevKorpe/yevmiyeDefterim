/// İşçiler ekranı — tür bazında gruplu liste, ekle/düzenle (plan §5, kural §8).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/async_retry.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../auth/application/user_access.dart';
import '../application/workers_providers.dart';
import '../data/worker.dart';
import 'worker_detail_screen.dart';
import 'worker_edit_screen.dart';

class WorkersScreen extends ConsumerWidget {
  const WorkersScreen({super.key});

  /// Yeni işçi ekle (FAB) — doğrudan düzenleme ekranı.
  void _openAdd(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => const WorkerEditScreen(),
      ),
    );
  }

  /// İşçiye dokun → geçmiş/detay ekranı (düzenleme oradaki kalem butonunda).
  void _openDetail(BuildContext context, Worker worker) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkerDetailScreen(worker: worker),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workersAsync = ref.watch(workersStreamProvider);

    return Scaffold(
      appBar: GradientAppBar(
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10, left: 2),
            child: _AddButton(onPressed: () => _openAdd(context)),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AsyncRetry(
          value: workersAsync,
          onRetry: () => ref.invalidate(workersStreamProvider),
          message: 'İşçiler yüklenemedi. İnternet bağlantınızı kontrol edin.',
          data: (workers) {
            if (workers.isEmpty) return const _EmptyWorkers();
            final active = workers.where((w) => w.active).toList();
            final passive = workers.where((w) => !w.active).toList();
            return ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                for (final type in WorkerType.values)
                  ..._section(context, type, active),
                if (passive.isNotEmpty) _passiveSection(context, passive),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _section(
    BuildContext context,
    WorkerType type,
    List<Worker> active,
  ) {
    final group = active.where((w) => w.type == type).toList();
    if (group.isEmpty) return const [];
    return [
      _Header('${type.label} (${group.length})'),
      for (final w in group)
        _WorkerTile(worker: w, onTap: () => _openDetail(context, w)),
    ];
  }

  Widget _passiveSection(BuildContext context, List<Worker> passive) {
    return ExpansionTile(
      leading: const Icon(Icons.person_off_outlined),
      title: Text('Pasif İşçiler (${passive.length})'),
      children: [
        for (final w in passive)
          _WorkerTile(
            worker: w,
            onTap: () => _openDetail(context, w),
          ),
      ],
    );
  }
}

/// Başlıktaki küçük beyaz "Ekle" hapı — degrade üzerinde güçlü kontrast
/// (Kasa ekranındaki ile aynı desen).
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

class _WorkerTile extends ConsumerWidget {
  const _WorkerTile({required this.worker, required this.onTap});

  final Worker worker;
  final VoidCallback onTap;

  String _subtitleText(bool canSeeMoney) {
    if (worker.type.isCrew) {
      return worker.crewSize > 0 ? '${worker.crewSize} kişilik ekip' : 'Elebaşı';
    }
    // Kısıtlı hesap ücret göremez → yalnız cinsiyet gösterilir.
    if (!canSeeMoney) return worker.gender.label;
    final wage = worker.dailyWageOverrideKurus;
    final wageText =
        wage == null ? 'Varsayılan ücret' : '${formatKurus(wage)} özel ücret';
    return '${worker.gender.label} • $wageText';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSeeMoney = ref.watch(canSeeMoneyProvider);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    worker.type.isCrew ? Icons.groups : Icons.person,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker.name,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitleText(canSeeMoney),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyWorkers extends StatelessWidget {
  const _EmptyWorkers();

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
              child:
                  Icon(Icons.groups, size: 42, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz işçi yok',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Sağ üstteki “Ekle” ile başlayın.',
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

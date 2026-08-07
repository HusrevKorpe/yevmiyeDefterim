/// Tarla ve İş yönetim ekranı (/yoklama/tarlalar) — yoklamadaki iki çip
/// şeridinin kaynağı.
///
/// TEK sayfa, İKİ bölüm: üstte **Tarlalar** ("nerede"), altında **Yapılan
/// İşler** ("ne"). Sekme yok — tek akışta kaydırılır, tarla eklendikçe işler
/// bölümü aşağı kayar. Her bölümün kendi "Ekle" düğmesi başlığındadır.
///
/// Yoklamada Tam/Yarım (elebaşında kişi sayısı) girilince bu iki liste satırın
/// altında ayrı ayrı çip olarak çıkar; ikisi de İSTEĞE BAĞLI ve birbirinden
/// bağımsızdır. Silme soft-delete'tir (kural §5): geçmiş yoklama kayıtlarındaki
/// denormalize ad okunur kalır.
///
/// NOT: "Yapılan İşler" listesi Firestore'da tarihsel `fields` koleksiyonudur
/// (bkz. [Job]) — 2026-08-07 tarla/iş ayrımından önce tek liste vardı, adı
/// "Tarlalar"dı ama içine hep yapılan iş yazılıyordu. Liste yerinde bırakılıp
/// anlamı düzeltildi, gerçek tarlalar yeni `plots` koleksiyonuna açıldı → tüm
/// geçmiş göç edilmeden doğru tarafa geçti.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ids/ids.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/async_retry.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/gradient_header.dart';
import '../application/jobs_providers.dart';
import '../application/plots_providers.dart';
import '../data/job.dart';
import '../data/plot.dart';
import 'widgets/tag_chips.dart';

class PlotsJobsScreen extends ConsumerWidget {
  const PlotsJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plotsAsync = ref.watch(plotsStreamProvider);
    final jobsAsync = ref.watch(jobsStreamProvider);

    return Scaffold(
      appBar: const GradientAppBar(title: 'Tarla ve İşler'),
      // İki liste TEK kaydırma akışında: tarlalar yukarıdan aşağı dizilir,
      // yapılan işler onların altından devam eder (tarla eklendikçe aşağı kayar).
      body: AsyncRetry(
        value: plotsAsync,
        onRetry: () => ref.invalidate(plotsStreamProvider),
        message: 'Tarlalar yüklenemedi. İnternet bağlantınızı kontrol edin.',
        data: (plots) => AsyncRetry(
          value: jobsAsync,
          onRetry: () => ref.invalidate(jobsStreamProvider),
          message: 'İşler yüklenemedi. İnternet bağlantınızı kontrol edin.',
          data: (jobs) {
            final activePlots = plots.where((p) => p.active).toList();
            final activeJobs = jobs.where((j) => j.active).toList();
            return ListView(
              padding: const EdgeInsets.only(top: 4, bottom: 32),
              children: [
                _SectionHeader(
                  icon: kPlotIcon,
                  title: 'Tarlalar',
                  hint: 'Kim nerede çalıştı',
                  addLabel: 'Tarla Ekle',
                  onAdd: () => _editPlot(context, ref),
                ),
                if (activePlots.isEmpty)
                  const _EmptySection(
                    icon: kPlotIcon,
                    message: 'Henüz tarla eklenmedi. Ekleyince yoklamada '
                        'tarla çipleri çıkar.',
                  )
                else
                  for (var i = 0; i < activePlots.length; i++)
                    _Tile(
                      icon: kPlotIcon,
                      name: activePlots[i].name,
                      last: i == activePlots.length - 1,
                      onEdit: () => _editPlot(context, ref, activePlots[i]),
                      onDelete: () => _deletePlot(context, ref, activePlots[i]),
                    ),
                const SizedBox(height: 8),
                _SectionHeader(
                  icon: kJobIcon,
                  title: 'Yapılan İşler',
                  hint: 'O gün ne işi yapıldı',
                  addLabel: 'İş Ekle',
                  onAdd: () => _editJob(context, ref),
                ),
                if (activeJobs.isEmpty)
                  const _EmptySection(
                    icon: kJobIcon,
                    message: 'Henüz iş eklenmedi. Ekleyince yoklamada iş '
                        'çipleri çıkar.',
                  )
                else
                  for (var i = 0; i < activeJobs.length; i++)
                    _Tile(
                      icon: kJobIcon,
                      name: activeJobs[i].name,
                      last: i == activeJobs.length - 1,
                      onEdit: () => _editJob(context, ref, activeJobs[i]),
                      onDelete: () => _deleteJob(context, ref, activeJobs[i]),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Tarla ekle (existing null) / ad düzenle — ortak sanatsal [showInputDialog].
  Future<void> _editPlot(BuildContext context, WidgetRef ref,
      [Plot? existing]) async {
    final name = await showInputDialog(
      context,
      title: existing == null ? 'Tarla Ekle' : 'Tarlayı Düzenle',
      icon: kPlotIcon,
      initialValue: existing?.name ?? '',
      label: 'Tarla adı',
      hint: 'Örn. Aşağı Tarla',
      textCapitalization: TextCapitalization.words,
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;
    final repo = ref.read(plotRepositoryProvider);
    if (existing == null) {
      await repo.add(Plot(id: newId(), name: trimmed));
    } else {
      await repo.update(existing.copyWith(name: trimmed));
    }
  }

  /// İş ekle / ad düzenle.
  Future<void> _editJob(BuildContext context, WidgetRef ref,
      [Job? existing]) async {
    final name = await showInputDialog(
      context,
      title: existing == null ? 'İş Ekle' : 'İşi Düzenle',
      icon: kJobIcon,
      initialValue: existing?.name ?? '',
      label: 'İş adı',
      hint: 'Örn. Çapa',
      textCapitalization: TextCapitalization.words,
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;
    final repo = ref.read(jobRepositoryProvider);
    if (existing == null) {
      await repo.add(Job(id: newId(), name: trimmed));
    } else {
      await repo.update(existing.copyWith(name: trimmed));
    }
  }

  /// Onaylı soft-delete: geçmiş yoklama kayıtlarındaki bilgi silinmez.
  Future<void> _deletePlot(
      BuildContext context, WidgetRef ref, Plot plot) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Tarlayı Sil',
      message: '"${plot.name}" listeden kaldırılacak. Geçmiş yoklama '
          'kayıtlarındaki tarla bilgisi silinmez.',
      confirmLabel: 'Sil',
      icon: Icons.delete_outline,
    );
    if (ok) {
      await ref.read(plotRepositoryProvider).setActive(plot.id, active: false);
    }
  }

  Future<void> _deleteJob(BuildContext context, WidgetRef ref, Job job) async {
    final ok = await showConfirmDialog(
      context,
      title: 'İşi Sil',
      message: '"${job.name}" listeden kaldırılacak. Geçmiş yoklama '
          'kayıtlarındaki iş bilgisi silinmez.',
      confirmLabel: 'Sil',
      icon: Icons.delete_outline,
    );
    if (ok) {
      await ref.read(jobRepositoryProvider).setActive(job.id, active: false);
    }
  }
}

/// Bölüm başlığı: ikon + ad + kısa ipucu + sağda "Ekle". FAB yerine bölüm
/// başına ekleme düğmesi — tek FAB iki listeden hangisine ekleyeceğini
/// soramazdı, sayfa da tek akış olduğu için sekme yok.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.hint,
    required this.addLabel,
    required this.onAdd,
  });

  final IconData icon;
  final String title;
  final String hint;
  final String addLabel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: Text(addLabel),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tek satır (tarla ya da iş) — ikisi de aynı görünümü paylaşır.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.name,
    required this.last,
    required this.onEdit,
    required this.onDelete,
  });

  final IconData icon;
  final String name;

  /// Bölümün son satırı mı? (altına ayraç çizgisi konmaz)
  final bool last;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tile = ListTile(
      onTap: onEdit,
      visualDensity: VisualDensity.compact,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 19, color: theme.colorScheme.primary),
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Düzenle',
            onPressed: onEdit,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 20, color: theme.colorScheme.error),
            tooltip: 'Sil',
            onPressed: onDelete,
          ),
        ],
      ),
    );
    if (last) return tile;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tile,
        const Divider(height: 1, thickness: 0.5, indent: 68, endIndent: 16),
      ],
    );
  }
}

/// Boş bölüm: kart şişkinliği yok, tek satırlık kompakt açıklama.
class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

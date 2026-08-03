part of 'workers_screen.dart';

/// Başlıktaki küçük beyaz hap buton (Ara/Ekle) — degrade üzerinde güçlü
/// kontrast (Kasa ekranındaki ile aynı desen).
class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: kHeroBottom),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
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

class _WorkerTile extends ConsumerWidget {
  const _WorkerTile({
    required this.worker,
    required this.onTap,
    this.canDelete = false,
    this.showBadge = false,
  });

  final Worker worker;
  final VoidCallback onTap;

  /// Sola kaydırma silme kısayolu bu karta eklensin mi (yalnız aktif liste).
  final bool canDelete;

  /// Tür/durum rozeti gösterilsin mi — arama sonucunda grup başlığı olmadığı
  /// için işçinin türü (ya da pasifliği) kartın üstünde belirtilir.
  final bool showBadge;

  /// Kaydırma silme davranışı işçinin durumuna göre değişir:
  /// - Aktif işçi → [_deactivate]: soft-delete, "Pasif İşçiler"e taşınır (geri alınır).
  /// - Pasif işçi → [_purge]: işçi VE tüm kayıtları KALICI silinir (geri alınamaz).
  Future<void> _delete(BuildContext context, WidgetRef ref) =>
      worker.active ? _deactivate(context, ref) : _purge(context, ref);

  /// Aktif işçiyi listeden kaldırır — soft-delete: kayıt Firestore'da kalır
  /// (yoklama/avans geçmişi korunur), yalnız "Pasif İşçiler"e taşınır.
  /// SnackBar'daki "Geri Al" ile geri alınır.
  Future<void> _deactivate(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(workerRepositoryProvider);
    final ok = await showConfirmDialog(
      context,
      title: 'İşçiyi kaldır',
      message: '${worker.name} listeden kaldırılsın mı? Kaydı ve geçmişi '
          'korunur, “Pasif İşçiler”e taşınır.',
      confirmLabel: 'Kaldır',
      icon: Icons.person_off_outlined,
    );
    if (!ok) return;
    await repo.setActive(worker.id, active: false);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('${worker.name} listeden kaldırıldı'),
        action: SnackBarAction(
          label: 'Geri Al',
          onPressed: () => repo.setActive(worker.id, active: true),
        ),
      ),
    );
  }

  /// Zaten pasif olan işçiyi uygulamadan KALICI siler: işçi dokümanı + TÜM
  /// yoklama ve avans kayıtları (bkz. [purgeWorkerRecords]). Kayıtlar işçinin
  /// adını denormalize sakladığından yalnız dokümanı silmek yetmezdi — işçi
  /// aylık tabloda (Excel), raporlarda ve CSV/PDF çıktılarında satır bırakırdı.
  /// Her şey kayıtlardan türediği için kayıtlar gidince işçi HER YERDEN kalkar.
  /// Geri alınamaz → çağrı öncesi onay alınır.
  Future<void> _purge(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showConfirmDialog(
      context,
      title: 'Kalıcı olarak sil',
      message: '${worker.name} ve bu işçiye ait TÜM kayıtlar (tüm aylardaki '
          'yoklamalar ve avanslar) kalıcı olarak silinsin mi? İşçi aylık '
          'tablodan ve raporlardan da kalkar. Bu işlem geri alınamaz.',
      confirmLabel: 'Kalıcı Sil',
      icon: Icons.delete_forever,
      accent: theme.colorScheme.error,
    );
    if (!ok) return;
    try {
      final result = await purgeWorkerRecords(
        attendance: ref.read(attendanceRepositoryProvider),
        advances: ref.read(advanceRepositoryProvider),
        workers: ref.read(workerRepositoryProvider),
        workerId: worker.id,
      );
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            result.isEmpty
                ? '${worker.name} kalıcı olarak silindi'
                : '${worker.name} silindi — ${result.summary}',
          ),
        ),
      );
    } catch (e, s) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('İşçi silinemedi. Tekrar deneyin.'),
      ));
      await logHandledError(e, s,
          reason: 'isci-kalici-silme', info: {'workerId': worker.id});
    }
  }

  String _subtitleText(bool canSeeMoney) {
    if (worker.type.isCrew) {
      final crewText =
          worker.crewSize > 0 ? '${worker.crewSize} kişilik ekip' : 'Elebaşı';
      // Para görebilen hesapta kişi başı yevmiye de gösterilir.
      final rate = worker.dailyWageOverrideKurus;
      if (canSeeMoney && rate != null && rate > 0) {
        return '$crewText • ${formatKurus(rate)}/kişi';
      }
      return crewText;
    }
    // Kısıtlı hesap ücret göremez → yalnız cinsiyet gösterilir.
    if (!canSeeMoney) return worker.gender.label;
    final wage = worker.dailyWageOverrideKurus;
    final wageText =
        wage == null ? 'Yevmiye girilmemiş' : '${formatKurus(wage)} yevmiye';
    return '${worker.gender.label} • $wageText';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSeeMoney = ref.watch(canSeeMoneyProvider);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final Widget card = Material(
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
              if (showBadge) ...[
                _TileBadge(
                  text: worker.active ? worker.type.label : 'Pasif',
                  muted: !worker.active,
                ),
                const SizedBox(width: 4),
              ],
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );

    // Kalıcı silme TÜM yoklama + avans geçmişini yok eder → para göremeyen
    // hesapta kapalıdır (aylık tablodaki temizlikle aynı kural). Aktif işçiyi
    // pasife alma herkese açık kalır: geri alınabilir, veri silmez.
    final bool showSwipe = canDelete && (worker.active || canSeeMoney);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: showSwipe
          ? Slidable(
              key: ValueKey('worker-${worker.id}'),
              // Sola kaydırınca sağdan açılan çöp kutusu butonu; SİLME yalnız
              // butona basınca olur (kaydırma tek başına silmez).
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                extentRatio: 0.28,
                children: [
                  SlidableAction(
                    onPressed: (ctx) => _delete(ctx, ref),
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: Colors.white,
                    icon: worker.active
                        ? Icons.delete_outline
                        : Icons.delete_forever,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ],
              ),
              child: card,
            )
          : card,
    );
  }
}

/// Kartın sağındaki küçük yuvarlak etiket ("Gündelik" / "Pasif").
class _TileBadge extends StatelessWidget {
  const _TileBadge({required this.text, required this.muted});

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color color =
        muted ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

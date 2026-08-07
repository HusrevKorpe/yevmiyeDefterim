/// İşçi detay/geçmiş ekranı (Faz 4) — özet + yoklama/avans/ödeme geçmişi (§8).
///
/// İşçiye dokununca açılır; düzenleme app bar kalem butonundadır. Geçmiş
/// salt-okunurdur (kural §5: pasif işçi de raporda görünür).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/date/app_date.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/async_retry.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../advances/application/advance_providers.dart';
import '../../advances/data/advance.dart';
import '../../advances/presentation/advance_edit_screen.dart';
import '../../advances/presentation/widgets/advance_note_chip.dart';
import '../../auth/application/user_access.dart';
import '../../attendance/data/attendance_record.dart';
import '../application/worker_history.dart';
import '../application/worker_history_providers.dart';
import '../data/worker.dart';
import 'worker_edit_screen.dart';

part 'worker_history_rows.dart';

class WorkerDetailScreen extends ConsumerWidget {
  const WorkerDetailScreen({super.key, required this.worker});

  final Worker worker;

  void _openEdit(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkerEditScreen(worker: worker),
      ),
    );
  }

  /// Bu işçi ön-seçili "Avans Ver" ekranı — arama → detay → avans kısayolu.
  /// Avans kısıtlı hesaba da açık (2026-07-23) → herkes kullanabilir.
  void _openAdvance(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => AdvanceEditScreen(initialWorkerId: worker.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = worker.id;
    final canSeeMoney = ref.watch(canSeeMoneyProvider);
    final historyState = ref.watch(workerHistoryStateProvider(id));
    // Değerler dış build'de izlenir (AsyncData iken hepsi hazır); AsyncRetry'nin
    // data closure'ında ref.watch YOK — o closure build dışında çalışır.
    final summary = ref.watch(workerHistorySummaryProvider(id));
    final attendance =
        ref.watch(attendanceByWorkerProvider(id)).asData?.value ?? const [];
    // Avans kısıtlı hesaba da açık (2026-07-23) → her hesapta izlenir.
    final advances = ref.watch(advancesByWorkerProvider(id));

    return Scaffold(
      appBar: GradientAppBar(
        title: worker.name,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Düzenle',
            onPressed: () => _openEdit(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Başlık kartı her zaman görünür (async değil); geçmiş aşağıda yüklenir.
          _HeaderCard(worker: worker, canSeeMoney: canSeeMoney),
          Expanded(
            child: AsyncRetry<void>(
              value: historyState,
              message: 'Geçmiş yüklenemedi. İnternet bağlantınızı kontrol edin.',
              onRetry: () {
                ref.invalidate(attendanceByWorkerProvider(id));
                ref.invalidate(advancesStreamProvider);
              },
              data: (_) => ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  _SummaryCard(
                    worker: worker,
                    summary: summary,
                    canSeeMoney: canSeeMoney,
                  ),
                  // Pasif işçi avans ekranındaki seçim listesinde yok
                  // (activeWorkersProvider) → kısayol da yalnız aktifte.
                  if (worker.active)
                    _GiveAdvanceButton(onPressed: () => _openAdvance(context)),
                  _Section('Yoklama Geçmişi (${attendance.length})'),
                  if (attendance.isEmpty)
                    const _EmptyLine('Bu işçi için yoklama kaydı yok.')
                  else
                    // Satırlar arasına ince ayırıcı — birbirinden ayrılsınlar.
                    for (var i = 0; i < attendance.length; i++) ...[
                      if (i > 0) const _RowDivider(),
                      _AttendanceRow(
                        record: attendance[i],
                        canSeeMoney: canSeeMoney,
                      ),
                    ],
                  // Avans kısıtlı hesaba da açık (2026-07-23) → herkes görür.
                  _Section('Avanslar (${advances.length})'),
                  if (advances.isEmpty)
                    const _EmptyLine('Avans kaydı yok.')
                  else
                    for (var i = 0; i < advances.length; i++) ...[
                      if (i > 0) const _RowDivider(),
                      _AdvanceRow(advance: advances[i]),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Özet kartının hemen altındaki kompakt "Avans Ver" kısayolu.
///
/// Arattığı işçinin detayına giren kullanıcı avans için Avans sekmesine gidip
/// listeden aynı işçiyi yeniden aramak zorunda kalmasın diye buradadır.
class _GiveAdvanceButton extends StatelessWidget {
  const _GiveAdvanceButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          // Tema varsayılanı 56px — kart aralarında derli toplu dursun.
          minimumSize: const Size.fromHeight(46),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        icon: const Icon(Icons.payments, size: 20),
        // Büyük sistem yazısında taşmasın — tek satıra sığdır.
        label: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('Avans Ver'),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.worker, required this.canSeeMoney});
  final Worker worker;
  final bool canSeeMoney;

  String get _subtitle {
    if (worker.type.isCrew) {
      final crewText = worker.crewSize > 0
          ? '${worker.crewSize} kişilik ekip'
          : 'Kişi sayısı belirtilmemiş';
      // Para görebilen hesapta kişi başı yevmiye de gösterilir.
      final rate = worker.dailyWageOverrideKurus;
      if (canSeeMoney && rate != null && rate > 0) {
        return '$crewText • ${formatKurus(rate)}/kişi';
      }
      return crewText;
    }
    // Kısıtlı hesap ücret göremez → yalnız cinsiyet.
    if (!canSeeMoney) return worker.gender.label;
    final wage = worker.dailyWageOverrideKurus;
    final wageText =
        wage == null ? 'Yevmiye girilmemiş' : '${formatKurus(wage)} yevmiye';
    return '${worker.gender.label} • $wageText';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: ListTile(
        leading: CircleAvatar(
          radius: 26,
          child: Icon(worker.type.isCrew ? Icons.groups : Icons.person),
        ),
        title: Text(
          worker.name,
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${worker.type.label} • $_subtitle'),
        trailing: worker.active
            ? null
            : Chip(
                label: const Text('Pasif'),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.worker,
    required this.summary,
    required this.canSeeMoney,
  });
  final Worker worker;
  final WorkerHistorySummary summary;

  /// false → yevmiye paraları (brüt/ödenen) gizlenir; çalışılan gün ve açık
  /// avans herkese görünür (avans kısıtlı hesaba da açık).
  final bool canSeeMoney;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysText = worker.type.isCrew
        ? '${summary.crewDays} gün'
        : '${summary.workedDays} gün';
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Stat(
                  icon: Icons.event_available,
                  label: 'Çalışılan',
                  value: daysText,
                  color: theme.colorScheme.primary,
                ),
                // Yevmiye para istatistikleri yalnız yetkili hesapta.
                if (canSeeMoney) ...[
                  _Stat(
                    icon: Icons.receipt_long,
                    label: 'Brüt kazanç',
                    value: formatKurus(summary.grossEarnedKurus),
                    color: theme.colorScheme.primary,
                  ),
                  _Stat(
                    icon: Icons.payments,
                    label: 'Verilen avans',
                    value: formatKurus(summary.advancesTotalKurus),
                    color: theme.colorScheme.secondary,
                  ),
                ],
                // Elebaşında "açık avans" yerine bugüne kadar getirdiği toplam
                // kişi (kişi-gün) gösterilir — sahada asıl merak edilen bu.
                if (worker.type.isCrew)
                  _Stat(
                    icon: Icons.groups,
                    label: 'Toplam kişi',
                    value: '${summary.crewHeadcountTotal} kişi',
                    color: theme.colorScheme.tertiary,
                  )
                // Açık avans herkese görünür (avans kısıtlı hesaba da açık).
                else if (summary.openAdvancesKurus > 0)
                  _Stat(
                    icon: Icons.account_balance_wallet,
                    label: 'Açık avans',
                    value: formatKurus(summary.openAdvancesKurus),
                    color: theme.colorScheme.error,
                  ),
              ],
            ),
            // Kalan bakiye şeridi (alacağı/vereceği) — yalnız para görebilen
            // hesapta. (Denkleşmemiş) brüt kazanç − açık avans.
            if (canSeeMoney) ...[
              const SizedBox(height: 12),
              _BalanceBanner(netKurus: summary.netBalanceKurus),
            ],
          ],
        ),
      ),
    );
  }
}

/// İşçinin kalan hesabını tek bakışta gösteren geniş şerit.
///
/// Pozitif → işçinin bizden ALACAĞI (yeşil); negatif → işçinin bize BORCU /
/// vereceği (kırmızı); sıfır → hesap denk (nötr).
class _BalanceBanner extends StatelessWidget {
  const _BalanceBanner({required this.netKurus});
  final int netKurus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color color, IconData icon, String label, int amount) = switch (
        netKurus.compareTo(0)) {
      > 0 => (
          incomeColor(context),
          Icons.trending_up,
          'İşçinin alacağı',
          netKurus,
        ),
      < 0 => (
          theme.colorScheme.error,
          Icons.trending_down,
          'İşçinin borcu (vereceği)',
          -netKurus,
        ),
      _ => (
          theme.colorScheme.onSurfaceVariant,
          Icons.check_circle_outline,
          'Hesap denk',
          0,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  formatKurus(amount),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
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

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 158,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12)),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
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


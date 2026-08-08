/// Aylık yoklama tablosu ekranı — Excel/kağıt cetvel mantığı (işçi × gün).
///
/// Sol işçi-adı sütunu ve üst gün-numarası satırı **donuk** kalır; gövde iki
/// eksende kaydırılır. Donuk katmanlar gövdeyi dinleyip aynalanır (tek yönlü
/// senkron → geri besleme döngüsü yok). Hücre: Tam ✓, Yarım ½, Yok ·; elebaşı
/// için kişi sayısı. En sağda "Toplam" sütunu (brüt + gün).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/routes.dart';
import '../../../core/date/app_date.dart';
import '../../../core/diagnostics/app_log.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/async_retry.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../advances/application/advance_providers.dart';
import '../../auth/application/user_access.dart';
import '../../workers/application/worker_purge.dart';
import '../../workers/application/workers_providers.dart';
import '../application/attendance_providers.dart';
import '../application/monthly_grid.dart';
import '../application/monthly_grid_providers.dart';
import '../data/attendance_record.dart';

part 'monthly_attendance_table.dart';

// Tablo ölçüleri (mantık piksel). Yoğun veri tablosu → sabit hücre boyutu.
const double _kNameW = 118;
const double _kDayW = 36;
const double _kTotalW = 104;
const double _kHeaderH = 46;
const double _kRowH = 46;

/// İki harfli TR gün kısaltmaları, [DateTime.weekday] (1=Pzt) indeksli.
const List<String> _kWeekdayShort = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pa'];

class MonthlyAttendanceScreen extends ConsumerWidget {
  const MonthlyAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Aylık Yoklama',
        actions: [
          // Takvimsiz toplam cetveli: kim toplam kaç gün çalıştı, ne kazandı.
          IconButton(
            icon: const Icon(Icons.table_view),
            tooltip: 'Çalışma özeti',
            onPressed: () => context.push(AppRoutes.workerTotals),
          ),
        ],
      ),
      body: const Column(
        children: [
          _MonthBar(),
          _Legend(),
          Expanded(child: _MonthlyBody()),
        ],
      ),
    );
  }
}

/// Ay seçici çubuk: ◀ Temmuz 2026 ▶ + "Bu ay". Yoklama ekranındaki [_DateBar]
/// ile aynı görünüm dilinde, gün yerine ay adımlı.
class _MonthBar extends ConsumerWidget {
  const _MonthBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final notifier = ref.read(selectedMonthProvider.notifier);
    final isCurrent = month == currentMonthIso();
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            iconSize: 28,
            tooltip: 'Önceki ay',
            onPressed: () => notifier.shift(-1),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatMonthTitle(month),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Aylık yoklama cetveli',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            iconSize: 28,
            tooltip: 'Sonraki ay',
            onPressed: isCurrent ? null : () => notifier.shift(1),
          ),
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Bu ay',
            onPressed: isCurrent ? null : notifier.thisMonth,
          ),
        ],
      ),
    );
  }
}

/// Kompakt açıklama şeridi: ✓ Tam · ½ Yarım · sayı = kişi (elebaşı). Hesabı
/// görülmüş işçi VARSA yeşil bant açıklaması da eklenir (yoksa gürültü olmasın).
class _Legend extends ConsumerWidget {
  const _Legend();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final anySettled =
        ref.watch(monthlyGridProvider).value?.rows.any((r) => r.isSettled) ??
            false;
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    Widget item(String mark, Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mark,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(width: 4),
            Text(label, style: muted),
          ],
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      child: Wrap(
        spacing: 16,
        runSpacing: 2,
        children: [
          item('✓', _fullColor(context), 'Tam'),
          item('½', _halfColor(context), 'Yarım'),
          item('3', _crewColor(context), 'kişi (elebaşı)'),
          // Mesai: işaretin yanındaki küçük sayı (örn. ✓2 = tam gün + 2 saat).
          item('²', theme.colorScheme.tertiary, 'mesai saati'),
          // Yeşil bant = "hesap görüldü" sınırının içinde kalan günler.
          if (anySettled)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: settledColor(context).withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: settledColor(context), width: 1),
                  ),
                ),
                const SizedBox(width: 4),
                Text('hesabı görüldü', style: muted),
              ],
            ),
        ],
      ),
    );
  }
}

class _MonthlyBody extends ConsumerWidget {
  const _MonthlyBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Izgara memoize provider'da hesaplanır (buildMonthlyGrid her build'de DEĞİL,
    // yalnız ay/kayıt/işçi değişince). Tek AsyncRetry hem yükleme hem hatayı sarar.
    final gridAsync = ref.watch(monthlyGridProvider);
    // Kısıtlı hesap tabloyu görür ama tutarları (Toplam sütunu + alt işçilik)
    // gizlidir; gün sayıları kalır.
    final canSeeMoney = ref.watch(canSeeMoneyProvider);

    return AsyncRetry<MonthlyAttendanceGrid>(
      value: gridAsync,
      onRetry: () {
        ref.invalidate(monthlyAttendanceProvider);
        ref.invalidate(workersStreamProvider);
      },
      message: 'Yoklama yüklenemedi. İnternet bağlantınızı kontrol edin.',
      data: (grid) {
        if (grid.isEmpty) return const _EmptyMonth();
        return Column(
          children: [
            // Kalıntı satır varsa (silinmiş/pasif işçi) temizleme ipucu —
            // uzun basma keşfedilebilir olsun. Kısıtlı hesapta temizleme
            // kapalı olduğundan ipucu da çıkmaz.
            if (canSeeMoney && grid.rows.any((r) => r.removed))
              const _RemovedHint(),
            Expanded(
              child: _MonthlyGridTable(grid: grid, canSeeMoney: canSeeMoney),
            ),
            _SummaryBar(grid: grid, canSeeMoney: canSeeMoney),
          ],
        );
      },
    );
  }
}

/// "Listeden kaldırılmış işçi" satırlarının nasıl temizleneceğini anlatan
/// tek satırlık ipucu. Deneme amaçlı açılıp silinen işçi tabloda satır bırakır
/// (satırlar yoklama kayıtlarından türetilir) — bu satır tek çıkış yolunu söyler.
class _RemovedHint extends StatelessWidget {
  const _RemovedHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(
        children: [
          Icon(Icons.person_off_outlined,
              size: 13, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'İşaretli işçi listeden kaldırılmış. Kayıtlarını tamamen silmek '
              'için adına basılı tutun.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMonth extends StatelessWidget {
  const _EmptyMonth();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(
              'Bu ay yoklama kaydı yok',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Günlük yoklama aldıkça bu tablo dolar.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Alt özet: ayın toplam işçilik brütü + işçi sayısı. Kısıtlı hesapta yalnız
/// işçi sayısı gösterilir (para gizli).
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.grid, required this.canSeeMoney});

  final MonthlyAttendanceGrid grid;
  final bool canSeeMoney;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      // Büyük yazı ölçeğinde Row taşmasın diye iki uç da esnek + scaleDown.
      child: Row(
        children: [
          Flexible(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('${grid.rows.length} işçi',
                  maxLines: 1,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          ),
          const SizedBox(width: 12),
          if (canSeeMoney)
            Flexible(
              flex: 6,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Toplam işçilik: ',
                        maxLines: 1,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    Text(
                      formatKurus(grid.grossKurus),
                      maxLines: 1,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: incomeColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Renkler (tema-duyarlı) ────────────────────────────────────────────────

bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color _fullColor(BuildContext c) =>
    _isDark(c) ? const Color(0xFF81C784) : StatusColors.full;
Color _halfColor(BuildContext c) =>
    _isDark(c) ? const Color(0xFFFFCA28) : const Color(0xFFB8860B);
Color _crewColor(BuildContext c) =>
    _isDark(c) ? const Color(0xFF9FA8DA) : const Color(0xFF3949AB);


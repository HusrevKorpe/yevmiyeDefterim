/// Çalışma Özeti — takvimsiz toplam cetveli (işçi · gün · kazanç).
///
/// Aylık yoklama cetvelinin sağ üstündeki tablo ikonundan açılır. Ay/hafta
/// seçimi YOKTUR: her işçinin ilk günden bugüne toplam çalıştığı gün ve
/// kazandığı para tek satırda görünür. Tutarlar kayıttan okunan snapshot
/// toplamıdır (kural §4); para kısıtlı hesapta Kazanç sütunu gizlenir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/date/app_date.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/async_retry.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../auth/application/user_access.dart';
import '../../workers/application/workers_providers.dart';
import '../application/worker_totals.dart';
import '../application/worker_totals_providers.dart';

// Sütun ölçüleri (mantık piksel). Ad sütunu esner; gün/kazanç sabittir →
// başlık ile satırlar birebir hizalanır.
const double _kDayW = 62;
const double _kMoneyW = 116;
const double _kRowH = 54;

class WorkerTotalsScreen extends ConsumerWidget {
  const WorkerTotalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalsAsync = ref.watch(workerTotalsProvider);
    final canSeeMoney = ref.watch(canSeeMoneyProvider);

    return Scaffold(
      appBar: const GradientAppBar(title: 'Çalışma Özeti'),
      body: AsyncRetry<WorkerTotalsTable>(
        value: totalsAsync,
        onRetry: () {
          ref.invalidate(allAttendanceProvider);
          ref.invalidate(workersStreamProvider);
        },
        message: 'Özet yüklenemedi. İnternet bağlantınızı kontrol edin.',
        data: (table) {
          if (table.isEmpty) return const _EmptyTotals();
          // Yoğun tablo okunaklı kalsın diye metin ölçeği üst sınırlı
          // (uygulama genelinde tavansız — bkz. app.dart / aylık cetvel).
          return MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.1,
            child: Column(
              children: [
                const _Caption(),
                _HeaderRow(canSeeMoney: canSeeMoney),
                Expanded(
                  child: ListView.builder(
                    itemExtent: _kRowH,
                    itemCount: table.rows.length,
                    itemBuilder: (context, i) => _TotalsRow(
                      row: table.rows[i],
                      canSeeMoney: canSeeMoney,
                      striped: i.isOdd,
                    ),
                  ),
                ),
                _SummaryBar(table: table, canSeeMoney: canSeeMoney),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Tablonun ne olduğunu tek satırda söyler: dönem/takvim yok, tüm zaman.
class _Caption extends StatelessWidget {
  const _Caption();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(
        children: [
          Icon(Icons.all_inclusive,
              size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'İlk günden bugüne toplam — ay ya da hafta seçimi yok.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.canSeeMoney});
  final bool canSeeMoney;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const style = TextStyle(fontWeight: FontWeight.w800, fontSize: 13);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.5), width: 1.4),
        ),
      ),
      child: Row(
        children: [
          const Expanded(child: Text('İşçi', style: style)),
          const SizedBox(
            width: _kDayW,
            child: Text('Gün', textAlign: TextAlign.center, style: style),
          ),
          if (canSeeMoney)
            const SizedBox(
              width: _kMoneyW,
              child: Text('Kazanç', textAlign: TextAlign.right, style: style),
            ),
        ],
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({
    required this.row,
    required this.canSeeMoney,
    required this.striped,
  });

  final WorkerTotalRow row;
  final bool canSeeMoney;

  /// Tek satırlar hafif zeminli → uzun listede satır kaymaz (Excel çizgisi).
  final bool striped;

  /// Gün dökümü: bireyselde tam/yarım (+mesai), elebaşıda gün ve kişi-gün.
  String get _detail {
    if (row.isCrew) {
      return '${row.crewDays} gün • ${row.crewHeadcountTotal} kişi-gün';
    }
    final parts = <String>[];
    if (row.fullDays > 0) parts.add('${row.fullDays} tam');
    if (row.halfDays > 0) parts.add('${row.halfDays} yarım');
    // Mesai kazancın içindedir; burada yalnız saat olarak görünür.
    if (row.overtimeHours > 0) parts.add('${row.overtimeHours} saat mesai');
    return parts.isEmpty ? 'çalışılan gün yok' : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final settled = row.isSettled;
    return Container(
      height: _kRowH,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        // Hesabı görülen satır yeşil şeritli — zebra çizgisinin yerine geçer,
        // "bu işçiyle hesap kapandı" listeyi tararken görünür.
        color: settled
            ? settledColor(context).withValues(alpha: dark ? 0.22 : 0.13)
            : striped
                ? theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.25)
                : null,
        border: Border(
          bottom:
              BorderSide(color: theme.dividerColor.withValues(alpha: 0.35)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (row.isCrew) ...[
                      Icon(Icons.groups,
                          size: 15, color: theme.colorScheme.primary),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        row.workerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                    // Hesabı görülmüş işçi — yeşil zeminin nedeni.
                    if (settled) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.check_circle,
                          size: 14, color: settledColor(context)),
                    ],
                    // Listeden kaldırılmış/pasif işçi — geçmişi durur.
                    if (row.removed) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.person_off_outlined,
                          size: 13, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                // Hesabı görülmüşse alt satır kapanışı söyler (gün dökümü zaten
                // "Gün" sütununda); görülmemişse tam/yarım dökümü kalır.
                settled
                    ? Text(
                        'hesap görüldü • '
                        '${formatShortDate(row.settledThrough!)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: settledColor(context),
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : Text(
                        _detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
              ],
            ),
          ),
          SizedBox(
            width: _kDayW,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatDayCount(row.dayCount),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
          if (canSeeMoney)
            SizedBox(
              width: _kMoneyW,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  formatKurus(row.grossKurus),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: incomeColor(context),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Alt toplam şeridi: işçi sayısı + gün toplamı + brüt (kısıtlı hesapta parasız).
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.table, required this.canSeeMoney});

  final WorkerTotalsTable table;
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
      // Büyük yazı ölçeğinde iki uç da esnek + scaleDown → Row taşmaz.
      child: Row(
        children: [
          // İki uç da Expanded: paylar tam genişliği bölüşür → sol yazı sol
          // kenara, toplam sağ kenara yaslanır (loose Flexible sağda boşluk
          // bırakırdı). İçerik sığmazsa FittedBox küçültür, taşma olmaz.
          Expanded(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${table.rows.length} işçi • '
                '${formatDayCount(table.dayCount)} gün',
                maxLines: 1,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (canSeeMoney)
            Expanded(
              flex: 5,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Toplam: ',
                        maxLines: 1,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    Text(
                      formatKurus(table.grossKurus),
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

class _EmptyTotals extends StatelessWidget {
  const _EmptyTotals();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.table_view,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(
              'Henüz yoklama kaydı yok',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Yoklama aldıkça kimin kaç gün çalıştığı ve ne kazandığı burada '
              'toplanır.',
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

/// Adam-gün gösterimi: tam sayıysa "12", değilse "12,5" (TR ondalık).
String formatDayCount(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1).replaceAll('.', ',');
}

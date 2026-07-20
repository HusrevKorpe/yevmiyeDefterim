/// Aylık yoklama tablosu ekranı — Excel/kağıt cetvel mantığı (işçi × gün).
///
/// Sol işçi-adı sütunu ve üst gün-numarası satırı **donuk** kalır; gövde iki
/// eksende kaydırılır. Donuk katmanlar gövdeyi dinleyip aynalanır (tek yönlü
/// senkron → geri besleme döngüsü yok). Hücre: Tam ✓, Yarım ½, Yok ·; elebaşı
/// için kişi sayısı. En sağda "Toplam" sütunu (brüt + gün).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/date/app_date.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/async_retry.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../workers/application/workers_providers.dart';
import '../application/monthly_grid.dart';
import '../application/monthly_grid_providers.dart';
import '../data/attendance_record.dart';

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
      appBar: const GradientAppBar(title: 'Aylık Yoklama'),
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

/// Kompakt açıklama şeridi: ✓ Tam · ½ Yarım · sayı = kişi (elebaşı).
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        ],
      ),
    );
  }
}

class _MonthlyBody extends ConsumerWidget {
  const _MonthlyBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final recordsAsync = ref.watch(monthlyAttendanceProvider);
    final workersAsync = ref.watch(workersStreamProvider);

    return AsyncRetry<List<AttendanceRecord>>(
      value: recordsAsync,
      onRetry: () => ref.invalidate(monthlyAttendanceProvider),
      message: 'Yoklama yüklenemedi. İnternet bağlantınızı kontrol edin.',
      data: (records) => AsyncRetry(
        value: workersAsync,
        onRetry: () => ref.invalidate(workersStreamProvider),
        message: 'İşçiler yüklenemedi. İnternet bağlantınızı kontrol edin.',
        data: (workers) {
          final grid = buildMonthlyGrid(
            monthIso: month,
            workers: workers,
            records: records,
          );
          if (grid.isEmpty) return const _EmptyMonth();
          return Column(
            children: [
              Expanded(child: _MonthlyGridTable(grid: grid)),
              _SummaryBar(grid: grid),
            ],
          );
        },
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

/// Alt özet: ayın toplam işçilik brütü + işçi sayısı.
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.grid});

  final MonthlyAttendanceGrid grid;

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
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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

// ── Tablo ─────────────────────────────────────────────────────────────────

/// Donuk sol sütun + donuk başlık + iki eksenli kaydırılan gövde.
///
/// Dört kaydırma denetleyicisi: gövde yatay/dikey kullanıcı tarafından
/// sürüklenir; başlık (yatay) ve ad sütunu (dikey) `NeverScrollable` olup
/// gövdeyi dinleyerek `jumpTo` ile aynalanır. İçerik genişlik/yükseklikleri
/// birebir eştir → offset daima geçerli aralıkta.
class _MonthlyGridTable extends StatefulWidget {
  const _MonthlyGridTable({required this.grid});

  final MonthlyAttendanceGrid grid;

  @override
  State<_MonthlyGridTable> createState() => _MonthlyGridTableState();
}

class _MonthlyGridTableState extends State<_MonthlyGridTable> {
  final _headerH = ScrollController(); // başlık yatay (aynalanır)
  final _bodyH = ScrollController(); // gövde yatay (sürüklenir)
  final _nameV = ScrollController(); // ad sütunu dikey (aynalanır)
  final _bodyV = ScrollController(); // gövde dikey (sürüklenir)

  @override
  void initState() {
    super.initState();
    _bodyH.addListener(() {
      if (_headerH.hasClients && _headerH.offset != _bodyH.offset) {
        _headerH.jumpTo(_bodyH.offset);
      }
    });
    _bodyV.addListener(() {
      if (_nameV.hasClients && _nameV.offset != _bodyV.offset) {
        _nameV.jumpTo(_bodyV.offset);
      }
    });
  }

  @override
  void dispose() {
    _headerH.dispose();
    _bodyH.dispose();
    _nameV.dispose();
    _bodyV.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grid = widget.grid;
    final theme = Theme.of(context);
    final line = theme.dividerColor.withValues(alpha: 0.4);
    final gridWidth = grid.days.length * _kDayW + _kTotalW;

    // Yoğun tablo okunaklı kalsın diye metin ölçeğini üst sınırla (uygulama
    // genelinde tavansız büyük yazı ölçeği hücreleri taşırırdı — bkz. app.dart).
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.1,
      child: Column(
        children: [
          // Başlık satırı: köşe + gün numaraları + "Toplam".
          Row(
            children: [
              _CornerCell(line: line),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _headerH,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Row(
                    children: [
                      for (final day in grid.days)
                        _HeaderDayCell(dayIso: day, line: line),
                      _HeaderTotalCell(line: line),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Row(
              // stretch → her iki sütun da tam yüksekliği doldurur: satırlar
              // üstten başlar (ortalanmaz) ve içerik ekranı aşınca dikey kaydırır.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Donuk ad sütunu.
                SizedBox(
                  width: _kNameW,
                  child: SingleChildScrollView(
                    controller: _nameV,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        for (final row in grid.rows)
                          _NameCell(row: row, line: line),
                      ],
                    ),
                  ),
                ),
                // Kaydırılan gövde (yatay dış, dikey iç).
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: _bodyH,
                    child: SizedBox(
                      width: gridWidth,
                      child: SingleChildScrollView(
                        controller: _bodyV,
                        child: Column(
                          children: [
                            for (final row in grid.rows)
                              _BodyRow(row: row, days: grid.days, line: line),
                          ],
                        ),
                      ),
                    ),
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

class _CornerCell extends StatelessWidget {
  const _CornerCell({required this.line});
  final Color line;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kNameW,
      height: _kHeaderH,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          right: BorderSide(color: line),
          bottom: BorderSide(color: line, width: 1.4),
        ),
      ),
      child: const Text('İşçi',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }
}

class _HeaderDayCell extends StatelessWidget {
  const _HeaderDayCell({required this.dayIso, required this.line});
  final String dayIso;
  final Color line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = parseIsoDate(dayIso);
    final weekend = d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
    return Container(
      width: _kDayW,
      height: _kHeaderH,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: weekend
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          right: BorderSide(color: line),
          bottom: BorderSide(color: line, width: 1.4),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${d.day}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Text(
            _kWeekdayShort[d.weekday - 1],
            style: TextStyle(
              fontSize: 9,
              color: weekend
                  ? StatusColors.absent
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderTotalCell extends StatelessWidget {
  const _HeaderTotalCell({required this.line});
  final Color line;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kTotalW,
      height: _kHeaderH,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: line, width: 1.4)),
      ),
      child: const Text('Toplam',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }
}

class _NameCell extends StatelessWidget {
  const _NameCell({required this.row, required this.line});
  final MonthlyWorkerRow row;
  final Color line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: _kNameW,
      height: _kRowH,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(color: line),
          bottom: BorderSide(color: line),
        ),
      ),
      child: Row(
        children: [
          if (row.isCrew) ...[
            Icon(Icons.groups, size: 15, color: _crewColor(context)),
            const SizedBox(width: 5),
          ],
          Expanded(
            child: Text(
              row.workerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyRow extends StatelessWidget {
  const _BodyRow({required this.row, required this.days, required this.line});
  final MonthlyWorkerRow row;
  final List<String> days;
  final Color line;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final day in days)
          _DayCell(cell: row.cells[day], dayIso: day, line: line),
        _TotalCell(row: row, line: line),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.cell, required this.dayIso, required this.line});
  final MonthlyGridCell? cell;
  final String dayIso;
  final Color line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = parseIsoDate(dayIso);
    final weekend = d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

    Color? bg;
    Widget? mark;
    final c = cell;
    if (c != null) {
      if (c.isCrew) {
        final col = _crewColor(context);
        bg = col.withValues(alpha: _isDark(context) ? 0.22 : 0.12);
        mark = Text('${c.crewHeadcount}',
            style: TextStyle(color: col, fontWeight: FontWeight.w800, fontSize: 13));
      } else {
        switch (c.status!) {
          case AttendanceStatus.full:
            final col = _fullColor(context);
            bg = col.withValues(alpha: _isDark(context) ? 0.24 : 0.15);
            mark = Text('✓',
                style: TextStyle(
                    color: col, fontWeight: FontWeight.w800, fontSize: 14));
          case AttendanceStatus.half:
            final col = _halfColor(context);
            bg = col.withValues(alpha: _isDark(context) ? 0.24 : 0.16);
            mark = Text('½',
                style: TextStyle(
                    color: col, fontWeight: FontWeight.w800, fontSize: 15));
          case AttendanceStatus.absent:
            mark = Text('·',
                style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant, fontSize: 16));
        }
      }
    }

    return Container(
      width: _kDayW,
      height: _kRowH,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg ??
            (weekend
                ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25)
                : null),
        border: Border(
          right: BorderSide(color: line),
          bottom: BorderSide(color: line),
        ),
      ),
      child: mark == null ? null : FittedBox(fit: BoxFit.scaleDown, child: mark),
    );
  }
}

class _TotalCell extends StatelessWidget {
  const _TotalCell({required this.row, required this.line});
  final MonthlyWorkerRow row;
  final Color line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = row.isCrew
        ? '${row.crewDays} gün • ${row.crewHeadcountTotal} kişi'
        : '${_fmtDays(row.individualDayEquivalent)} gün';

    return Container(
      width: _kTotalW,
      height: _kRowH,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              formatKurus(row.grossKurus),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: incomeColor(context),
              ),
            ),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Adam-gün gösterimi: tam sayıysa "12", değilse "12,5".
String _fmtDays(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1).replaceAll('.', ',');
}

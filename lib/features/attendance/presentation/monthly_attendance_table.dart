part of 'monthly_attendance_screen.dart';

// Aylık tablo gövdesi (donuk sütun/başlık + iki eksenli kaydırma, hücreler).
// Ana kütüphane: monthly_attendance_screen.dart

// ── Gün sütunu meta verisi ─────────────────────────────────────────────────

/// Bir gün sütununun önceden hesaplanmış bilgisi. ISO tarih burada BİR KEZ
/// parse edilir; başlık ve gövde hücreleri hazır alanları okur. Böylece aylık
/// tabloda `parseIsoDate` (pahalı intl parseStrict) çağrısı 31·N'den (hücre
/// başına) 31'e (gün başına) iner — ekranın en büyük ana-thread yükü kalkar.
class _DayMeta {
  const _DayMeta({
    required this.iso,
    required this.dayNum,
    required this.weekdayShort,
    required this.weekend,
  });

  final String iso;
  final int dayNum;
  final String weekdayShort;
  final bool weekend;
}

List<_DayMeta> _dayMetasOf(List<String> days) {
  final metas = <_DayMeta>[];
  for (final iso in days) {
    final d = parseIsoDate(iso);
    metas.add(_DayMeta(
      iso: iso,
      dayNum: d.day,
      weekdayShort: _kWeekdayShort[d.weekday - 1],
      weekend: d.weekday == DateTime.saturday || d.weekday == DateTime.sunday,
    ));
  }
  return metas;
}

// ── Tablo ─────────────────────────────────────────────────────────────────

/// Donuk sol sütun + donuk başlık + iki eksenli kaydırılan gövde.
///
/// Dört kaydırma denetleyicisi: gövde yatay/dikey kullanıcı tarafından
/// sürüklenir; başlık (yatay) ve ad sütunu (dikey) `NeverScrollable` olup
/// gövdeyi dinleyerek `jumpTo` ile aynalanır. İçerik genişlik/yükseklikleri
/// birebir eştir → offset daima geçerli aralıkta.
class _MonthlyGridTable extends StatefulWidget {
  const _MonthlyGridTable({required this.grid, required this.canSeeMoney});

  final MonthlyAttendanceGrid grid;
  final bool canSeeMoney;

  @override
  State<_MonthlyGridTable> createState() => _MonthlyGridTableState();
}

class _MonthlyGridTableState extends State<_MonthlyGridTable> {
  final _headerH = ScrollController(); // başlık yatay (aynalanır)
  final _bodyH = ScrollController(); // gövde yatay (sürüklenir)
  final _nameV = ScrollController(); // ad sütunu dikey (aynalanır)
  final _bodyV = ScrollController(); // gövde dikey (sürüklenir)

  // Gün sütunları bir kez parse edilir; ay değişmedikçe yeniden hesaplanmaz
  // (aynı ay için günler birebir aynı → kayıt değişiminde boşa parse yok).
  late List<_DayMeta> _dayMetas = _dayMetasOf(widget.grid.days);

  @override
  void didUpdateWidget(covariant _MonthlyGridTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.grid.monthIso != widget.grid.monthIso) {
      _dayMetas = _dayMetasOf(widget.grid.days);
    }
  }

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
                      for (final m in _dayMetas)
                        _HeaderDayCell(meta: m, line: line),
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
                // Donuk ad sütunu — tembel (yalnız görünür satırlar). itemExtent
                // gövdeyle birebir eşit → dikey aynalama (jumpTo) piksel-tam.
                SizedBox(
                  width: _kNameW,
                  child: ListView.builder(
                    controller: _nameV,
                    physics: const NeverScrollableScrollPhysics(),
                    itemExtent: _kRowH,
                    itemCount: grid.rows.length,
                    itemBuilder: (context, i) => _NameCell(
                      row: grid.rows[i],
                      line: line,
                      // Kalıntı temizleme yıkıcıdır → yalnız sahip hesapta
                      // (para görebilen) açık; kısıtlı hesap tabloyu okur.
                      canPurge: widget.canSeeMoney,
                    ),
                  ),
                ),
                // Kaydırılan gövde (yatay dış, dikey iç tembel liste → yalnız
                // görünür satırlar inşa edilir; N işçi büyüdükçe kasmaz).
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: _bodyH,
                    child: SizedBox(
                      width: gridWidth,
                      child: ListView.builder(
                        controller: _bodyV,
                        itemExtent: _kRowH,
                        itemCount: grid.rows.length,
                        itemBuilder: (context, i) => _BodyRow(
                          row: grid.rows[i],
                          days: _dayMetas,
                          line: line,
                          canSeeMoney: widget.canSeeMoney,
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
  const _HeaderDayCell({required this.meta, required this.line});
  final _DayMeta meta;
  final Color line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekend = meta.weekend;
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
          Text('${meta.dayNum}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Text(
            meta.weekdayShort,
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

class _NameCell extends ConsumerWidget {
  const _NameCell({
    required this.row,
    required this.line,
    required this.canPurge,
  });
  final MonthlyWorkerRow row;
  final Color line;

  /// Kalıntı satırı temizleme (uzun basma) bu hesapta açık mı.
  final bool canPurge;

  /// Silinmiş/pasif işçinin ARTIK KAYDI KALMASIN: tüm yoklama + avans kayıtları
  /// silinir, satır tablodan düşer. Deneme amaçlı açılıp silinen işçinin geride
  /// bıraktığı satırı temizlemenin tek yolu budur (bkz. [purgeWorkerRecords]).
  Future<void> _purge(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showConfirmDialog(
      context,
      title: 'Kayıtları sil',
      message: '${row.workerName} İşçiler listesinden kaldırılmış. Bu işçiye '
          'ait TÜM yoklama ve avans kayıtları (bu ay dahil, tüm aylar) kalıcı '
          'olarak silinsin mi? Bu işlem geri alınamaz.',
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
        workerId: row.workerId,
      );
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('${row.workerName}: ${result.summary}'),
      ));
    } catch (e, s) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Kayıtlar silinemedi. Tekrar deneyin.'),
      ));
      await logHandledError(e, s,
          reason: 'kalinti-temizleme', info: {'workerId': row.workerId});
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cell = Container(
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
          // Listeden kaldırılmış işçi işareti — bu satır temizlenebilir.
          if (row.removed) ...[
            const SizedBox(width: 4),
            Icon(Icons.person_off_outlined,
                size: 13, color: theme.colorScheme.onSurfaceVariant),
          ],
        ],
      ),
    );
    if (!row.removed || !canPurge) return cell;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _purge(context, ref),
      child: cell,
    );
  }
}

class _BodyRow extends StatelessWidget {
  const _BodyRow({
    required this.row,
    required this.days,
    required this.line,
    required this.canSeeMoney,
  });
  final MonthlyWorkerRow row;
  final List<_DayMeta> days;
  final Color line;
  final bool canSeeMoney;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final m in days)
          _DayCell(cell: row.cells[m.iso], meta: m, line: line),
        _TotalCell(row: row, line: line, canSeeMoney: canSeeMoney),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.cell, required this.meta, required this.line});
  final MonthlyGridCell? cell;
  final _DayMeta meta;
  final Color line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekend = meta.weekend;

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
  const _TotalCell({
    required this.row,
    required this.line,
    required this.canSeeMoney,
  });
  final MonthlyWorkerRow row;
  final Color line;

  /// false → brüt tutar gizli; yalnız gün/kişi özeti gösterilir.
  final bool canSeeMoney;

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
            if (canSeeMoney)
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

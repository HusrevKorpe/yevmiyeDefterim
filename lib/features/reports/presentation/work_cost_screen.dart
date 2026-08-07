/// Tarla / İş Maliyeti sayfası — "hangi tarlaya, hangi işe kaç yevmiye, kaç ₺
/// gitti" (§8).
///
/// Rapor ekranındaki özet kartına dokununca açılır. TEK sayfa, İKİ kırılım:
/// üstteki geçiş düğmesiyle "Tarla" ve "Yapılan İş" arasında geçilir (ayrı
/// sayfa açılmaz, rapor akışı kalabalıklaşmaz). İki kırılımın toplamı aynıdır —
/// aynı yoklama parası, farklı boyuttan gösterilir (çifte sayım değil).
///
/// Açılışta dolu olan kırılım seçilir: 2026-08-07 tarla/iş ayrımından ÖNCEKİ
/// dönemlerde tarla verisi yoktur (o zaman tek liste vardı ve içine yapılan iş
/// yazılıyordu) → eski dönem raporları doğrudan "Yapılan İş" tarafında açılır.
///
/// Dönem, Rapor ile AYNI sağlayıcıdan ([reportPeriodProvider]) okunur: burada
/// değiştirilen aralık rapora da yansır, iki ekran hep aynı dönemi anlatır.
///
/// Kaynak yalnız yoklamadır; giderler tarlaya/işe bağlanmaz (çifte sayım yok,
/// kural §6). Para kısıtlı hesap bu sayfayı göremez — Rapor gibi router'da
/// engellidir (bkz. `router.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/async_retry.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/period_range_selector.dart';
import '../../advances/application/advance_providers.dart';
import '../application/period_report.dart';
import '../application/report_providers.dart';
import '../application/work_cost.dart';
import 'widgets/work_cost_list.dart';

class WorkCostScreen extends ConsumerStatefulWidget {
  const WorkCostScreen({super.key});

  @override
  ConsumerState<WorkCostScreen> createState() => _WorkCostScreenState();
}

class _WorkCostScreenState extends ConsumerState<WorkCostScreen> {
  /// Kullanıcının elle seçtiği kırılım. `null` iken açılış kuralı işler (dolu
  /// olan kırılım gösterilir) → dönem değiştirilince de doğru taraf açık kalır.
  /// Kullanıcı bir kez dokunduysa seçimi korunur (rapor onun elinde).
  CostGroupKind? _picked;

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(reportPeriodProvider);
    final notifier = ref.read(reportPeriodProvider.notifier);
    final reportAsync = ref.watch(reportProvider);

    return Scaffold(
      appBar: const GradientAppBar(title: 'Tarla / İş Maliyeti'),
      body: Column(
        children: [
          // Hazır aralık düğmeleri (Bu Hafta/Bu Ay) BİLEREK yok: Rapor ekranıyla
          // aynı dönem pili, aynı sadelik.
          PeriodRangeSelector(
            startIso: period.start,
            endIso: period.end,
            onSetStart: notifier.setStart,
            onSetEnd: notifier.setEnd,
          ),
          Expanded(
            child: AsyncRetry<PeriodReport>(
              value: reportAsync,
              message: 'Rapor yüklenemedi. İnternet bağlantınızı kontrol edin.',
              onRetry: () {
                ref.invalidate(reportAttendanceProvider);
                ref.invalidate(reportLedgerProvider);
                ref.invalidate(advancesStreamProvider);
              },
              data: (report) {
                // Tarla/iş seçimi isteğe bağlı: hiçbiri kullanılmadıysa
                // dökümü göstermenin anlamı yok.
                if (!report.hasWorkCosts) return const _EmptyCosts();
                final kind = _resolveKind(report);
                final costs = kind == CostGroupKind.plot
                    ? report.plotCosts
                    : report.jobCosts;
                return Column(
                  children: [
                    _KindSwitch(
                      selected: kind,
                      // Boş kırılım da seçilebilir kalır: kullanıcı "tarla
                      // girmemişim" sonucunu görebilmeli (boş durum metni
                      // hangi taraf boşsa onu anlatır).
                      onChanged: (k) => setState(() => _picked = k),
                    ),
                    Expanded(
                      child: hasAssignedCosts(costs)
                          ? WorkCostList(
                              costs: costs,
                              header: _PeriodHero(costs: costs, kind: kind),
                            )
                          : _EmptyCosts(kind: kind),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Gösterilecek kırılım: kullanıcı seçtiyse o, seçmediyse dolu olan (ikisi de
  /// doluysa tarla).
  CostGroupKind _resolveKind(PeriodReport report) {
    final picked = _picked;
    if (picked != null) return picked;
    return report.hasPlotCosts ? CostGroupKind.plot : CostGroupKind.job;
  }
}

/// Üstteki "Tarla | Yapılan İş" geçişi.
class _KindSwitch extends StatelessWidget {
  const _KindSwitch({required this.selected, required this.onChanged});

  final CostGroupKind selected;
  final ValueChanged<CostGroupKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: SegmentedButton<CostGroupKind>(
        segments: const [
          ButtonSegment(
            value: CostGroupKind.plot,
            label: Text('Tarla'),
            icon: Icon(Icons.grass, size: 16),
          ),
          ButtonSegment(
            value: CostGroupKind.job,
            label: Text('Yapılan İş'),
            icon: Icon(Icons.handyman_outlined, size: 16),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (s) => onChanged(s.first),
        showSelectedIcon: false,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStatePropertyAll(
            Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ),
    );
  }
}

/// Dönem özeti: toplam işçilik + kaç tarla/iş, kaç yevmiye.
class _PeriodHero extends StatelessWidget {
  const _PeriodHero({required this.costs, required this.kind});

  final List<WorkCost> costs;
  final CostGroupKind kind;

  @override
  Widget build(BuildContext context) {
    final total = totalWorkGross(costs);
    final groupCount = costs.where((c) => !c.isUnassigned).length;
    final workdays = costs.fold<int>(0, (sum, c) => sum + c.workdayHalves) / 2;
    final unassigned = costs
        .where((c) => c.isUnassigned)
        .fold<int>(0, (s, c) => s + c.grossKurus);
    final isPlot = kind == CostGroupKind.plot;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: heroGradient(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: heroBottom(context).withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPlot ? Icons.grass : Icons.handyman_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isPlot ? 'Dönem Tarla İşçiliği' : 'Dönem İş İşçiliği',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatKurus(total),
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(
                icon: isPlot ? Icons.grass : Icons.handyman_outlined,
                label: isPlot ? '$groupCount tarla' : '$groupCount iş',
              ),
              _Pill(
                icon: Icons.event_available,
                label: '${formatWorkdays(workdays)} yevmiye',
              ),
              if (unassigned > 0)
                _Pill(
                  icon: Icons.help_outline,
                  label: isPlot
                      ? 'Tarlasız ${formatKurus(unassigned)}'
                      : 'İşsiz ${formatKurus(unassigned)}',
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isPlot
                ? 'Yalnız işçilik (yoklama). Giderler tarlaya bağlanmaz.'
                : 'Yalnız işçilik (yoklama). Giderler işe bağlanmaz.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.80),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Degrade zemin üstünde okunur mini bilgi hapı.
class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.92)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Boş durum. [kind] verilirse yalnız o kırılım boştur (diğer sekmede veri
/// olabilir); verilmezse dönemde hiçbir seçim yapılmamıştır.
class _EmptyCosts extends StatelessWidget {
  const _EmptyCosts({this.kind});

  final CostGroupKind? kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPlot = kind == CostGroupKind.plot;
    final icon = switch (kind) {
      CostGroupKind.plot => Icons.grass,
      CostGroupKind.job => Icons.handyman_outlined,
      null => Icons.grass,
    };
    final title = switch (kind) {
      CostGroupKind.plot => 'Bu dönemde tarla seçili kayıt yok',
      CostGroupKind.job => 'Bu dönemde iş seçili kayıt yok',
      null => 'Bu dönemde tarla/iş seçili kayıt yok',
    };
    final body = kind == null
        ? 'Yoklama alırken tarla ve yapılan iş seçerseniz hangisine kaç '
            'yevmiye gittiği burada dökülür.'
        : isPlot
            ? 'Yoklama alırken tarla seçerseniz hangi tarlaya kaç yevmiye '
                'gittiği burada dökülür. "Yapılan İş" tarafına bakmayı deneyin.'
            : 'Yoklama alırken yapılan işi seçerseniz hangi işe kaç yevmiye '
                'gittiği burada dökülür. "Tarla" tarafına bakmayı deneyin.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              body,
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

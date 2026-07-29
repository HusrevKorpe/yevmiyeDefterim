/// Tarla Maliyeti sayfası — "hangi tarlaya kaç yevmiye, kaç ₺ gitti" (§8).
///
/// Rapor ekranındaki özet kartına dokununca açılır. Dönem, Rapor ile AYNI
/// sağlayıcıdan ([reportPeriodProvider]) okunur: burada değiştirilen aralık
/// rapora da yansır, iki ekran hep aynı dönemi anlatır.
///
/// Kaynak yalnız yoklamadır; giderler tarlaya bağlanmaz (çifte sayım yok,
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
import '../application/field_cost.dart';
import '../application/period_report.dart';
import '../application/report_providers.dart';
import 'widgets/field_cost_list.dart';

class FieldCostScreen extends ConsumerWidget {
  const FieldCostScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final notifier = ref.read(reportPeriodProvider.notifier);
    final reportAsync = ref.watch(reportProvider);

    return Scaffold(
      appBar: const GradientAppBar(title: 'Tarla Maliyeti'),
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
                // Tarla seçimi isteğe bağlı: hiç kullanılmadıysa (yalnız
                // "seçilmemiş" satırı) dökümü göstermenin anlamı yok.
                if (!report.hasFieldCosts) return const _EmptyFields();
                return FieldCostList(
                  costs: report.fieldCosts,
                  header: _PeriodHero(costs: report.fieldCosts),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Dönem özeti: toplam tarla işçiliği + kaç tarla / kaç yevmiye.
class _PeriodHero extends StatelessWidget {
  const _PeriodHero({required this.costs});

  final List<FieldCost> costs;

  @override
  Widget build(BuildContext context) {
    final total = totalFieldGross(costs);
    final fieldCount = costs.where((f) => !f.isUnassigned).length;
    final workdays =
        costs.fold<int>(0, (sum, f) => sum + f.workdayHalves) / 2;
    final unassigned =
        costs.where((f) => f.isUnassigned).fold<int>(0, (s, f) => s + f.grossKurus);

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
                child: const Icon(Icons.grass, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Dönem Tarla İşçiliği',
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
              _Pill(icon: Icons.grass, label: '$fieldCount tarla'),
              _Pill(
                icon: Icons.event_available,
                label: '${formatWorkdays(workdays)} yevmiye',
              ),
              if (unassigned > 0)
                _Pill(
                  icon: Icons.help_outline,
                  label: 'Tarlasız ${formatKurus(unassigned)}',
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Yalnız işçilik (yoklama). Giderler tarlaya bağlanmaz.',
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

class _EmptyFields extends StatelessWidget {
  const _EmptyFields();

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
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.grass,
                  size: 38, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Bu dönemde tarla seçili kayıt yok',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Yoklama alırken tarla seçerseniz hangi tarlaya kaç yevmiye '
              'gittiği burada dökülür.',
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

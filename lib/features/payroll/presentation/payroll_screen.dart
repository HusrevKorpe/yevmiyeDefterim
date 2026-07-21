/// Hakediş ekranı — dönem seç → işçiler/elebaşılar → "Öde" (plan §5, kural §8).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/routes.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/async_retry.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/period_range_selector.dart';
import '../application/payroll_calculator.dart';
import '../application/payroll_providers.dart';
import '../application/payroll_view_model.dart';
import 'widgets/payroll_line_tile.dart';

class PayrollScreen extends ConsumerWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ödeme sonucu geri bildirimi (snackbar).
    ref.listen<PayrollPayState>(payrollViewModelProvider, (prev, next) {
      final messenger = ScaffoldMessenger.of(context);
      if (next.paidWorkerId != null && next.paidWorkerId != prev?.paidWorkerId) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Ödeme yapıldı.')),
        );
      } else if (next.error != null && next.error != prev?.error) {
        messenger.showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    final attendanceAsync = ref.watch(attendanceInPeriodProvider);
    final lines = ref.watch(payrollLinesProvider);
    final period = ref.watch(payrollPeriodProvider);
    final periodNotifier = ref.read(payrollPeriodProvider.notifier);

    return Scaffold(
      appBar: GradientAppBar(
        title: 'Hakediş',
        actions: [
          TextButton.icon(
            onPressed: () => context.push(AppRoutes.advances),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text('Avanslar'),
          ),
        ],
      ),
      body: Column(
        children: [
          PeriodRangeSelector(
            startIso: period.start,
            endIso: period.end,
            onSetStart: periodNotifier.setStart,
            onSetEnd: periodNotifier.setEnd,
          ),
          Expanded(
            child: AsyncRetry(
              value: attendanceAsync,
              onRetry: () => ref.invalidate(attendanceInPeriodProvider),
              message: 'Hakediş yüklenemedi. İnternet bağlantınızı kontrol edin.',
              data: (_) => _PayrollList(lines: lines),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayrollList extends StatelessWidget {
  const _PayrollList({required this.lines});

  final List<PayrollLine> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const _EmptyView();

    final workers = lines.where((l) => !l.isCrew).toList();
    final crews = lines.where((l) => l.isCrew).toList();
    final totalNet = lines.fold<int>(0, (s, l) => s + l.netPaidKurus);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (workers.isNotEmpty) ...[
          _SectionHeader('İşçiler (${workers.length})'),
          for (final l in workers) PayrollLineTile(line: l),
        ],
        if (crews.isNotEmpty) ...[
          _SectionHeader('Elebaşılar (${crews.length})'),
          for (final l in crews) PayrollLineTile(line: l),
        ],
        _TotalNetCard(totalNet: totalNet),
      ],
    );
  }
}

/// Dönemin toplam ödenecek neti — degrade vurgu kartı (Ana Sayfa ile uyumlu).
class _TotalNetCard extends StatelessWidget {
  const _TotalNetCard({required this.totalNet});
  final int totalNet;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: heroGradient(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kHeroBottom.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.payments, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Toplam ödenecek net',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
          Text(
            formatKurus(totalNet),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: SectionTitle(text),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

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
              child: Icon(Icons.payments_outlined,
                  size: 42, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Bu dönemde hakediş yok',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Seçili dönemde ödenmemiş yoklama kaydı bulunmuyor. '
              'Dönemi değiştirin ya da yoklama alın.',
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

/// Rapor ekranı — dönem seç → kasa + işçilik özeti + işçi bazında kazanç (§8).
///
/// Rapor dönemi Kasa/Hakediş'ten bağımsızdır. Kasa kartı [LedgerSummaryCard]
/// ile paylaşılır (DRY). Dışa aktarma (PDF/CSV) app bar'dan (Faz 4 Part D).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/period_range_selector.dart';
import '../../ledger/application/ledger_summary.dart';
import '../../ledger/presentation/widgets/ledger_summary_card.dart';
import '../application/period_report.dart';
import '../application/report_providers.dart';
import '../application/report_share.dart';
import 'widgets/report_labor_card.dart';
import 'widgets/worker_earning_tile.dart';

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  /// Paylaş yaprağı: CSV veya PDF. Boş raporda paylaşım kapalıdır.
  Future<void> _share(BuildContext context, PeriodReport report) async {
    final format = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Raporu Paylaş',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('CSV (Excel) olarak'),
              onTap: () => Navigator.pop(ctx, 'csv'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('PDF olarak'),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
          ],
        ),
      ),
    );
    if (format == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (format == 'csv') {
        await shareReportCsv(report);
      } else {
        await shareReportPdf(report);
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Paylaşım başarısız. Tekrar deneyin.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final notifier = ref.read(reportPeriodProvider.notifier);
    final report = ref.watch(reportProvider);
    final loading = ref.watch(reportLoadingProvider);

    return Scaffold(
      appBar: GradientAppBar(
        title: 'Rapor',
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Paylaş',
            onPressed:
                report.isEmpty ? null : () => _share(context, report),
          ),
        ],
      ),
      body: Column(
        children: [
          PeriodRangeSelector(
            startIso: period.start,
            endIso: period.end,
            onSetStart: notifier.setStart,
            onSetEnd: notifier.setEnd,
            onThisWeek: notifier.thisWeek,
            onThisMonth: notifier.thisMonth,
          ),
          Expanded(
            child: (loading && report.isEmpty)
                ? const Center(child: CircularProgressIndicator())
                : _ReportBody(report: report),
          ),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});

  final PeriodReport report;

  @override
  Widget build(BuildContext context) {
    if (report.isEmpty) return const _EmptyReport();

    final theme = Theme.of(context);
    final kasa = LedgerSummary(
      incomeKurus: report.incomeKurus,
      expenseKurus: report.expenseKurus,
      expenseByCategory: report.expenseByCategory,
    );

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 32),
      children: [
        const _Section('Kasa'),
        LedgerSummaryCard(summary: kasa),
        const SizedBox(height: 8),
        ReportLaborCard(report: report),
        if (report.workerEarnings.isNotEmpty) ...[
          _Section('İşçi Kazançları (${report.workerEarnings.length})'),
          for (final e in report.workerEarnings)
            WorkerEarningTile(earning: e),
        ] else
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Bu dönemde çalışan işçi kaydı yok.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: SectionTitle(text),
    );
  }
}

class _EmptyReport extends StatelessWidget {
  const _EmptyReport();

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
              child: Icon(Icons.assessment_outlined,
                  size: 42, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Bu dönemde kayıt yok',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Farklı bir dönem seçin ya da yoklama/kasa kaydı girin.',
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

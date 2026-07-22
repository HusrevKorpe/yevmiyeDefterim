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
import '../../advances/presentation/widgets/advance_note_chip.dart';
import '../../auth/application/user_access.dart';
import '../../attendance/data/attendance_record.dart';
import '../../payroll/application/payroll_providers.dart';
// --- HAKEDİŞ ŞİMDİLİK RAFTA --- geri açınca bu import'u da aç.
// import '../../payroll/data/payroll.dart';
// --- /HAKEDİŞ ---
import '../application/worker_history.dart';
import '../application/worker_history_providers.dart';
import '../data/worker.dart';
import 'worker_edit_screen.dart';

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
    // Avanslar para → kısıtlı hesapta hiç izlenmez/gösterilmez.
    final advances = canSeeMoney
        ? ref.watch(advancesByWorkerProvider(id))
        : const <Advance>[];
    // --- HAKEDİŞ ŞİMDİLİK RAFTA ---
    // final payrolls = ref.watch(payrollsByWorkerProvider(id));
    // --- /HAKEDİŞ ---

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
                if (canSeeMoney) {
                  ref.invalidate(advancesStreamProvider);
                  ref.invalidate(payrollsStreamProvider);
                }
              },
              data: (_) => ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  _SummaryCard(
                    worker: worker,
                    summary: summary,
                    canSeeMoney: canSeeMoney,
                  ),
                  _Section('Yoklama Geçmişi (${attendance.length})'),
                  if (attendance.isEmpty)
                    const _EmptyLine('Bu işçi için yoklama kaydı yok.')
                  else
                    for (final r in attendance)
                      _AttendanceRow(record: r, canSeeMoney: canSeeMoney),
                  // Avanslar bölümü tamamen para → kısıtlı hesapta gizli.
                  if (canSeeMoney) ...[
                    _Section('Avanslar (${advances.length})'),
                    if (advances.isEmpty)
                      const _EmptyLine('Avans kaydı yok.')
                    else
                      for (final a in advances) _AdvanceRow(advance: a),
                  ],
                  // --- HAKEDİŞ ŞİMDİLİK RAFTA ---
                  // Geri açmak için bu bloğu, yukarıdaki `payrolls` izlemesini,
                  // `_PayrollRow` sınıfını ve payroll import'unu birlikte aç.
                  // _Section('Ödenen Hakedişler (${payrolls.length})'),
                  // if (payrolls.isEmpty)
                  //   const _EmptyLine('Ödenmiş hakediş yok.')
                  // else
                  //   for (final p in payrolls) _PayrollRow(payroll: p),
                  // --- /HAKEDİŞ ---
                ],
              ),
            ),
          ),
        ],
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
      return worker.crewSize > 0
          ? '${worker.crewSize} kişilik ekip'
          : 'Kişi sayısı belirtilmemiş';
    }
    // Kısıtlı hesap ücret göremez → yalnız cinsiyet.
    if (!canSeeMoney) return worker.gender.label;
    final wage = worker.dailyWageOverrideKurus;
    final wageText =
        wage == null ? 'Varsayılan ücret' : '${formatKurus(wage)} özel ücret';
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

  /// false → yalnız "Çalışılan gün" gösterilir; brüt/ödenen/avans gizlenir.
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
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Stat(
              icon: Icons.event_available,
              label: 'Çalışılan',
              value: daysText,
              color: theme.colorScheme.primary,
            ),
            // Para istatistikleri yalnız yetkili hesapta.
            if (canSeeMoney) ...[
              _Stat(
                icon: Icons.receipt_long,
                label: 'Brüt kazanç',
                value: formatKurus(summary.grossEarnedKurus),
                color: theme.colorScheme.primary,
              ),
              _Stat(
                icon: Icons.payments,
                label: 'Ödenen',
                value: formatKurus(summary.netPaidKurus),
                color: incomeColor(context),
              ),
              if (summary.openAdvancesKurus > 0)
                _Stat(
                  icon: Icons.account_balance_wallet,
                  label: 'Açık avans',
                  value: formatKurus(summary.openAdvancesKurus),
                  color: theme.colorScheme.error,
                ),
            ],
          ],
        ),
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

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({required this.record, required this.canSeeMoney});
  final AttendanceRecord record;

  /// false → satırda kazanç tutarı gösterilmez (yalnız tarih + durum).
  final bool canSeeMoney;

  @override
  Widget build(BuildContext context) {
    final detail = switch (record) {
      IndividualAttendance(:final status) => status.label,
      CrewAttendance(:final headcount) => '$headcount kişi',
    };
    return ListTile(
      dense: true,
      leading: const Icon(Icons.event, size: 20),
      title: Text(formatHumanDate(record.date)),
      subtitle: Text(detail),
      trailing: canSeeMoney
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- ÖDEME KİLİDİ ŞİMDİLİK RAFTA (hakediş ile birlikte) ---
                // Hakedişi geri açınca kilit ikonunu da geri getir:
                // if (record.isPaid)
                //   Icon(Icons.lock, size: 15, color: theme.colorScheme.outline),
                // if (record.isPaid) const SizedBox(width: 6),
                Text(
                  formatKurus(record.earningKurus),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            )
          : null,
    );
  }
}

class _AdvanceRow extends StatelessWidget {
  const _AdvanceRow({required this.advance});
  final Advance advance;

  /// Avansın durum etiketi: açık / hesap görüldü (tarihli) / (eski) mahsup.
  static String _advanceStatus(Advance a) {
    if (a.isOpen) return 'Açık (devrediyor)';
    if (a.isManuallySettled) {
      final d = a.settledDate;
      return d == null
          ? 'Hesap görüldü'
          : 'Hesap görüldü • ${formatHumanDateNoWeekday(d)}';
    }
    return 'Mahsup edildi';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: const Icon(Icons.account_balance_wallet, size: 20),
      title: Text(formatHumanDate(advance.date)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_advanceStatus(advance)),
          if (advance.note != null && advance.note!.isNotEmpty)
            AdvanceNoteChip(advance.note!),
        ],
      ),
      trailing: Text(
        formatKurus(advance.amountKurus),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: advance.isOpen ? theme.colorScheme.error : null,
        ),
      ),
    );
  }
}

// --- HAKEDİŞ ŞİMDİLİK RAFTA --- (build'deki bloğu geri açınca bunu da aç)
// class _PayrollRow extends StatelessWidget {
//   const _PayrollRow({required this.payroll});
//   final Payroll payroll;
//
//   @override
//   Widget build(BuildContext context) {
//     return ListTile(
//       dense: true,
//       leading: const Icon(Icons.payments, size: 20),
//       title: Text(formatHumanDate(payroll.paidDate)),
//       subtitle: Text(
//         '${formatHumanDate(payroll.periodStart)} – '
//         '${formatHumanDate(payroll.periodEnd)}',
//         maxLines: 1,
//         overflow: TextOverflow.ellipsis,
//       ),
//       trailing: Text(
//         formatKurus(payroll.netPaidKurus),
//         style: TextStyle(
//           fontWeight: FontWeight.w600,
//           color: Colors.green.shade700,
//         ),
//       ),
//     );
//   }
// }
// --- /HAKEDİŞ ---

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: SectionTitle(text),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

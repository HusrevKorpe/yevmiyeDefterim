part of 'worker_detail_screen.dart';

// Geçmiş liste satırları (yoklama/avans satırı, bölüm başlığı, ayırıcı).
// Ana kütüphane: worker_detail_screen.dart

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
          ? Text(
              formatKurus(record.earningKurus),
              style: const TextStyle(fontWeight: FontWeight.w600),
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

/// Geçmiş satırları arasındaki ince ayırıcı çizgi (kenarlardan içeri girintili).
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      endIndent: 16,
      color: Theme.of(context).colorScheme.outlineVariant,
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

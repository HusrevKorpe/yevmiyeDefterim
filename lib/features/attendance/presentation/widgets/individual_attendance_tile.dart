/// Bireysel işçi yoklama satırı — Tam/Yarım/Yok segment düğmesi (kural §8).
library;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/money/money.dart';
import '../../../workers/data/worker.dart';
import '../../data/attendance_record.dart';
import 'paid_lock_badge.dart';

class IndividualAttendanceTile extends StatelessWidget {
  const IndividualAttendanceTile({
    super.key,
    required this.worker,
    required this.status,
    required this.resolvedWageKurus,
    required this.onChanged,
    this.locked = false,
  });

  final Worker worker;
  final AttendanceStatus status;
  final int resolvedWageKurus;
  final ValueChanged<AttendanceStatus> onChanged;

  /// Bu gün ödendi (hakedişe girdi) → düzenleme kapalı (kural §3, §6).
  final bool locked;

  Color get _statusColor => switch (status) {
        AttendanceStatus.full => StatusColors.full,
        AttendanceStatus.half => StatusColors.half,
        AttendanceStatus.absent => StatusColors.absent,
      };

  @override
  Widget build(BuildContext context) {
    final wageText = resolvedWageKurus == 0
        ? 'Ücret girilmemiş'
        : 'Yevmiye ${formatKurus(resolvedWageKurus)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      wageText,
                      style: TextStyle(
                        fontSize: 13,
                        color: resolvedWageKurus == 0
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (locked) const PaidLockBadge(),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AttendanceStatus>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: AttendanceStatus.full,
                  label: Text('Tam'),
                  icon: Icon(Icons.check_circle_outline),
                ),
                ButtonSegment(
                  value: AttendanceStatus.half,
                  label: Text('Yarım'),
                  icon: Icon(Icons.contrast),
                ),
                ButtonSegment(
                  value: AttendanceStatus.absent,
                  label: Text('Yok'),
                  icon: Icon(Icons.cancel_outlined),
                ),
              ],
              selected: {status},
              // Ödenmiş gün → düzenleme kapalı (null callback = disabled).
              onSelectionChanged: locked ? null : (s) => onChanged(s.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return _statusColor.withValues(alpha: 0.18);
                  }
                  return null;
                }),
              ),
            ),
          ),
          const Divider(height: 20),
        ],
      ),
    );
  }
}

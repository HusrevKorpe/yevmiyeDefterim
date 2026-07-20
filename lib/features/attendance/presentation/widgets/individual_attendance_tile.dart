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
    required this.onCleared,
    this.locked = false,
  });

  final Worker worker;

  /// Bu günün durumu; `null` → yoklama alınmamış, hiçbir segment seçili değil.
  final AttendanceStatus? status;
  final int resolvedWageKurus;
  final ValueChanged<AttendanceStatus> onChanged;

  /// Seçili durum boşaltılınca (gün geri alınınca) çağrılır → kayıt silinir.
  final VoidCallback onCleared;

  /// Bu gün ödendi (hakedişe girdi) → düzenleme kapalı (kural §3, §6).
  final bool locked;

  /// Durum rengi; seçili değilse (null) null döner → nötr içi boş nokta.
  Color? get _statusColor => switch (status) {
        AttendanceStatus.full => StatusColors.full,
        AttendanceStatus.half => StatusColors.half,
        AttendanceStatus.absent => StatusColors.absent,
        null => null,
      };

  @override
  Widget build(BuildContext context) {
    final dotColor = _statusColor;
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
                  // Seçili değilse (null) içi boş, ince çerçeveli nötr nokta.
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: dotColor == null
                      ? Border.all(
                          color: Theme.of(context).colorScheme.outline,
                          width: 1.5,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  worker.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                wageText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: resolvedWageKurus == 0
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (locked) ...[
                const SizedBox(width: 6),
                const PaidLockBadge(),
              ],
            ],
          ),
          const SizedBox(height: 6),
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
              // status null → hiçbiri seçili değil (yoklama alınmamış gün).
              // Boş seçime izin ver: seçili segmente tekrar dokununca gün geri
              // alınır (onCleared → kayıt silinir).
              emptySelectionAllowed: true,
              selected: status == null ? const {} : {status!},
              // Ödenmiş gün → düzenleme kapalı (null callback = disabled).
              onSelectionChanged: locked
                  ? null
                  : (s) => s.isEmpty ? onCleared() : onChanged(s.first),
              style: ButtonStyle(
                // Hap/StadiumBorder yerine düz köşeli dikdörtgen (kral tercihi).
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return (dotColor ?? StatusColors.full)
                        .withValues(alpha: 0.18);
                  }
                  return null;
                }),
              ),
            ),
          ),
          const Divider(height: 14),
        ],
      ),
    );
  }
}

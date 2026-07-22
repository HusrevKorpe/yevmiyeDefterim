/// Bireysel işçi yoklama satırı — Tam/Yarım/Yok segment düğmesi (kural §8).
library;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/money/money.dart';
import '../../../workers/data/worker.dart';
import '../../data/attendance_record.dart';
import '../../data/field.dart';
import 'field_chips.dart';
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
    this.showWage = true,
    this.fields = const [],
    this.fieldId,
    this.fieldName,
    this.onFieldChanged,
  });

  final Worker worker;

  /// Bu günün durumu; `null` → yoklama alınmamış, hiçbir segment seçili değil.
  final AttendanceStatus? status;
  final int resolvedWageKurus;

  /// Yevmiye tutarı satırda gösterilsin mi? Para/gider kısıtlı hesapta `false`.
  final bool showWage;
  final ValueChanged<AttendanceStatus> onChanged;

  /// Seçili durum boşaltılınca (gün geri alınınca) çağrılır → kayıt silinir.
  final VoidCallback onCleared;

  /// Bu gün ödendi (hakedişe girdi) → düzenleme kapalı (kural §3, §6).
  final bool locked;

  /// Aktif tarlalar + bu günün tarla seçimi (isteğe bağlı — "kim nerede
  /// çalıştı"). Çipler yalnız Tam/Yarım seçiliyken görünür (bkz. [_showFields]).
  final List<Field> fields;
  final String? fieldId;
  final String? fieldName;
  final ValueChanged<Field?>? onFieldChanged;

  /// Tarla çipleri yalnız Tam/Yarım seçiliyken görünür (Yok/boş günde "nerede
  /// çalıştı" sorusu anlamsız). Tarla tanımlı değilse satır hiç çıkmaz; ama
  /// silinmiş tarlaya bağlı eski kayıt adıyla gösterilebilsin diye [fieldId]
  /// doluysa açık kalır.
  bool get _showFields =>
      onFieldChanged != null &&
      !locked &&
      (status == AttendanceStatus.full || status == AttendanceStatus.half) &&
      (fields.isNotEmpty || fieldId != null);

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
              // Yevmiye tutarı yalnız para görebilen hesapta gösterilir.
              if (showWage) ...[
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
              ],
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
          if (_showFields) ...[
            const SizedBox(height: 8),
            FieldChips(
              fields: fields,
              selectedFieldId: fieldId,
              selectedFieldName: fieldName,
              onChanged: onFieldChanged!,
            ),
          ],
          const Divider(height: 14),
        ],
      ),
    );
  }
}

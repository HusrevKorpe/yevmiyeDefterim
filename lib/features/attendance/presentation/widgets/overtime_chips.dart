/// Yoklama satırı altındaki kompakt mesai (fazla çalışma) seçici (kural §8).
///
/// Tam/Yarım seçilince satırın altında saat çipleri çıkar: 1s · 2s · 3s · 4s ·
/// Diğer. Seçim İSTEĞE BAĞLIDIR (mesai yoksa hiç dokunulmaz); seçili çipe tekrar
/// dokunmak mesaiyi kaldırır. "Diğer" 5+ saat için elle giriş açar.
///
/// Tutar burada HESAPLANMAZ, yalnız gösterilir: saat × işçinin mesai saat ücreti
/// (yoklama anında dondurulmuş — bkz. `AttendanceViewModel.setOvertimeHours`).
library;

import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../data/attendance_record.dart';

/// Hazır çip olarak sunulan saatler. Fazlası "Diğer" ile elle girilir.
const List<int> _quickHours = [1, 2, 3, 4];

class OvertimeChips extends StatelessWidget {
  const OvertimeChips({
    super.key,
    required this.hours,
    required this.rateKurus,
    required this.onChanged,
    this.showAmount = true,
  });

  /// O günün mesai saati; 0 → mesai yok (hiçbir çip seçili değil).
  final int hours;

  /// Mesai saat ücreti (kuruş) — kayıtta dondurulmuş değer, yoksa işçinin
  /// güncel ücreti. 0 ise tutar gösterilmez, yerine uyarı çıkar.
  final int rateKurus;

  /// Yeni saat (0 = mesai kaldırıldı).
  final ValueChanged<int> onChanged;

  /// Para tutarı gösterilsin mi? Kısıtlı hesapta false → yalnız saat görünür.
  final bool showAmount;

  /// "Diğer" çipi: seçili saat hazır çiplerden biri değilse (5+) o saati gösterir.
  bool get _customSelected => hours > 0 && !_quickHours.contains(hours);

  Future<void> _askCustom(BuildContext context) async {
    final text = await showInputDialog(
      context,
      title: 'Mesai saati',
      icon: Icons.more_time,
      message: 'Kaç saat mesaiye kaldı? (en fazla $kMaxOvertimeHours saat, '
          'kaldırmak için 0 yazın)',
      initialValue: hours > 0 ? '$hours' : '',
      label: 'Saat',
      hint: 'Örn. 6',
      keyboardType: TextInputType.number,
      textCapitalization: TextCapitalization.none,
    );
    if (text == null) return;
    final n = int.tryParse(text.trim());
    if (n == null || n < 0) return;
    onChanged(n > kMaxOvertimeHours ? kMaxOvertimeHours : n);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.more_time,
                size: 15, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final h in _quickHours)
                      _Chip(
                        label: '$h s',
                        selected: h == hours,
                        // Seçiliye tekrar dokunmak mesaiyi kaldırır.
                        onTap: () => onChanged(h == hours ? 0 : h),
                      ),
                    _Chip(
                      label: _customSelected ? '$hours s' : 'Diğer',
                      selected: _customSelected,
                      onTap: () => _askCustom(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (hours > 0) ...[
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 21),
            child: Text(
              _summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                // Saat ücreti girilmemişse mesai ₺0 kalır → uyarı rengi
                // (yevmiyesi girilmemiş işçi satırıyla aynı desen).
                color: showAmount && rateKurus == 0
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Çiplerin altındaki özet satırı: "2 saat mesai · ₺200".
  String get _summary {
    if (!showAmount) return '$hours saat mesai';
    if (rateKurus == 0) return '$hours saat mesai · saat ücreti girilmemiş';
    return '$hours saat mesai · ${formatKurus(hours * rateKurus)}';
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected
              ? theme.colorScheme.tertiary
              : theme.colorScheme.onSurfaceVariant,
        ),
        selectedColor: theme.colorScheme.tertiary.withValues(alpha: 0.14),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.tertiary
              : theme.colorScheme.outlineVariant,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// Yoklama satırı altındaki kompakt tarla seçici (kural §8).
///
/// Tam/Yarım seçilince (elebaşında kişi girilince) satırın altında yatay
/// kaydırmalı küçük çipler çıkar; seçim İSTEĞE BAĞLIDIR ("kim nerede çalıştı"
/// bilgisi). Seçili çipe tekrar dokunmak seçimi kaldırır.
library;

import 'package:flutter/material.dart';

import '../../data/field.dart';

class FieldChips extends StatelessWidget {
  const FieldChips({
    super.key,
    required this.fields,
    required this.selectedFieldId,
    required this.onChanged,
    this.selectedFieldName,
  });

  /// Aktif tarlalar (ada göre sıralı). Boş liste + seçim yoksa çağıran gizler.
  final List<Field> fields;
  final String? selectedFieldId;

  /// Kayıtta denormalize saklanan ad: seçili tarla sonradan silindiyse aktif
  /// listede olmasa da adıyla gösterilir (seçim kaldırılabilir kalır).
  final String? selectedFieldName;

  /// Yeni seçim (null = seçim kaldırıldı).
  final ValueChanged<Field?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Seçili tarla aktif listede yoksa (silinmiş/pasif) başa "hayalet" çip.
    final ghost = selectedFieldId != null &&
        !fields.any((f) => f.id == selectedFieldId);
    return Row(
      children: [
        Icon(Icons.grass, size: 15, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (ghost)
                  _Chip(
                    label: selectedFieldName ?? 'Silinmiş tarla',
                    selected: true,
                    onTap: () => onChanged(null),
                  ),
                for (final f in fields)
                  _Chip(
                    label: f.name,
                    selected: f.id == selectedFieldId,
                    // Seçiliye tekrar dokunmak seçimi kaldırır.
                    onTap: () =>
                        onChanged(f.id == selectedFieldId ? null : f),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
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
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        selectedColor: theme.colorScheme.primary.withValues(alpha: 0.14),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

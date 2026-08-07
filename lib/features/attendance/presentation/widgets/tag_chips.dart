/// Yoklama satırı altındaki kompakt etiket seçici (kural §8).
///
/// İKİ KEZ kullanılır — bir kez TARLA ([Plot]), bir kez YAPILAN İŞ ([Job]) için.
/// İki liste bağımsızdır: aynı satırda alt alta iki çip şeridi çıkar.
///
/// Tam/Yarım seçilince (elebaşında kişi girilince) satırın altında yatay
/// kaydırmalı küçük çipler çıkar; seçim İSTEĞE BAĞLIDIR. Seçili çipe tekrar
/// dokunmak seçimi kaldırır.
library;

import 'package:flutter/material.dart';

/// Tarla/iş çip şeridi. [T] = [Plot] ya da [Job]; ad ve kimlik [idOf]/[nameOf]
/// ile okunur → iki tip tek widget'ı paylaşır ama birbirine karışamaz (seçim
/// geri çağrısı da [T] döner).
class TagChips<T> extends StatelessWidget {
  const TagChips({
    super.key,
    required this.items,
    required this.idOf,
    required this.nameOf,
    required this.selectedId,
    required this.onChanged,
    required this.icon,
    required this.ghostLabel,
    this.selectedName,
  });

  /// Aktif liste (ada göre sıralı). Boş liste + seçim yoksa çağıran gizler.
  final List<T> items;
  final String Function(T) idOf;
  final String Function(T) nameOf;

  final String? selectedId;

  /// Kayıtta denormalize saklanan ad: seçili öğe sonradan silindiyse aktif
  /// listede olmasa da adıyla gösterilir (seçim kaldırılabilir kalır).
  final String? selectedName;

  /// Şerit başındaki ikon (tarla: çimen, iş: el aleti) — iki şerit bakışta ayırt
  /// edilsin diye.
  final IconData icon;

  /// Adı da kaybolmuş silinmiş öğe için yedek etiket ("Silinmiş tarla" gibi).
  final String ghostLabel;

  /// Yeni seçim (null = seçim kaldırıldı).
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Seçili öğe aktif listede yoksa (silinmiş/pasif) başa "hayalet" çip.
    final ghost =
        selectedId != null && !items.any((i) => idOf(i) == selectedId);
    return Row(
      children: [
        Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (ghost)
                  _Chip(
                    label: selectedName ?? ghostLabel,
                    selected: true,
                    onTap: () => onChanged(null),
                  ),
                for (final item in items)
                  _Chip(
                    label: nameOf(item),
                    selected: idOf(item) == selectedId,
                    // Seçiliye tekrar dokunmak seçimi kaldırır.
                    onTap: () =>
                        onChanged(idOf(item) == selectedId ? null : item),
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

/// Tarla şeridinin ikonu ve hayalet etiketi (iki tile aynı görünümü paylaşsın).
const IconData kPlotIcon = Icons.grass;
const String kPlotGhostLabel = 'Silinmiş tarla';

/// Yapılan iş şeridinin ikonu ve hayalet etiketi.
const IconData kJobIcon = Icons.handyman_outlined;
const String kJobGhostLabel = 'Silinmiş iş';

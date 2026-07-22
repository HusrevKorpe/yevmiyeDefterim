/// Avans açıklaması rozeti — notu hafif renkli bir hapla listede öne çıkarır.
///
/// Tutar yeşiliyle (primary) çakışmasın diye `tertiary` tonu kullanılır;
/// karanlık modda şema kendini uyarlar. Kompakt: küçük ikon + italik metin.
library;

import 'package:flutter/material.dart';

class AdvanceNoteChip extends StatelessWidget {
  const AdvanceNoteChip(this.note, {super.key});

  final String note;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.tertiary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notes, size: 13, color: scheme.tertiary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: scheme.tertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

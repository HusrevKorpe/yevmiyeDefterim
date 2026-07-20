/// "Ödendi" kilit rozeti — ödenmiş (hakedişe girmiş) yoklama günü için (kural §6).
///
/// Bireysel ve elebaşı yoklama satırları paylaşır; düzenleme kapalı olduğunu
/// düşük teknoloji dostu biçimde (ikon + yazı) gösterir (kural §8).
library;

import 'package:flutter/material.dart';

class PaidLockBadge extends StatelessWidget {
  const PaidLockBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock, size: 15, color: color),
          const SizedBox(width: 4),
          Text(
            'Ödendi',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

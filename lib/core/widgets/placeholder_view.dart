/// Faz 0 iskeleti için ortak "yakında" gövdesi.
///
/// Faz 1+ ilerledikçe ilgili ekranın gerçek içeriğiyle değiştirilir.
library;

import 'package:flutter/material.dart';

/// Boş bir ekranın merkezine büyük ikon + başlık + mesaj koyar.
class PlaceholderView extends StatelessWidget {
  const PlaceholderView({
    super.key,
    required this.icon,
    required this.title,
    this.message = 'Yakında',
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

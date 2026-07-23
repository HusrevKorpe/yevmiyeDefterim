/// Ortak sanatsal onay diyaloğu — tüm ekranlarda tutarlı görünüm için.
///
/// Degrade tonlu ikon rozeti + ortalanmış başlık/mesaj + eşit genişlikte
/// yan yana iki buton (nötr "Vazgeç" / aksan renkli onay). Eski dağınık
/// [AlertDialog] kopyalarının yerini alır; [AlertDialog] üstüne kurulu
/// olduğundan `find.byType(AlertDialog)` testleri çalışmayı sürdürür.
library;

import 'package:flutter/material.dart';

/// Onay diyaloğunu açar; onaylanırsa `true`, vazgeçilir ya da dışına
/// dokunulursa `false` döner (null dönmez → çağrı yeri `if (!ok) return;`).
///
/// [accent] verilmezse yıkıcı varsayılan (tema `error` kırmızısı) kullanılır;
/// uyarı için sarı, olumlu işlem için `colorScheme.primary` geçilebilir.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required IconData icon,
  String cancelLabel = 'Vazgeç',
  Color? accent,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      icon: icon,
      accent: accent,
    ),
  );
  return ok == true;
}

/// Sanatsal onay kartı. Genelde doğrudan değil, [showConfirmDialog] ile açılır.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.icon,
    this.cancelLabel = 'Vazgeç',
    this.accent,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData icon;

  /// Onay butonu + ikon rozeti rengi; null → tema `error` (yıkıcı varsayılan).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accentColor = accent ?? cs.error;
    // Aksan üstünde okunur metin: koyu aksanda beyaz, açıkta (örn. sarı) koyu.
    final onAccent =
        ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
            ? Colors.white
            : Colors.black87;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Degrade tonlu ikon rozeti — sanatsal başlık dokunuşu.
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withValues(alpha: 0.22),
                  accentColor.withValues(alpha: 0.06),
                ],
              ),
            ),
            child: Icon(icon, size: 30, color: accentColor),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style:
                theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant, height: 1.35),
          ),
          const SizedBox(height: 24),
          // Eşit genişlikte iki buton; renkle ayrılır (nötr / aksan).
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      foregroundColor: cs.onSurfaceVariant,
                      backgroundColor: cs.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(cancelLabel),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(confirmLabel),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ortak sanatsal onay diyaloğu — tüm ekranlarda tutarlı görünüm için.
///
/// Artık ortak [AppDialog] iskelesinin ince bir sarmalayıcısıdır (degrade ikon
/// rozeti + ortalanmış başlık/mesaj + eşit iki buton). Public API korunur:
/// çağrı yerleri [showConfirmDialog] kullanmayı sürdürür; [AppDialog] da
/// [AlertDialog] üstüne kurulu olduğundan `find.byType(AlertDialog)` ve
/// `find.widgetWithText(FilledButton, …)` testleri çalışmayı sürdürür.
library;

import 'package:flutter/material.dart';

import 'app_dialog.dart';

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
    return AppDialog(
      icon: icon,
      title: title,
      message: message,
      // Onay diyaloğunun yıkıcı varsayılanı: aksan verilmezse tema kırmızısı.
      accent: accent ?? Theme.of(context).colorScheme.error,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      onConfirm: () => Navigator.pop(context, true),
      onCancel: () => Navigator.pop(context, false),
    );
  }
}

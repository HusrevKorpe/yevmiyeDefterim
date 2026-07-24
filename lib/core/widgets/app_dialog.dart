/// Uygulamanın TEK diyalog görünüm dili — onay, metin girişi, liste ve tutar
/// diyaloglarının hepsi bu iskeleyi paylaşır (eskiden her ekran kendi
/// [AlertDialog]'unu elde kuruyordu → görünüm sürüklenmesi olurdu).
///
/// Görünüm (Tarla Ekle diyaloğunun geliştirilmiş hâli):
///   • Beyaz zeminli, yumuşak yuvarlak (28 px) kart.
///   • Degrade tonlu, ince aksan halkalı ikon rozeti — sanatsal başlık.
///   • Ortalanmış başlık + isteğe bağlı açıklama.
///   • İsteğe bağlı içerik yuvası (giriş alanı, liste, özet satırları…).
///   • Eşit genişlikte, kompakt (46 px) iki buton: nötr "Vazgeç" / aksan onay.
///
/// [AlertDialog] üstüne kuruludur → `find.byType(AlertDialog)` ve onay
/// butonundaki `find.widgetWithText(FilledButton, …)` testleri çalışmayı sürdürür.
library;

import 'package:flutter/material.dart';

/// Ortak sanatsal diyalog kartı. Genelde doğrudan değil; onay için
/// [showConfirmDialog] (confirm_dialog.dart), metin girişi için
/// [showInputDialog] yardımcılarıyla ya da özel içerikli diyaloglarda
/// (ör. "Hesap Görüldü") gövde olarak kullanılır.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.confirmLabel,
    required this.onConfirm,
    this.message,
    this.content,
    this.cancelLabel = 'Vazgeç',
    this.onCancel,
    this.accent,
    this.confirmIcon,
    this.scrollable = false,
  });

  /// Üstteki degrade rozetin ikonu (her diyalogda vardır — sanatsal başlık).
  final IconData icon;
  final String title;

  /// Başlık altındaki açıklama (isteğe bağlı). Ortalanmış, sönük ton.
  final String? message;

  /// Başlık/mesaj ile butonlar arasına giren serbest içerik: metin alanı,
  /// liste, özet satırları… Yoksa kart onay diyaloğu gibi daralır.
  final Widget? content;

  final String confirmLabel;

  /// Onay butonuna basılınca çalışır. Genelde `Navigator.pop(context, …)`.
  final VoidCallback onConfirm;

  final String cancelLabel;

  /// Vazgeç butonuna basılınca; verilmezse yalnızca diyaloğu kapatır (`pop`).
  final VoidCallback? onCancel;

  /// Rozet + onay butonu rengi; null → tema `primary`. Yıkıcı işlemler için
  /// çağrı yeri `error` geçebilir (bkz. [showConfirmDialog]).
  final Color? accent;

  /// Onay butonu etiketinin soluna küçük ikon (ör. "Öde" için tik).
  final IconData? confirmIcon;

  /// İçerik uzun/klavye açılıyorsa (liste, tutar alanı) kaydırılabilir yap.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = accent ?? cs.primary;
    // Aksan üstünde okunur metin: koyu aksanda beyaz, açıkta (örn. sarı) koyu.
    final onAccent =
        ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
            ? Colors.white
            : Colors.black87;

    final hasContent = content != null;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          hasContent ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
      children: [
        Center(child: _Badge(icon: icon, accent: accentColor)),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant, height: 1.35),
          ),
        ],
        if (hasContent) ...[
          const SizedBox(height: 18),
          content!,
        ],
        const SizedBox(height: 22),
        _actions(context, cs, accentColor, onAccent),
      ],
    );

    // İçerik varsa TextField/ListView için genişlik sabitlenir (aksi hâlde
    // intrinsic-width hesabı çöker); yoksa kart içeriğe göre daralır.
    Widget inner = body;
    if (hasContent) {
      inner = SizedBox(
        width: double.maxFinite,
        child: scrollable ? SingleChildScrollView(child: body) : body,
      );
    } else if (scrollable) {
      inner = SingleChildScrollView(child: body);
    }

    return AlertDialog(
      // Kullanıcı isteği: beyaz zemin. Koyu temada beyaz göz almasın diye
      // yükseltilmiş koyu yüzey. surfaceTint kapalı → beyaz gerçekten beyaz kalır.
      backgroundColor: isDark ? cs.surfaceContainerHigh : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
      content: inner,
    );
  }

  Widget _actions(
      BuildContext context, ColorScheme cs, Color accent, Color onAccent) {
    return Row(
      children: [
        Expanded(
          child: _DialogButton(
            label: cancelLabel,
            onPressed: onCancel ?? () => Navigator.pop(context),
            filled: false,
            background: cs.surfaceContainerHighest,
            foreground: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DialogButton(
            label: confirmLabel,
            onPressed: onConfirm,
            filled: true,
            background: accent,
            foreground: onAccent,
            icon: confirmIcon,
          ),
        ),
      ],
    );
  }
}

/// Degrade tonlu, ince aksan halkalı ikon rozeti (sanatsal başlık dokunuşu).
class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.20),
            accent.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, size: 30, color: accent),
    );
  }
}

/// Diyalogların kompakt (46 px), yuvarlak buton çifti. Onay [FilledButton]
/// (testler `widgetWithText(FilledButton, …)` ile bulur), Vazgeç [TextButton].
class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.onPressed,
    required this.filled,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(15));
    const textStyle = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700);
    final child = FittedBox(
      fit: BoxFit.scaleDown,
      child: icon == null
          ? Text(label)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 6),
                Text(label),
              ],
            ),
    );

    return SizedBox(
      height: 46,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: background,
                foregroundColor: foreground,
                minimumSize: const Size(0, 46),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: textStyle,
                shape: shape,
              ),
              child: child,
            )
          : TextButton(
              onPressed: onPressed,
              style: TextButton.styleFrom(
                backgroundColor: background,
                foregroundColor: foreground,
                minimumSize: const Size(0, 46),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: textStyle,
                shape: shape,
              ),
              child: child,
            ),
    );
  }
}

/// Metin girişi isteyen sanatsal diyalog (Tarla Ekle/Düzenle gibi). Dönüş:
/// kaydedilen ham metin ya da vazgeçilirse `null`. Trim/boş denetimi çağrı
/// yerine bırakılır (eski davranış korunur).
Future<String?> showInputDialog(
  BuildContext context, {
  required String title,
  required IconData icon,
  String? message,
  String initialValue = '',
  String? hint,
  String? label,
  String confirmLabel = 'Kaydet',
  String cancelLabel = 'Vazgeç',
  TextCapitalization textCapitalization = TextCapitalization.sentences,
  Color? accent,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _InputDialog(
      title: title,
      icon: icon,
      message: message,
      initialValue: initialValue,
      hint: hint,
      label: label,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      textCapitalization: textCapitalization,
      accent: accent,
    ),
  );
}

class _InputDialog extends StatefulWidget {
  const _InputDialog({
    required this.title,
    required this.icon,
    required this.message,
    required this.initialValue,
    required this.hint,
    required this.label,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.textCapitalization,
    required this.accent,
  });

  final String title;
  final IconData icon;
  final String? message;
  final String initialValue;
  final String? hint;
  final String? label;
  final String confirmLabel;
  final String cancelLabel;
  final TextCapitalization textCapitalization;
  final Color? accent;

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppDialog(
      icon: widget.icon,
      title: widget.title,
      message: widget.message,
      accent: widget.accent,
      confirmLabel: widget.confirmLabel,
      cancelLabel: widget.cancelLabel,
      onConfirm: _submit,
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: widget.textCapitalization,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          filled: true,
          fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: cs.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

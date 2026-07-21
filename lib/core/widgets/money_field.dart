/// ₺ para giriş alanı (kural §1, §8).
///
/// TR biçimini (nokta=binlik, virgül=ondalık) [parseTlToKurus] ile doğrular.
/// Değeri okumak için `parseTlToKurus(controller.text)` kullanılır.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../money/money.dart';

class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.allowEmpty = false,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
    this.helperText,
    this.filled = false,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;

  /// Boş giriş geçerli mi? Doğruysa boş = 0 kuruş kabul edilir.
  final bool allowEmpty;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;
  final String? helperText;

  /// Dolgulu, yuvarlak, çerçevesiz görünüm (yeni giriş ekranlarının sade dili).
  /// Varsayılan çerçeveli — eski çağrı yerleri (Ayarlar) etkilenmez.
  final bool filled;

  String? _validate(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return allowEmpty ? null : 'Tutar girin.';
    final kurus = parseTlToKurus(t);
    if (kurus == null) {
      return 'Geçerli tutar girin (örn. 2.000 veya 2000,50).';
    }
    if (kurus < 0) return 'Tutar negatif olamaz.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = InputDecoration(
      labelText: label,
      helperText: helperText,
      helperMaxLines: 2,
      prefixText: '₺ ',
      border: const OutlineInputBorder(),
    );
    final decoration = !filled
        ? base
        : base.copyWith(
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
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
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
            ),
          );
    return TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      // Yalnız rakam, nokta ve virgül; harf/başka simge engellenir.
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      decoration: decoration,
      validator: _validate,
    );
  }
}

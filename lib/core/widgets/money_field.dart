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
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixText: '₺ ',
        border: const OutlineInputBorder(),
      ),
      validator: _validate,
    );
  }
}

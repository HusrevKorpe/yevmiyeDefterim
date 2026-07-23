/// Ortak "kayıt ekle/düzenle" form öğeleri — sanatsal + sade, tüm giriş
/// ekranlarında (Kasa, Mazot, Avans) tutarlı bir görünüm için tek kaynak.
///
/// [FieldLabel] bölüm etiketi, [AmountHeroField] formun odak "tutar" alanı,
/// [PickerTile] dokunulabilir seçim satırı (tarih vb.), [entryFieldDecoration]
/// dolgulu yuvarlak giriş süslemesi.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../money/money.dart';

/// Küçük, aralıklı, aksan çubuklu bölüm etiketi. Form alanlarını gruplar.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sanatsal "tutar" giriş alanı — formun odak noktası. Yumuşak tonlu kartta
/// büyük ₺ öneki + iri sayı. TR biçimini [parseTlToKurus] ile doğrular; değeri
/// `parseTlToKurus(controller.text)` ile okunur (MoneyField ile aynı sözleşme).
class AmountHeroField extends StatelessWidget {
  const AmountHeroField({
    super.key,
    required this.controller,
    this.label = 'Tutar',
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;

  String? _validate(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Tutar girin.';
    final kurus = parseTlToKurus(t);
    if (kurus == null) return 'Geçerli tutar girin (örn. 2.000).';
    if (kurus <= 0) return 'Tutar 0’dan büyük olmalı.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.10),
            accent.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '₺',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  enabled: enabled,
                  autofocus: autofocus,
                  textInputAction: textInputAction,
                  onFieldSubmitted:
                      onSubmitted == null ? null : (_) => onSubmitted!(),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  // Yalnız rakam, nokta ve virgül (MoneyField ile aynı kural).
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  cursorColor: accent,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: '0',
                    hintStyle: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.35),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  validator: _validate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dokunulabilir seçim satırı — ikon-daireli, değer + ok. Bölüm başlığı üstteki
/// [FieldLabel] ile verilir. Tarih gibi "dokun→aç" alanları için (düz butondan
/// daha zarif). Değer büyük yazı ölçeğinde FittedBox ile tek satıra sığdırılır.
class PickerTile extends StatelessWidget {
  const PickerTile({
    super.key,
    required this.icon,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  // Büyük yazı ölçeğinde uzun tarih taşmasın diye tek satırda
                  // küçültülerek sığdırılır (kesme değil, ölçekle).
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 1,
                      softWrap: false,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              if (enabled) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Seçim çipi — düz dropdown/segment yerine ikonlu, dokunulabilir seçenek
/// (kural §8). Kategori, işçi türü, cinsiyet gibi küçük kümeli seçimler için;
/// [Wrap] içine dizilir → büyük yazı ölçeğinde alt satıra kayar, taşmaz.
///
/// [accent] verilirse seçili tonu o renk olur (ör. cinsiyet mavi/pembe);
/// verilmezse marka yeşili (primaryContainer).
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    super.key,
    required this.selected,
    required this.label,
    this.icon,
    this.onSelected,
    this.accent,
  });

  final bool selected;
  final String label;
  final IconData? icon;
  final ValueChanged<bool>? onSelected;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selBg =
        accent == null ? cs.primaryContainer : accent!.withValues(alpha: 0.18);
    final selFg = accent ?? cs.onPrimaryContainer;
    return ChoiceChip(
      selected: selected,
      onSelected: onSelected,
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: 20,
              color: selected ? selFg : cs.onSurfaceVariant,
            ),
      label: Text(label),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        color: selected ? selFg : null,
      ),
      selectedColor: selBg,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? Colors.transparent : cs.outlineVariant,
        ),
      ),
    );
  }
}

/// Dolgulu, yuvarlak, çerçevesiz giriş süslemesi — not/dropdown alanları için.
/// Tüm giriş ekranlarında tutarlı "sade kart" hissi verir.
InputDecoration entryFieldDecoration(
  BuildContext context, {
  String? label,
  String? hint,
  IconData? icon,
}) {
  final theme = Theme.of(context);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon),
    filled: true,
    fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
}

/// [entryFieldDecoration]'ın [DropdownMenu] için tema karşılığı — DropdownMenu
/// süslemeyi tek tek değil tema olarak aldığından aynı "dolgulu yuvarlak"
/// görünüm buradan verilir.
InputDecorationThemeData entryFieldDecorationTheme(BuildContext context) {
  final theme = Theme.of(context);
  return InputDecorationThemeData(
    filled: true,
    fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
}

/// Ortak sanatsal başlık öğeleri — tüm ekranlarda tutarlı görünüm için.
///
/// [GradientAppBar]: standart [AppBar] yerine degrade + soluk dekoratif daireli
/// başlık (geri düğmesi ve aksiyonlar normal çalışır). [SectionTitle]: aksan
/// çubuklu bölüm başlığı (Ana Sayfa'daki "Bugün Özeti" ile aynı).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';

/// Degrade "hero" başlık. `appBar:` olarak kullanılır; içte gerçek bir [AppBar]
/// barındırır → `find.byType(AppBar)` ve otomatik geri düğmesi çalışmayı sürdürür.
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GradientAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  static Widget _circle(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: alpha),
          shape: BoxShape.circle,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: actions,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      centerTitle: true,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      flexibleSpace: const _HeaderBackground(),
    );
  }
}

/// Degrade + dekoratif daireler; AppBar arkasını (durum çubuğu dahil) doldurur.
class _HeaderBackground extends StatelessWidget {
  const _HeaderBackground();

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: kHeroGradient),
        child: Stack(
          children: [
            Positioned(
              top: -34,
              right: -22,
              child: GradientAppBar._circle(120, 0.09),
            ),
            Positioned(
              top: 18,
              right: 64,
              child: GradientAppBar._circle(58, 0.07),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aksan çubuklu bölüm başlığı. Sağa isteğe bağlı [trailing] eklenebilir.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

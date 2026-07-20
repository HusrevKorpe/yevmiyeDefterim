/// Uygulama kökü — `MaterialApp.router` + TR yerelleştirme (plan §1).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';
import 'theme_mode.dart';

/// Kök widget. Türkçe yerel ayar ve `₺`/tarih formatı bütün uygulamada geçerli.
class YevmiyeApp extends ConsumerWidget {
  const YevmiyeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    return MaterialApp.router(
      title: 'Yevmiye Defterim',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Düşük teknoloji dostu: en az 1.10x font. Sistem ayarı zaten daha büyükse
      // ona dokunmayız (kullanıcının ölçeği aynen korunur). Yalnızca taban
      // gerektiğinde DÜZ (linear) bir ölçek veririz — sonsuz-tavanlı `clamp`
      // KULLANMAYIZ. Aksi halde ambient ölçek `_ClampedTextScaler(min:1.10,
      // max:∞)` olur; Material tarih seçici (ve benzeri) ölçeği kendi tavanıyla
      // yeniden clamp'leyince min==max çakışıp `assert(maxScale > minScale)`
      // atıyor, takvim düzeni yarım kalıp RenderFlex ~99k px taşıyordu.
      builder: (context, child) {
        final data = MediaQuery.of(context);
        if (data.textScaler.scale(100) >= 110) return child!;
        return MediaQuery(
          data: data.copyWith(textScaler: const TextScaler.linear(1.10)),
          child: child!,
        );
      },
      routerConfig: router,
    );
  }
}

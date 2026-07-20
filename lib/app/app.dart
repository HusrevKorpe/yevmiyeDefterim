/// Uygulama kökü — `MaterialApp.router` + TR yerelleştirme (plan §1).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

/// Kök widget. Türkçe yerel ayar ve `₺`/tarih formatı bütün uygulamada geçerli.
class YevmiyeApp extends ConsumerWidget {
  const YevmiyeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'Yevmiye Defterim',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Düşük teknoloji dostu: en az 1.10x font. Kullanıcının sistem ayarı daha
      // büyükse ona saygı gösterilir (taban uygulanır, tavan uygulanmaz).
      builder: (context, child) {
        final scaler = MediaQuery.textScalerOf(context);
        final effective = scaler.scale(100) < 110
            ? const TextScaler.linear(1.10)
            : scaler;
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: effective.scale(1),
          maxScaleFactor: double.infinity,
          child: child!,
        );
      },
      routerConfig: router,
    );
  }
}

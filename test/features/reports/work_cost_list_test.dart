/// Tarla maliyeti listesi (kendi sayfasındaki döküm) — satır içeriği ve
/// işçi dökümünün açılıp kapanması.
///
/// Hesap mantığı `field_cost_test.dart` ile saf sınanır; burada aranan şey
/// listenin onu doğru göstermesi: yevmiye/gün/işçi satırı, tutar, tarlasız
/// satırın en sonda ve dokununca açılan işçi dökümü.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/features/reports/application/work_cost.dart';
import 'package:yevmiye_defterim/features/reports/presentation/widgets/work_cost_list.dart';

import 'work_cost_fixtures.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('tr_TR', null));

  Widget app(List<WorkCost> costs) => MaterialApp(
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: WorkCostList(costs: costs)),
      );

  testWidgets('tarla satırı: ad, yevmiye/gün/işçi ve tutar', (tester) async {
    await tester.pumpWidget(app(const [dere, bos]));

    expect(find.text('Dere Tarlası'), findsOneWidget);
    expect(find.text('2,5 yevmiye • 3 gün • 2 işçi'), findsOneWidget);
    expect(find.textContaining('5.000,00'), findsOneWidget);
    // Sıra rozeti yalnız gerçek tarlaya verilir.
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('tarlasız satır ayrı görünür', (tester) async {
    await tester.pumpWidget(app(const [dere, bos]));
    expect(find.text(kUnassignedPlotLabel), findsOneWidget);
    expect(find.text('1 yevmiye • 1 gün • 0 işçi'), findsOneWidget);
  });

  testWidgets('satıra dokununca işçi dökümü açılır, tekrar dokununca kapanır',
      (tester) async {
    await tester.pumpWidget(app(const [dere, bos]));
    expect(find.text('Ahmet'), findsNothing);

    await tester.tap(find.text('Dere Tarlası'));
    await tester.pumpAndSettle();
    expect(find.text('Ahmet'), findsOneWidget);
    expect(find.text('2 yevmiye'), findsOneWidget); // Ahmet'in payı
    expect(find.text('Veli'), findsOneWidget);
    expect(find.text('0,5 yevmiye'), findsOneWidget);

    await tester.tap(find.text('Dere Tarlası'));
    await tester.pumpAndSettle();
    expect(find.text('Ahmet'), findsNothing);
  });

  testWidgets('aynı anda tek satır açık kalır', (tester) async {
    await tester.pumpWidget(app(const [dere, bos]));

    await tester.tap(find.text('Dere Tarlası'));
    await tester.pumpAndSettle();
    expect(find.text('Ahmet'), findsOneWidget);

    // Kalıntı satırın dökümü yok ama açılması öncekini kapatır.
    await tester.tap(find.text(kUnassignedPlotLabel));
    await tester.pumpAndSettle();
    expect(find.text('Ahmet'), findsNothing);
    expect(find.text('İşçi dökümü yok.'), findsOneWidget);
  });

  testWidgets('başlık verilirse listenin üstünde çizilir', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(
        body: WorkCostList(
          costs: [dere],
          header: Text('DÖNEM ÖZETİ'),
        ),
      ),
    ));

    expect(find.text('DÖNEM ÖZETİ'), findsOneWidget);
    expect(find.text('Dere Tarlası'), findsOneWidget);
  });
}

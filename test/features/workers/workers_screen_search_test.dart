/// İşçiler ekranı arama akışı — "Ara" hapı, süzme ve "Kapat".
///
/// Eşleşme mantığı ayrıca `worker_search_test.dart` ile saf fonksiyon olarak
/// sınanır; burada aranan şey ekranın o mantığı doğru bağlayıp bağlamadığı:
/// arama açılınca kutu görünür, yazınca liste süzülür (yanlış yazımda bile),
/// kapanınca tüm liste geri gelir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/features/auth/application/user_access.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';
import 'package:yevmiye_defterim/features/workers/presentation/workers_screen.dart';

import '../../support/fake_worker_repository.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('tr_TR', null));

  Worker w(String id, String name, {bool active = true}) => Worker(
        id: id,
        name: name,
        type: WorkerType.gundelik,
        gender: Gender.male,
        dailyWageOverrideKurus: 100000,
        active: active,
      );

  Future<Widget> buildApp() async {
    final repo = FakeWorkerRepository();
    await repo.add(w('1', 'Ahmet Yılmaz'));
    await repo.add(w('2', 'Mehmet Kaya'));
    await repo.add(w('3', 'Şükrü Demir'));
    await repo.add(w('4', 'Hasan Çelik', active: false));

    return ProviderScope(
      overrides: [
        workerRepositoryProvider.overrideWithValue(repo),
        canSeeMoneyProvider.overrideWithValue(true),
      ],
      child: const MaterialApp(
        locale: Locale('tr', 'TR'),
        supportedLocales: [Locale('tr', 'TR')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: WorkersScreen(),
      ),
    );
  }

  Future<void> openSearch(WidgetTester tester) async {
    await tester.tap(find.text('Ara'));
    await tester.pumpAndSettle();
  }

  testWidgets('arama kapalıyken kutu yok, tüm liste görünür', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Ahmet Yılmaz'), findsOneWidget);
    expect(find.text('Mehmet Kaya'), findsOneWidget);
  });

  testWidgets('"Ara" hapı kutuyu açar, yazınca liste süzülür', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    await openSearch(tester);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'mehmet');
    await tester.pumpAndSettle();

    expect(find.text('Mehmet Kaya'), findsOneWidget);
    expect(find.text('Ahmet Yılmaz'), findsNothing);
    expect(find.text('1 sonuç'), findsOneWidget);
  });

  testWidgets('yanlış yazım ve Türkçe harf farkı sonucu bozmaz',
      (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();
    await openSearch(tester);

    // Yazım hatası.
    await tester.enterText(find.byType(TextField), 'mehmed');
    await tester.pumpAndSettle();
    expect(find.text('Mehmet Kaya'), findsOneWidget);

    // Türkçe harf kullanmadan.
    await tester.enterText(find.byType(TextField), 'sukru');
    await tester.pumpAndSettle();
    expect(find.text('Şükrü Demir'), findsOneWidget);
    expect(find.text('Mehmet Kaya'), findsNothing);
  });

  testWidgets('pasif işçi de aramada bulunur ve rozetlenir', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();
    await openSearch(tester);

    await tester.enterText(find.byType(TextField), 'hasan');
    await tester.pumpAndSettle();

    expect(find.text('Hasan Çelik'), findsOneWidget);
    expect(find.text('Pasif'), findsOneWidget);
  });

  testWidgets('sonuç yoksa nazik bilgi gösterilir', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();
    await openSearch(tester);

    await tester.enterText(find.byType(TextField), 'traktör');
    await tester.pumpAndSettle();

    expect(find.textContaining('bulunamadı'), findsOneWidget);
    expect(find.text('Ahmet Yılmaz'), findsNothing);
  });

  testWidgets('"Kapat" aramayı temizler, tüm liste geri gelir', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();
    await openSearch(tester);

    await tester.enterText(find.byType(TextField), 'mehmet');
    await tester.pumpAndSettle();
    expect(find.text('Ahmet Yılmaz'), findsNothing);

    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Ahmet Yılmaz'), findsOneWidget);
    expect(find.text('Mehmet Kaya'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dar ekran + büyük yazıda başlık ve arama kutusu taşmaz',
      (tester) async {
    // En dar desteklenen telefon (iPhone SE) + iri sistem yazısı: başlıkta artık
    // iki hap ("Ara" + "Ekle") yan yana duruyor (app.dart yazı ölçeğine tavan
    // koymuyor → taşma buradan gelir).
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: await buildApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await openSearch(tester);
    await tester.enterText(find.byType(TextField), 'ahmet');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('çarpı (Temizle) sorguyu siler, kutu açık kalır', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();
    await openSearch(tester);

    await tester.enterText(find.byType(TextField), 'mehmet');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Temizle'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget); // kutu hâlâ açık
    expect(find.text('Ahmet Yılmaz'), findsOneWidget);
  });
}

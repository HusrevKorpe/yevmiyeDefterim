/// Açık avans kartı: birden fazla avansı olan işçinin kartı KAPALI başlar
/// (tek satır: ad + toplam + "N avans"), başlığa dokununca tamamı açılır.
/// Tek avanslı işçide kapanma yoktur — satır her zaman görünür.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/core/date/app_date.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';
import 'package:yevmiye_defterim/features/advances/presentation/advances_screen.dart';

import '../../support/fake_advance_repository.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('tr_TR', null));

  Advance adv({
    required String id,
    required String workerId,
    required String workerName,
    required String date,
    int amountKurus = 50000,
  }) =>
      Advance(
        id: id,
        workerId: workerId,
        workerName: workerName,
        amountKurus: amountKurus,
        date: date,
      );

  Widget buildApp(FakeAdvanceRepository repo) => ProviderScope(
        overrides: [advanceRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          locale: Locale('tr', 'TR'),
          supportedLocales: [Locale('tr', 'TR')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AdvancesScreen(),
        ),
      );

  testWidgets('birden fazla avans → kart kapalı, dokununca açılır',
      (tester) async {
    final repo = FakeAdvanceRepository([
      adv(id: 'a1', workerId: 'w1', workerName: 'Ahmet', date: '2026-07-10'),
      adv(id: 'a2', workerId: 'w1', workerName: 'Ahmet', date: '2026-07-12'),
      adv(id: 'a3', workerId: 'w1', workerName: 'Ahmet', date: '2026-07-14'),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    // Kapalı: özet satırı var, tarih satırları yok.
    expect(find.text('Ahmet'), findsOneWidget);
    expect(
      find.text('3 avans • son ${formatHumanDateNoWeekday('2026-07-14')}'),
      findsOneWidget,
    );
    expect(find.text(formatHumanDate('2026-07-14')), findsNothing);
    expect(find.text(formatHumanDate('2026-07-10')), findsNothing);

    // Başlığa dokun → tamamı açılır.
    await tester.tap(find.text('Ahmet'));
    await tester.pumpAndSettle();
    expect(find.text('3 avans'), findsOneWidget);
    expect(find.text(formatHumanDate('2026-07-14')), findsOneWidget);
    expect(find.text(formatHumanDate('2026-07-12')), findsOneWidget);
    expect(find.text(formatHumanDate('2026-07-10')), findsOneWidget);

    // Tekrar dokun → kapanır.
    await tester.tap(find.text('Ahmet'));
    await tester.pumpAndSettle();
    expect(find.text(formatHumanDate('2026-07-10')), findsNothing);
  });

  testWidgets('tek avans → kart hep açık (kapatma oku yok)', (tester) async {
    final repo = FakeAdvanceRepository([
      adv(id: 'a1', workerId: 'w2', workerName: 'Veli', date: '2026-07-10'),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    expect(find.text('Veli'), findsOneWidget);
    expect(find.text(formatHumanDate('2026-07-10')), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsNothing);
  });

  testWidgets('açık kartta avans satırına dokunmak düzenlemeyi açar',
      (tester) async {
    final repo = FakeAdvanceRepository([
      adv(id: 'a1', workerId: 'w1', workerName: 'Ahmet', date: '2026-07-10'),
      adv(id: 'a2', workerId: 'w1', workerName: 'Ahmet', date: '2026-07-12'),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ahmet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(formatHumanDate('2026-07-12')));
    await tester.pumpAndSettle();

    expect(find.text('Avansı Düzenle'), findsOneWidget);
  });
}

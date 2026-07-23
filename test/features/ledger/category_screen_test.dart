/// Kategori ekranı widget testi — tahsilat/bakiye görünümü (kural §8).
///
/// Tahsilat (esnafa önden verilen para) kayıtları listede yeşil `+` ile
/// "Mazot Tahsilatı" olarak ayrışır; üst kart "verilen / harcanan / kalan"
/// bakiyesini gösterir. Hiç tahsilat yoksa eski sade tek-satır toplam korunur
/// (mevcut kullanıcılar için görünüm değişmez).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/core/constants/categories.dart';
import 'package:yevmiye_defterim/core/money/money.dart';
import 'package:yevmiye_defterim/features/ledger/application/ledger_providers.dart';
import 'package:yevmiye_defterim/features/ledger/data/ledger_entry.dart';
import 'package:yevmiye_defterim/features/ledger/presentation/category_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  /// [ledgerStreamProvider]'ı verilen kayıtlarla değiştirip Mazot ekranını kurar.
  Widget buildApp(List<LedgerEntry> entries) {
    return ProviderScope(
      overrides: [
        ledgerStreamProvider.overrideWith((ref) => Stream.value(entries)),
      ],
      child: const MaterialApp(
        locale: Locale('tr', 'TR'),
        supportedLocales: [Locale('tr', 'TR')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: CategoryScreen(category: LedgerCategory.mazot),
      ),
    );
  }

  LedgerEntry mazot(String id, int amountKurus,
          {String kind = LedgerKind.gider}) =>
      LedgerEntry(
        id: id,
        category: LedgerCategory.mazot,
        amountKurus: amountKurus,
        date: '2026-07-15',
        source: LedgerSource.manual,
        kind: kind,
      );

  testWidgets('tahsilat YOKKEN eski sade toplam görünümü korunur',
      (tester) async {
    await tester.pumpWidget(buildApp([
      mazot('g1', 200000),
      mazot('g2', 500000),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Toplam mazot (2 kayıt)'), findsOneWidget);
    expect(find.text('Verilen para'), findsNothing);
    expect(find.text('Kalan'), findsNothing);
  });

  testWidgets('tahsilat VARKEN bakiye kartı: verilen − harcanan = kalan',
      (tester) async {
    await tester.pumpWidget(buildApp([
      // 30.000 + 20.000 TL önden verildi; 2.000 + 5.000 TL alım yapıldı.
      mazot('t1', 3000000, kind: LedgerKind.tahsilat),
      mazot('t2', 2000000, kind: LedgerKind.tahsilat),
      mazot('g1', 200000),
      mazot('g2', 500000),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Verilen para'), findsOneWidget);
    expect(find.text('Harcanan'), findsOneWidget);
    expect(find.text('Kalan'), findsOneWidget);
    expect(find.text('+${formatKurus(5000000)}'), findsOneWidget); // verilen
    expect(find.text('−${formatKurus(700000)}'), findsOneWidget); // harcanan
    expect(find.text(formatKurus(4300000)), findsOneWidget); // kalan
    // Tahsilat satırları listede ayrışır (yeşil `+` ve kendi başlığı).
    expect(find.text('Mazot Tahsilatı'), findsNWidgets(2));
    expect(find.text('+${formatKurus(3000000)}'), findsOneWidget);
    // Eski tek-satır toplam bu görünümde yok.
    expect(find.textContaining('Toplam mazot'), findsNothing);
  });
}

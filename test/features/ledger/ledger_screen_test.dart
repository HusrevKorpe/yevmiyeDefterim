/// Kasa (Giderler) ekranı widget testi — iki davranışı sabitler:
///
/// 1. Özet kartı (₺ "Toplam Gider") YALNIZ veri hazırken görünür (kural §8).
///    Regresyon: özet eskiden akışı `.asData?.value ?? []` ile yutan ayrı bir
///    sağlayıcıdan okunuyordu; yükleniyor/hata durumunda bile ₺0'lık "boş özet"
///    görünüyor, kullanıcı "hiç gider yok" sanıyordu.
/// 2. Liste tüm geçmişi gösterir ve ay değişince araya ay ayracı girer
///    ("Temmuz 2026 · −₺X" — ayraçtaki tutar O AYIN toplamı).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/core/constants/categories.dart';
import 'package:yevmiye_defterim/core/money/money.dart';
import 'package:yevmiye_defterim/features/ledger/application/ledger_providers.dart';
import 'package:yevmiye_defterim/features/ledger/data/ledger_entry.dart';
import 'package:yevmiye_defterim/features/ledger/presentation/ledger_screen.dart';
import 'package:yevmiye_defterim/features/ledger/presentation/widgets/ledger_entry_tile.dart';
import 'package:yevmiye_defterim/features/ledger/presentation/widgets/month_header_row.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  /// Kayıt akışını değiştirip Giderler ekranını kurar.
  Widget buildApp(Stream<List<LedgerEntry>> entries) {
    return ProviderScope(
      overrides: [
        ledgerStreamProvider.overrideWith((ref) => entries),
      ],
      child: const MaterialApp(
        locale: Locale('tr', 'TR'),
        supportedLocales: [Locale('tr', 'TR')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: LedgerScreen(),
      ),
    );
  }

  LedgerEntry expense(String id, int amountKurus) => LedgerEntry(
        id: id,
        category: LedgerCategory.genel,
        amountKurus: amountKurus,
        date: '2026-07-15',
        source: LedgerSource.manual,
        note: 'Test gideri',
      );

  testWidgets('YÜKLENİYOR: özet kartı gösterilmez, spinner çıkar', (tester) async {
    final stuck = StreamController<List<LedgerEntry>>();
    addTearDown(stuck.close);

    await tester.pumpWidget(buildApp(stuck.stream));
    await tester.pump(); // hiç emisyon yok → AsyncLoading

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Kritik: yükleniyorken ₺0 "boş özet" gösterilmez.
    expect(find.text('Toplam Gider'), findsNothing);

    // AsyncRetry'nin bekleme sayacını iptal etmek için ağacı söküp bırak.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('HATA: özet kartı gösterilmez, "Yeniden Dene" çıkar', (tester) async {
    await tester.pumpWidget(buildApp(Stream.error('izin reddedildi')));
    await tester.pumpAndSettle();

    expect(find.text('Yeniden Dene'), findsOneWidget);
    // Kritik: hata "kayıt yok" (₺0 özet) sanılmaz.
    expect(find.text('Toplam Gider'), findsNothing);
  });

  testWidgets('VERİ: özet kartı + gider satırı gösterilir', (tester) async {
    await tester.pumpWidget(buildApp(Stream.value([expense('e1', 150000)])));
    await tester.pumpAndSettle();

    expect(find.text('Toplam Gider'), findsOneWidget);
    expect(find.byType(LedgerEntryTile), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Yeniden Dene'), findsNothing);
  });

  testWidgets('YÜKLENMİŞ-BOŞ: ₺0 özet VAR (gerçekten boş, hata değil)',
      (tester) async {
    await tester.pumpWidget(buildApp(Stream.value(const [])));
    await tester.pumpAndSettle();

    // Veri geldi ve gerçekten boş → özet gösterilir (yükleniyor/hatadan farkı bu).
    expect(find.text('Toplam Gider'), findsOneWidget);
    expect(find.text('Henüz gider kaydı yok'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Yeniden Dene'), findsNothing);
  });

  testWidgets('GEÇMİŞ: eski aylar da listede, ay değişince ayraç girer',
      (tester) async {
    LedgerEntry at(String id, String date, int amountKurus) => LedgerEntry(
          id: id,
          category: LedgerCategory.genel,
          amountKurus: amountKurus,
          date: date,
          source: LedgerSource.manual,
        );

    await tester.pumpWidget(buildApp(Stream.value([
      at('a1', '2026-08-01', 100000), // Ağustos: ₺1.000
      at('t1', '2026-07-20', 250000), // Temmuz: ₺2.500 + ₺500
      at('t2', '2026-07-05', 50000),
    ])));
    await tester.pumpAndSettle();

    // Üç kayıt da tek listede; ay değişince ayraç satırı girer.
    expect(find.byType(LedgerEntryTile), findsNWidgets(3));
    expect(find.byType(MonthHeaderRow), findsNWidgets(2));
    expect(find.text('Ağustos 2026'), findsOneWidget);
    expect(find.text('Temmuz 2026'), findsOneWidget);

    // Ayraçtaki tutar O AYIN toplamı (tüm zamanların değil).
    Finder inHeader(String text) => find.descendant(
          of: find.byType(MonthHeaderRow),
          matching: find.text(text),
        );
    expect(inHeader('−${formatKurus(100000)}'), findsOneWidget);
    expect(inHeader('−${formatKurus(300000)}'), findsOneWidget);
  });
}

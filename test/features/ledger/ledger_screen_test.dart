/// Kasa ekranı widget testi — özet kartının (₺ "Toplam Gider") YALNIZ veri
/// hazırken gösterildiğini sabitler (kural §8).
///
/// Regresyon: özet eskiden [ledgerInPeriodProvider]'ı `.asData?.value ?? []` ile
/// yutan ayrı bir sağlayıcıdan okunuyordu; bu yüzden yükleniyor/hata durumunda
/// bile ₺0'lık "boş özet" görünüyor, kullanıcı "hiç gider yok" sanıyordu. Artık
/// özet AsyncRetry'nin veri closure'ında `summarizeLedger(entries)` ile türetilir.
/// Bu test o davranışı kilitler: yükleniyor/hata → özet YOK; yüklenmiş-boş → ₺0
/// özet VAR (gerçekten boş dönem, hata değil).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/core/constants/categories.dart';
import 'package:yevmiye_defterim/features/ledger/application/ledger_providers.dart';
import 'package:yevmiye_defterim/features/ledger/data/ledger_entry.dart';
import 'package:yevmiye_defterim/features/ledger/presentation/ledger_screen.dart';
import 'package:yevmiye_defterim/features/ledger/presentation/widgets/ledger_entry_tile.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  /// [ledgerInPeriodProvider]'ı verilen akışla değiştirip Kasa ekranını kurar.
  Widget buildApp(Stream<List<LedgerEntry>> entries) {
    return ProviderScope(
      overrides: [
        ledgerInPeriodProvider.overrideWith((ref) => entries),
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

  testWidgets('YÜKLENMİŞ-BOŞ: ₺0 özet VAR (gerçekten boş dönem, hata değil)',
      (tester) async {
    await tester.pumpWidget(buildApp(Stream.value(const [])));
    await tester.pumpAndSettle();

    // Veri geldi ve gerçekten boş → özet gösterilir (yükleniyor/hatadan farkı bu).
    expect(find.text('Toplam Gider'), findsOneWidget);
    expect(find.text('Bu dönemde kayıt yok'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Yeniden Dene'), findsNothing);
  });
}

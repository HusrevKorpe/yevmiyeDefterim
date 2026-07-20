/// Görsel doğrulama: Kasa ve Avans düzenleme ekranlarındaki "Tarih: …" takvim
/// butonu, uzun TR tarih ("31 Ağustos 2026, Pazartesi") + büyük sistem yazısında
/// taşmamalı/satır bölünmemeli. FittedBox(scaleDown) ile tek satırda küçülerek
/// sığar. Bu regresyon `flutter test` ile tam yakalanamaz (gerçek font metrikleri)
/// → simülatörde ekran görüntüsüyle doğrulanır.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/app/theme.dart';
import 'package:yevmiye_defterim/core/constants/categories.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';
import 'package:yevmiye_defterim/features/advances/presentation/advance_edit_screen.dart';
import 'package:yevmiye_defterim/features/ledger/application/ledger_providers.dart';
import 'package:yevmiye_defterim/features/ledger/data/ledger_entry.dart';
import 'package:yevmiye_defterim/features/ledger/presentation/ledger_edit_screen.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';

import '../test/support/fake_advance_repository.dart';
import '../test/support/fake_ledger_repository.dart';
import '../test/support/fake_worker_repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // En uzun görünümlü tarih: "31 Ağustos 2026, Pazartesi".
  const longDate = '2026-08-31';

  // Ekranı, uygulamanın gerçek teması + TR yerelleştirmesiyle, verilen yazı
  // ölçeğine zorlayarak sarar (tavansız büyük yazı senaryosu).
  Widget wrap(Widget screen, {required double scale}) => ProviderScope(
        overrides: [
          ledgerRepositoryProvider.overrideWithValue(FakeLedgerRepository()),
          advanceRepositoryProvider.overrideWithValue(FakeAdvanceRepository()),
          workerRepositoryProvider.overrideWithValue(FakeWorkerRepository()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          locale: const Locale('tr', 'TR'),
          supportedLocales: const [Locale('tr', 'TR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            minScaleFactor: scale,
            maxScaleFactor: scale,
            child: child!,
          ),
          home: screen,
        ),
      );

  final ledgerEntry = LedgerEntry(
    id: 'l1',
    type: LedgerType.expense,
    category: LedgerCategory.genel,
    amountKurus: 175000,
    date: longDate,
    source: LedgerSource.manual,
    note: 'Görsel doğrulama',
  );

  const advance = Advance(
    id: 'a1',
    workerId: 'w1',
    workerName: 'Ahmet Yılmaz',
    amountKurus: 250000,
    date: longDate,
  );

  testWidgets('Tarih butonu — büyük yazıda taşmaz (Kasa + Avans)',
      (tester) async {
    await initializeDateFormatting('tr_TR', null);

    // Kasa düzenleme — normal büyük (1.3x) ve aşırı (2.6x) ölçek.
    await tester.pumpWidget(wrap(LedgerEditScreen(entry: ledgerEntry), scale: 1.3));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('date-kasa-x1.3');

    await tester.pumpWidget(wrap(LedgerEditScreen(entry: ledgerEntry), scale: 2.6));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('date-kasa-x2.6');

    // Avans düzenleme — aynı iki ölçek.
    await tester.pumpWidget(wrap(const AdvanceEditScreen(advance: advance), scale: 1.3));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('date-avans-x1.3');

    await tester.pumpWidget(wrap(const AdvanceEditScreen(advance: advance), scale: 2.6));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('date-avans-x2.6');

    // Hard RenderFlex taşması olmamalı.
    expect(tester.takeException(), isNull);
  });
}

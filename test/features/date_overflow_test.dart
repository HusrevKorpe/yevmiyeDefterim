/// Tarih başlıklarının dar ekran + büyük yazı ölçeğinde taşmadığını doğrular.
///
/// Kök sebep sınıfı: uzun TR insancıl tarih ("29 Ağustos 2026, Cumartesi")
/// dar/tek satırlı bir kapta → kesme, çok satıra bölünme ya da piksel taşması.
/// Uygulama yazı ölçeğine TAVAN koymadığı (app.dart) için büyük sistem
/// yazısında bu kritik; regresyonu burada büyük ölçekle kilitliyoruz.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/core/widgets/entry_form.dart';
import 'package:yevmiye_defterim/core/widgets/period_range_selector.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/advances/presentation/advance_edit_screen.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/presentation/attendance_screen.dart';
import 'package:yevmiye_defterim/features/ledger/application/ledger_providers.dart';
import 'package:yevmiye_defterim/features/ledger/presentation/ledger_edit_screen.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_providers.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';

import '../support/fake_advance_repository.dart';
import '../support/fake_attendance_repository.dart';
import '../support/fake_ledger_repository.dart';
import '../support/fake_settings_repository.dart';
import '../support/fake_worker_repository.dart';

/// En dar desteklenen telefon (küçük iPhone SE) + verilen yazı ölçeği.
Future<void> _pumpNarrow(
  WidgetTester tester,
  Widget child, {
  double scale = 1.3,
}) async {
  tester.view.physicalSize = const Size(320, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: child,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR', null));

  testWidgets('Yoklama tarih başlığı dar ekranda taşmaz', (tester) async {
    await _pumpNarrow(
      tester,
      ProviderScope(
        overrides: [
          workerRepositoryProvider.overrideWithValue(FakeWorkerRepository()),
          settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
          attendanceRepositoryProvider
              .overrideWithValue(FakeAttendanceRepository()),
        ],
        child: const MaterialApp(home: AttendanceScreen()),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.3, 2.0]) {
    testWidgets('Dönem pili (Hakediş/Kasa/Rapor) x$scale taşmaz',
        (tester) async {
      await _pumpNarrow(
        tester,
        MaterialApp(
          home: Scaffold(
            body: PeriodRangeSelector(
              startIso: '2026-09-28', // "28 Eylül" — uzun ay adı
              endIso: '2026-12-31',
              onSetStart: (_) {},
              onSetEnd: (_) {},
              onThisWeek: () {},
              onThisMonth: () {},
            ),
          ),
        ),
        scale: scale,
      );

      expect(tester.takeException(), isNull);
    });
  }

  // Kasa (gider) düzenleme ekranındaki tarih [PickerTile]: uzun TR tarih +
  // büyük yazı ölçeğinde taşmamalı ve değer FittedBox ile sığdırılmalı
  // (regresyon: birisi düz Text'e geri dönerse test kırılır).
  testWidgets('Kasa düzenleme tarih satırı dar ekran x2.0 taşmaz',
      (tester) async {
    await _pumpNarrow(
      tester,
      ProviderScope(
        overrides: [
          ledgerRepositoryProvider.overrideWithValue(FakeLedgerRepository()),
        ],
        child: const MaterialApp(home: LedgerEditScreen()),
      ),
      scale: 2.0,
    );

    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(PickerTile),
        matching: find.byType(FittedBox),
      ),
      findsOneWidget,
    );
  });

  // Avans ekle/düzenle ekranındaki tarih [PickerTile] için aynı güvence.
  testWidgets('Avans düzenleme tarih satırı dar ekran x2.0 taşmaz',
      (tester) async {
    await _pumpNarrow(
      tester,
      ProviderScope(
        overrides: [
          advanceRepositoryProvider.overrideWithValue(FakeAdvanceRepository()),
          workerRepositoryProvider.overrideWithValue(FakeWorkerRepository()),
        ],
        child: const MaterialApp(home: AdvanceEditScreen()),
      ),
      scale: 2.0,
    );

    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(PickerTile),
        matching: find.byType(FittedBox),
      ),
      findsOneWidget,
    );
  });
}

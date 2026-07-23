/// Tahsilat akışı — GERÇEK uygulamayı çalıştırır; yalnız veri katmanı
/// bellek-içi seed'li fake'lerle değiştirilir. Görsel doğrulanan akış:
/// Giderler listesi (tahsilat yeşil `+`, toplam gider tahsilatsız) → Mazot
/// ekranı (verilen/harcanan/kalan bakiye kartı) → Ekle formunda "Tür"
/// seçiciden Tahsilat girme → kaydet sonrası güncel bakiye. Büyük sistem
/// yazısında (2.0x) bakiye kartının taşmadığı da ayrıca doğrulanır.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/app/app.dart';
import 'package:yevmiye_defterim/core/constants/categories.dart';
import 'package:yevmiye_defterim/core/widgets/entry_form.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/auth/application/auth_providers.dart';
import 'package:yevmiye_defterim/features/auth/data/app_user.dart';
import 'package:yevmiye_defterim/features/ledger/application/ledger_providers.dart';
import 'package:yevmiye_defterim/features/ledger/data/ledger_entry.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_providers.dart';
import 'package:yevmiye_defterim/features/settings/data/app_settings.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';

import '../test/support/fake_advance_repository.dart';
import '../test/support/fake_attendance_repository.dart';
import '../test/support/fake_auth_repository.dart';
import '../test/support/fake_ledger_repository.dart';
import '../test/support/fake_settings_repository.dart';
import '../test/support/fake_worker_repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  LedgerEntry entry({
    required String id,
    required int amount,
    required String date,
    String category = LedgerCategory.mazot,
    String kind = LedgerKind.gider,
    String? note,
  }) =>
      LedgerEntry(
        id: id,
        category: category,
        amountKurus: amount,
        date: date,
        source: LedgerSource.manual,
        kind: kind,
        note: note,
      );

  /// Seed: 50.000 ₺ tahsilat + 2.000/5.000 ₺ mazot alımı + 600 ₺ genel gider.
  FakeLedgerRepository seedLedger() => FakeLedgerRepository([
        entry(
          id: 't1',
          amount: 5000000, // 50.000 ₺ önden verilen para
          date: '2026-07-03',
          kind: LedgerKind.tahsilat,
          note: 'Mazotçuya önden',
        ),
        entry(id: 'g1', amount: 200000, date: '2026-07-10', note: 'Traktör'),
        entry(id: 'g2', amount: 500000, date: '2026-07-05'),
        entry(
          id: 'g3',
          amount: 60000,
          date: '2026-07-08',
          category: LedgerCategory.genel,
          note: 'İlaç',
        ),
      ]);

  Future<void> pumpApp(WidgetTester tester, FakeLedgerRepository ledger) async {
    await initializeDateFormatting('tr_TR', null);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(const AppUser(uid: 'u1', email: 'demo@ciftlik.tr')),
        ),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository(
          const AppSettings(
            defaultWageMaleKurus: 200000,
            defaultWageFemaleKurus: 180000,
            defaultCrewRateKurus: 150000,
          ),
        )),
        workerRepositoryProvider.overrideWithValue(FakeWorkerRepository()),
        attendanceRepositoryProvider
            .overrideWithValue(FakeAttendanceRepository()),
        advanceRepositoryProvider.overrideWithValue(FakeAdvanceRepository()),
        ledgerRepositoryProvider.overrideWithValue(ledger),
      ],
      child: const YevmiyeApp(),
    ));
    await tester.pumpAndSettle();

    // Dönemi deterministik yap (makine saatinden bağımsız).
    final container = ProviderScope.containerOf(
      tester.element(find.byType(YevmiyeApp)),
      listen: false,
    );
    container.read(ledgerPeriodProvider.notifier).setStart('2026-07-01');
    container.read(ledgerPeriodProvider.notifier).setEnd('2026-07-31');
    await tester.pumpAndSettle();
  }

  Future<void> openMazot(WidgetTester tester) async {
    await tester.tap(find.text('Giderler').last);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AppBar),
      matching: find.widgetWithIcon(IconButton, Icons.local_gas_station),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Giderler + Mazot bakiyesi + Tür seçiciyle tahsilat ekleme',
      (tester) async {
    await pumpApp(tester, seedLedger());

    // Giderler listesi: tahsilat yeşil `+` satırı; toplam gider tahsilatsız.
    await tester.tap(find.text('Giderler').last);
    await tester.pumpAndSettle();
    expect(find.text('Mazot Tahsilatı'), findsOneWidget);
    await binding.takeScreenshot('tahsilat-01-giderler-liste');

    // Mazot ekranı: verilen/harcanan/kalan bakiye kartı.
    await tester.tap(find.descendant(
      of: find.byType(AppBar),
      matching: find.widgetWithIcon(IconButton, Icons.local_gas_station),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Verilen para'), findsOneWidget);
    expect(find.text('Kalan'), findsOneWidget);
    await binding.takeScreenshot('tahsilat-02-mazot-bakiye');

    // Ekle formu: kategori Mazot ön seçili → "Tür" seçici görünür.
    await tester.tap(find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Ekle'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SelectableChip, 'Tahsilat'));
    await tester.pumpAndSettle();
    final amountField = find.descendant(
        of: find.byType(AmountHeroField), matching: find.byType(TextField));
    await tester.enterText(amountField, '10.000');
    await tester.enterText(find.byType(TextField).last, 'İkinci ödeme');
    await tester.pumpAndSettle();
    await binding.takeScreenshot('tahsilat-03-tur-secici-form');

    // Kaydet → Mazot ekranına dön: verilen 60.000, kalan 53.000.
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Mazot Tahsilatı'), findsNWidgets(2));
    expect(find.textContaining('İkinci ödeme'), findsOneWidget);
    await binding.takeScreenshot('tahsilat-04-mazot-sonrasi');
  });

  testWidgets('Büyük sistem yazısında (2.0x) bakiye kartı taşmaz',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(tester, seedLedger());
    await openMazot(tester);
    expect(find.text('Kalan'), findsOneWidget);
    await binding.takeScreenshot('tahsilat-05-bakiye-scale2');
    expect(tester.takeException(), isNull);
  });
}

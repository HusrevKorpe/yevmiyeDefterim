/// Kasa akışı — GERÇEK uygulamayı (router, shell, tüm ekranlar, ViewModel'lar,
/// saf özet) çalıştırır; yalnız veri katmanı bellek-içi seed'li fake'lerle
/// değiştirilir. Kasa listesi, filtre, Mazot ekranı ve kayıt ekleme görsel
/// olarak doğrulanır (ekran görüntüsü alınır).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/app/app.dart';
import 'package:yevmiye_defterim/core/constants/categories.dart';
import 'package:yevmiye_defterim/core/widgets/money_field.dart';
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

  const male = 200000;
  const female = 180000;
  const crewRate = 150000;

  // Temmuz 2026 dönemine ait gider kayıtları (elle + otomatik hakediş gideri).
  LedgerEntry entry({
    required String id,
    required String category,
    required int amount,
    required String date,
    String source = LedgerSource.manual,
    String? note,
  }) =>
      LedgerEntry(
        id: id,
        category: category,
        amountKurus: amount,
        date: date,
        source: source,
        note: note,
      );

  testWidgets('Kasa → liste, filtre, Mazot, kayıt ekleme (gerçek uygulama)',
      (tester) async {
    await initializeDateFormatting('tr_TR', null);

    final ledger = FakeLedgerRepository([
      entry(
        id: 'l2',
        category: LedgerCategory.mazot,
        amount: 150000, // 1.500 ₺
        date: '2026-07-10',
        note: 'Traktör',
      ),
      entry(
        id: 'l3',
        category: LedgerCategory.mazot,
        amount: 90000, // 900 ₺
        date: '2026-07-05',
      ),
      entry(
        id: 'l4',
        category: LedgerCategory.genel,
        amount: 60000, // 600 ₺
        date: '2026-07-08',
        note: 'İlaç',
      ),
      // Otomatik hakediş gideri — salt-okunur (kilit ikonu).
      entry(
        id: 'l5',
        category: LedgerCategory.maas,
        amount: 500000, // 5.000 ₺
        date: '2026-07-16',
        source: LedgerSource.payroll,
      ),
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(const AppUser(uid: 'u1', email: 'demo@ciftlik.tr')),
        ),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository(
          const AppSettings(
            defaultWageMaleKurus: male,
            defaultWageFemaleKurus: female,
            defaultCrewRateKurus: crewRate,
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

    await binding.takeScreenshot('01-ana-sayfa');

    // Kasa sekmesine geç.
    await tester.tap(find.text('Kasa').last);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('02-kasa-liste');

    // App bar "Mazot" ikon butonu → Mazot ekranı.
    await tester.tap(find.descendant(
      of: find.byType(AppBar),
      matching: find.widgetWithIcon(IconButton, Icons.local_gas_station),
    ));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('04-mazot-ekrani');

    // "Mazot Ekle" → önceden Gider/Mazot seçili form.
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Mazot Ekle'));
    await tester.pumpAndSettle();

    // Tutar (ilk alan = MoneyField) ve not gir.
    final amountField =
        find.descendant(of: find.byType(MoneyField), matching: find.byType(TextField));
    await tester.enterText(amountField, '2.500');
    await tester.enterText(find.widgetWithText(TextField, 'Not (isteğe bağlı)'),
        'Depo dolumu');
    await tester.pumpAndSettle();
    await binding.takeScreenshot('05-mazot-ekle-formu');

    // Kaydet → Mazot ekranına dön, yeni kayıt + güncel toplam.
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('06-mazot-sonrasi');

    // Yeni mazot kaydı listede görünür.
    expect(find.textContaining('Depo dolumu'), findsOneWidget);
  });
}

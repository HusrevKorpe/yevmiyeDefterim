/// Ortak onay diyaloğu görsel doğrulaması — GERÇEK uygulamada bir gider
/// kaydı açılır, "Kaydı Sil" ile yeni sanatsal [ConfirmDialog] ekrana
/// getirilir (degrade ikon rozeti + eşit genişlikte Vazgeç/Sil) ve ekran
/// görüntüsü alınır. Vazgeç'in kapattığı da doğrulanır.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/app/app.dart';
import 'package:yevmiye_defterim/core/constants/categories.dart';
import 'package:yevmiye_defterim/core/widgets/confirm_dialog.dart';
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

  testWidgets('Gider sil onayı — yeni ConfirmDialog görünümü', (tester) async {
    await initializeDateFormatting('tr_TR', null);

    final ledger = FakeLedgerRepository([
      const LedgerEntry(
        id: 'l1',
        category: LedgerCategory.mazot,
        amountKurus: 150000, // 1.500 ₺
        date: '2026-07-10',
        source: LedgerSource.manual,
        note: 'Traktör',
      ),
    ]);

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

    // Giderler → kaydı aç → "Kaydı Sil".
    await tester.tap(find.text('Giderler').last);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Traktör'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Kaydı Sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydı Sil'));
    await tester.pumpAndSettle();

    // Yeni sanatsal onay diyaloğu: rozet ikonu + eşit iki buton.
    expect(find.byType(ConfirmDialog), findsOneWidget);
    expect(find.text('Kaydı sil'), findsOneWidget);
    expect(find.text('Vazgeç'), findsOneWidget);
    expect(find.text('Sil'), findsOneWidget);
    await binding.takeScreenshot('confirm-01-sil-onayi');

    // Vazgeç → diyalog kapanır, kayıt durur.
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(find.byType(ConfirmDialog), findsNothing);
  });
}

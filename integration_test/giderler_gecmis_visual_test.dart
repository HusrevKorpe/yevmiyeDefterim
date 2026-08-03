/// Giderler — geçmişle beraber ay ay liste (görsel doğrulama).
///
/// GERÇEK uygulamayı çalıştırır; yalnız veri katmanı bellek-içi fake'lerle
/// değiştirilir. Liste tüm geçmişi gösterir; ay değişince "Temmuz 2026 · −₺X"
/// ayracı girer. Gerçek fontla çalıştığı için ayraç satırının taşmadığı da
/// burada görülür.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/app/app.dart';
import 'package:yevmiye_defterim/core/constants/categories.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/auth/application/auth_providers.dart';
import 'package:yevmiye_defterim/features/auth/data/app_user.dart';
import 'package:yevmiye_defterim/features/ledger/application/ledger_providers.dart';
import 'package:yevmiye_defterim/features/ledger/data/ledger_entry.dart';
import 'package:yevmiye_defterim/features/ledger/presentation/widgets/month_header_row.dart';
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
    required String category,
    required int amount,
    required String date,
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

  testWidgets('Giderler → geçmiş aylar tek listede, ay ayraçlarıyla',
      (tester) async {
    await initializeDateFormatting('tr_TR', null);

    // Üç ayrı ay: ayraçların ay değişiminde girdiği görülsün.
    final ledger = FakeLedgerRepository([
      entry(
        id: 'a1',
        category: LedgerCategory.mazot,
        amount: 185000,
        date: '2026-08-01',
        note: 'Traktör',
      ),
      entry(
        id: 't1',
        category: LedgerCategory.genel,
        amount: 62000,
        date: '2026-07-28',
        note: 'İlaç',
      ),
      entry(
        id: 't2',
        category: LedgerCategory.mazot,
        amount: 240000,
        date: '2026-07-14',
      ),
      entry(
        id: 't3',
        category: LedgerCategory.bakkal,
        amount: 45000,
        date: '2026-07-03',
        note: 'Çay şeker',
      ),
      entry(
        id: 'h1',
        category: LedgerCategory.tamir,
        amount: 1250000,
        date: '2026-06-19',
        note: 'Römork kaynak',
      ),
      entry(
        id: 'h2',
        category: LedgerCategory.mazot,
        amount: 500000,
        date: '2026-06-02',
        kind: LedgerKind.tahsilat, // toplamlara girmez, listede yeşil "+"
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

    // Giderler sekmesi.
    await tester.tap(find.text('Giderler').last);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('01-giderler-tum-gecmis');

    // Ay değişiminde ayraç girer (Ağustos / Temmuz / Haziran).
    expect(find.byType(MonthHeaderRow), findsNWidgets(3));
    expect(find.text('Ağustos 2026'), findsOneWidget);
    expect(find.text('Temmuz 2026'), findsOneWidget);
    expect(find.text('Haziran 2026'), findsOneWidget);

    // Listeyi aşağı kaydır → eski aylar.
    await tester.drag(find.byType(ListView).last, const Offset(0, -260));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('02-giderler-eski-aylar');
  });
}

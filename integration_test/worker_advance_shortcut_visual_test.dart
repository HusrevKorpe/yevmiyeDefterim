/// İşçi özet ekranındaki "Avans Ver" kısayolunun görsel doğrulaması —
/// GERÇEK uygulamada işçi aranır, özet sayfasına girilir ve butondan işçi
/// ön-seçili avans ekranı açılır (gerçek fontla taşma kontrolü; `flutter test`
/// gerçek font taşmasını kaçırır).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/app/app.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/auth/application/auth_providers.dart';
import 'package:yevmiye_defterim/features/auth/data/app_user.dart';
import 'package:yevmiye_defterim/features/ledger/application/ledger_providers.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_providers.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../test/support/fake_advance_repository.dart';
import '../test/support/fake_attendance_repository.dart';
import '../test/support/fake_auth_repository.dart';
import '../test/support/fake_ledger_repository.dart';
import '../test/support/fake_settings_repository.dart';
import '../test/support/fake_worker_repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('İşçi özeti — "Avans Ver" kısayolu ön-seçili ekranı açar',
      (tester) async {
    await initializeDateFormatting('tr_TR', null);

    final workers = FakeWorkerRepository();
    Future<void> add(String id, String name,
            {Gender gender = Gender.male, int wage = 120000}) =>
        workers.add(Worker(
          id: id,
          name: name,
          type: WorkerType.gundelik,
          gender: gender,
          dailyWageOverrideKurus: wage,
        ));

    await add('1', 'Ahmet Yılmaz', wage: 150000);
    await add('2', 'Mehmet Kaya');
    await add('3', 'Zeynep Aslan', gender: Gender.female, wage: 110000);

    // Özet kartı boş görünmesin: birkaç yoklama günü + bir açık avans.
    final attendance = FakeAttendanceRepository();
    for (final date in ['2026-07-20', '2026-07-21', '2026-07-22']) {
      await attendance.save(AttendanceRecord.individual(
        id: '2-$date',
        date: date,
        workerId: '2',
        workerName: 'Mehmet Kaya',
        workerType: WorkerType.gundelik,
        status: AttendanceStatus.full,
        wageSnapshotKurus: 120000,
      ));
    }
    final advances = FakeAdvanceRepository([
      const Advance(
        id: 'a1',
        workerId: '2',
        workerName: 'Mehmet Kaya',
        amountKurus: 50000,
        date: '2026-07-21',
        note: 'Market',
      ),
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(const AppUser(uid: 'u1', email: 'demo@ciftlik.tr')),
        ),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        workerRepositoryProvider.overrideWithValue(workers),
        attendanceRepositoryProvider.overrideWithValue(attendance),
        advanceRepositoryProvider.overrideWithValue(advances),
        ledgerRepositoryProvider.overrideWithValue(FakeLedgerRepository()),
      ],
      child: const YevmiyeApp(),
    ));
    await tester.pumpAndSettle();

    // İşçiler → ara → sonuca dokun (kullanıcının gerçek yolu).
    await tester.tap(find.text('İşçiler').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ara'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'mehmet');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mehmet Kaya'));
    await tester.pumpAndSettle();

    // Özet sayfası — kart + "Avans Ver" kısayolu.
    expect(find.text('Avans Ver'), findsOneWidget);
    await binding.takeScreenshot('avans-kisayolu-01-isci-ozeti');

    await tester.tap(find.text('Avans Ver'));
    await tester.pumpAndSettle();

    // Avans ekranı — işçi önden dolu geldi.
    expect(find.text('Mehmet Kaya'), findsWidgets);
    await binding.takeScreenshot('avans-kisayolu-02-onsecili-avans');
  });
}

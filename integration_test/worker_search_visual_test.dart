/// İşçiler ekranı arama görsel doğrulaması — GERÇEK uygulamada "Ara" hapına
/// basılır, yanlış yazılmış bir ad ("mehmed") girilir ve sonucun süzülmüş
/// listede çıktığı ekran görüntüsüyle sabitlenir (gerçek fontla taşma kontrolü;
/// `flutter test` gerçek font taşmasını kaçırır).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/app/app.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
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

  testWidgets('İşçiler — arama hapı, süzülmüş liste ve sonuçsuz görünüm',
      (tester) async {
    await initializeDateFormatting('tr_TR', null);

    final workers = FakeWorkerRepository();
    Future<void> add(
      String id,
      String name, {
      WorkerType type = WorkerType.gundelik,
      Gender gender = Gender.male,
      int wage = 120000,
      bool active = true,
      int? headcount,
    }) =>
        workers.add(Worker(
          id: id,
          name: name,
          type: type,
          gender: gender,
          dailyWageOverrideKurus: wage,
          defaultHeadcount: headcount,
          active: active,
        ));

    await add('1', 'Ahmet Yılmaz', type: WorkerType.sabit, wage: 150000);
    await add('2', 'Mehmet Kaya');
    await add('3', 'Şükrü Demir', wage: 130000);
    await add('4', 'Zeynep Aslan', gender: Gender.female, wage: 110000);
    await add('5', 'Fatma Şahin', gender: Gender.female, wage: 110000);
    await add('6', 'Hasan Ekip',
        type: WorkerType.elebasi, wage: 100000, headcount: 12);
    await add('7', 'Mehmet Ali Öz', active: false);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(const AppUser(uid: 'u1', email: 'demo@ciftlik.tr')),
        ),
        settingsRepositoryProvider
            .overrideWithValue(FakeSettingsRepository()),
        workerRepositoryProvider.overrideWithValue(workers),
        attendanceRepositoryProvider
            .overrideWithValue(FakeAttendanceRepository()),
        advanceRepositoryProvider.overrideWithValue(FakeAdvanceRepository()),
        ledgerRepositoryProvider.overrideWithValue(FakeLedgerRepository()),
      ],
      child: const YevmiyeApp(),
    ));
    await tester.pumpAndSettle();

    // İşçiler sekmesi — arama kapalı hâli (başlıkta "Ara" + "Ekle").
    await tester.tap(find.text('İşçiler').last);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('arama-01-isciler-listesi');

    // "Ara" → kutu açılır.
    await tester.tap(find.text('Ara'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('arama-02-kutu-acik');

    // Yanlış yazım ("mehmed") → yine de bulur.
    await tester.enterText(find.byType(TextField), 'mehmed');
    await tester.pumpAndSettle();
    expect(find.text('Mehmet Kaya'), findsOneWidget);
    await binding.takeScreenshot('arama-03-yanlis-yazim-sonuc');

    // Türkçea harf yazmadan ("sukru").
    await tester.enterText(find.byType(TextField), 'sukru');
    await tester.pumpAndSettle();
    expect(find.text('Şükrü Demir'), findsOneWidget);
    await binding.takeScreenshot('arama-04-turkce-harfsiz');

    // Sonuçsuz görünüm.
    await tester.enterText(find.byType(TextField), 'traktör');
    await tester.pumpAndSettle();
    await binding.takeScreenshot('arama-05-sonuc-yok');

    // "Kapat" → tam liste geri.
    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();
    expect(find.text('Ahmet Yılmaz'), findsOneWidget);
  });
}

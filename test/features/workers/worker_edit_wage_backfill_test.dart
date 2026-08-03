/// Yevmiye SONRADAN girilince ücretsiz (₺0) kaydedilmiş geçmiş günleri
/// fiyatlama akışı (saha hatası 2026-08-03: elebaşı ücretsiz açıldı, sonra
/// fiyat eklendi ama günlerde görünmedi).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/auth/application/user_access.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_providers.dart';
import 'package:yevmiye_defterim/features/settings/data/app_settings.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';
import 'package:yevmiye_defterim/features/workers/presentation/worker_edit_screen.dart';

import '../../support/fake_attendance_repository.dart';
import '../../support/fake_settings_repository.dart';
import '../../support/fake_worker_repository.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('tr_TR', null));

  /// Kişi başı yevmiyesi GİRİLMEMİŞ elebaşı (kayıt ekranında isteğe bağlı alan).
  const boss = Worker(
    id: 'eA',
    name: 'Usta Ali',
    type: WorkerType.elebasi,
    gender: Gender.male,
    defaultHeadcount: 10,
  );

  AttendanceRecord crew(String date, {int headcount = 10, int rate = 0}) =>
      AttendanceRecord.crew(
        id: '${date}_eA',
        date: date,
        workerId: 'eA',
        workerName: 'Usta Ali',
        headcount: headcount,
        crewRateSnapshotKurus: rate,
      );

  late FakeAttendanceRepository attendance;
  late FakeWorkerRepository workers;

  Future<Widget> buildApp(List<AttendanceRecord> records) async {
    attendance = FakeAttendanceRepository();
    for (final r in records) {
      await attendance.save(r);
    }
    workers = FakeWorkerRepository();
    await workers.add(boss);

    return ProviderScope(
      overrides: [
        attendanceRepositoryProvider.overrideWithValue(attendance),
        workerRepositoryProvider.overrideWithValue(workers),
        settingsRepositoryProvider
            .overrideWithValue(FakeSettingsRepository(AppSettings.empty)),
        canSeeMoneyProvider.overrideWithValue(true),
      ],
      child: MaterialApp(
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Ekran ROUTE olarak açılır: kayıt bitince kendini pop eder.
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WorkerEditScreen(worker: boss),
                ),
              ),
              child: const Text('Aç'),
            ),
          ),
        ),
      ),
    );
  }

  /// Ekranı açar, kişi başı yevmiye alanına [amount] yazıp Kaydet'e basar.
  Future<void> enterWage(WidgetTester tester, String amount) async {
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Kişi başı günlük ücret'), amount);
    // Test görüntü alanı (800×600) formun tamamını almaz → düğmeyi görünür kıl.
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();
  }

  testWidgets('onaylanınca ücretsiz geçmiş günler yeni ücretle fiyatlanır',
      (tester) async {
    await tester.pumpWidget(await buildApp([
      crew('2026-07-20'),
      crew('2026-07-21', headcount: 8),
      crew('2026-07-22', rate: 90000), // ücreti girilmiş → dokunulmamalı
    ]));
    await tester.pumpAndSettle();

    await enterWage(tester, '1.000');

    // 2 gün fiyatlanacak → onay sorulur.
    expect(find.textContaining('2 gün'), findsWidgets);
    await tester.tap(find.text('Güncelle'));
    await tester.pumpAndSettle();

    final byId = {for (final r in attendance.all) r.id: r as CrewAttendance};
    expect(byId['2026-07-20_eA']!.crewRateSnapshotKurus, 100000);
    expect(byId['2026-07-20_eA']!.earningKurus, 10 * 100000);
    expect(byId['2026-07-21_eA']!.crewRateSnapshotKurus, 100000);
    expect(byId['2026-07-22_eA']!.crewRateSnapshotKurus, 90000, // korundu
        reason: 'ücreti dondurulmuş gün değişmemeli (kural §4)');
    // İşçinin kendisi de kaydedildi.
    expect(workers.all.single.dailyWageOverrideKurus, 100000);
  });

  testWidgets('vazgeçilirse geçmiş günlere dokunulmaz ama işçi kaydedilir',
      (tester) async {
    await tester.pumpWidget(await buildApp([crew('2026-07-20')]));
    await tester.pumpAndSettle();

    await enterWage(tester, '1.000');
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect((attendance.all.single as CrewAttendance).crewRateSnapshotKurus, 0);
    expect(workers.all.single.dailyWageOverrideKurus, 100000);
  });

  testWidgets('fiyatlanacak gün yoksa onay sorulmaz', (tester) async {
    await tester.pumpWidget(await buildApp([crew('2026-07-20', rate: 90000)]));
    await tester.pumpAndSettle();

    await enterWage(tester, '1.000');

    expect(find.text('Güncelle'), findsNothing);
    expect(workers.all.single.dailyWageOverrideKurus, 100000);
  });
}

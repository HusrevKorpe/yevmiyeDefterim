/// Yevmiye değişince geçmiş günlerin güncellenmesi — işçi düzenleme akışı.
///
/// Müşteri kuralı (2026-08-07): zam "o günden sonrasına" değil, hesabı
/// görülmemiş TÜM günlere işler. Son "Hesap görüldü" tarihi ve öncesi kapanmış
/// sayılır → dokunulmaz. Ayrıca ücretsiz (₺0) kalmış günler her hâlükârda
/// fiyatlanır (saha hatası 2026-08-03: elebaşı ücretsiz açıldı, fiyat sonradan
/// eklenince günlerde görünmedi).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/auth/application/user_access.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_providers.dart';
import 'package:yevmiye_defterim/features/settings/data/app_settings.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';
import 'package:yevmiye_defterim/features/workers/presentation/worker_edit_screen.dart';

import '../../support/fake_advance_repository.dart';
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

  /// [settledDate] verilirse o tarihli "Hesap görüldü" kapanışı olan bir avans.
  Advance advance({String? settledDate}) => Advance(
        id: 'a1',
        workerId: 'eA',
        workerName: 'Usta Ali',
        amountKurus: 50000,
        date: '2026-08-01',
        settledPayrollId: settledDate == null
            ? null
            : Advance.manualSettlementId(settledDate),
      );

  late FakeAttendanceRepository attendance;
  late FakeWorkerRepository workers;

  Future<Widget> buildApp(
    List<AttendanceRecord> records, {
    Worker worker = boss,
    List<Advance> advances = const [],
  }) async {
    attendance = FakeAttendanceRepository();
    for (final r in records) {
      await attendance.save(r);
    }
    workers = FakeWorkerRepository();
    await workers.add(worker);

    return ProviderScope(
      overrides: [
        attendanceRepositoryProvider.overrideWithValue(attendance),
        advanceRepositoryProvider
            .overrideWithValue(FakeAdvanceRepository(advances)),
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
                  builder: (_) => WorkerEditScreen(worker: worker),
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

  testWidgets('hesap hiç görülmediyse zam TÜM geçmişe işler', (tester) async {
    await tester.pumpWidget(await buildApp(
      [
        crew('2026-07-20'), // ücretsiz kalmış gün
        crew('2026-07-21', headcount: 8, rate: 90000),
        crew('2026-07-22', rate: 90000),
      ],
      worker: boss.copyWith(dailyWageOverrideKurus: 90000),
    ));
    await tester.pumpAndSettle();

    await enterWage(tester, '1.000');

    // 3 gün güncellenecek → onay sorulur.
    expect(find.textContaining('3 çalışma günü'), findsWidgets);
    await tester.tap(find.text('Güncelle'));
    await tester.pumpAndSettle();

    final byId = {for (final r in attendance.all) r.id: r as CrewAttendance};
    expect(byId['2026-07-20_eA']!.crewRateSnapshotKurus, 100000);
    expect(byId['2026-07-21_eA']!.crewRateSnapshotKurus, 100000);
    expect(byId['2026-07-22_eA']!.crewRateSnapshotKurus, 100000);
    expect(byId['2026-07-20_eA']!.earningKurus, 10 * 100000);
    // İşçinin kendisi de kaydedildi.
    expect(workers.all.single.dailyWageOverrideKurus, 100000);
  });

  testWidgets('hesap görüldükten SONRAKİ günler zamlanır, öncesi korunur',
      (tester) async {
    await tester.pumpWidget(await buildApp(
      [
        crew('2026-08-01', rate: 90000), // kapanış öncesi
        crew('2026-08-02', rate: 90000), // kapanış GÜNÜ
        crew('2026-08-03', rate: 90000),
        crew('2026-08-17', rate: 90000),
      ],
      worker: boss.copyWith(dailyWageOverrideKurus: 90000),
      advances: [advance(settledDate: '2026-08-02')],
    ));
    await tester.pumpAndSettle();

    await enterWage(tester, '1.200');

    expect(find.textContaining('2 Ağustos 2026'), findsWidgets);
    expect(find.textContaining('2 çalışma günü'), findsWidgets);
    await tester.tap(find.text('Güncelle'));
    await tester.pumpAndSettle();

    final byId = {for (final r in attendance.all) r.id: r as CrewAttendance};
    expect(byId['2026-08-03_eA']!.crewRateSnapshotKurus, 120000);
    expect(byId['2026-08-17_eA']!.crewRateSnapshotKurus, 120000);
    expect(byId['2026-08-01_eA']!.crewRateSnapshotKurus, 90000,
        reason: 'hesabı görülmüş gün değişmemeli');
    expect(byId['2026-08-02_eA']!.crewRateSnapshotKurus, 90000,
        reason: 'kapanış GÜNÜ de denkleşmiştir');
  });

  testWidgets('kapanış öncesinde ücretsiz kalmış gün yine fiyatlanır',
      (tester) async {
    await tester.pumpWidget(await buildApp(
      [
        crew('2026-08-01'), // ₺0 → eksik veri
        crew('2026-08-02', rate: 90000), // kapanış günü, fiyatlı
      ],
      worker: boss.copyWith(dailyWageOverrideKurus: 90000),
      advances: [advance(settledDate: '2026-08-02')],
    ));
    await tester.pumpAndSettle();

    await enterWage(tester, '1.200');
    await tester.tap(find.text('Güncelle'));
    await tester.pumpAndSettle();

    final byId = {for (final r in attendance.all) r.id: r as CrewAttendance};
    expect(byId['2026-08-01_eA']!.crewRateSnapshotKurus, 120000);
    expect(byId['2026-08-02_eA']!.crewRateSnapshotKurus, 90000);
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

  testWidgets('yevmiye değişmediyse onay sorulmaz', (tester) async {
    await tester.pumpWidget(await buildApp(
      [crew('2026-07-20', rate: 100000)],
      worker: boss.copyWith(dailyWageOverrideKurus: 100000),
    ));
    await tester.pumpAndSettle();

    await enterWage(tester, '1.000');

    expect(find.text('Güncelle'), findsNothing);
    expect(workers.all.single.dailyWageOverrideKurus, 100000);
  });
}

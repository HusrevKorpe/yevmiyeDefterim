/// "Hesap Görüldü" akışı — GERÇEK uygulamayı çalıştırır; yalnız veri katmanı
/// bellek-içi seed'li fake'lerle değiştirilir. Görsel doğrulanan akış:
/// Avans listesi (açık avanslar) → avansı düzenle (buton) → onay diyaloğu →
/// kapanış sonrası liste (SnackBar + "Hesabı Görülenler") → grup kartı →
/// listeden "Geri Al" → avanslar yeniden açık. Büyük sistem yazısında (2.0x)
/// kapanış kartının taşmadığı da ayrıca doğrulanır.
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
import 'package:yevmiye_defterim/features/auth/application/auth_providers.dart';
import 'package:yevmiye_defterim/features/auth/data/app_user.dart';
import 'package:yevmiye_defterim/features/ledger/application/ledger_providers.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_providers.dart';
import 'package:yevmiye_defterim/features/settings/data/app_settings.dart';
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

  Advance adv(
    String id, {
    required String workerId,
    required String workerName,
    required int amount,
    required String date,
    String? settled,
    String? note,
  }) =>
      Advance(
        id: id,
        workerId: workerId,
        workerName: workerName,
        amountKurus: amount,
        date: date,
        settledPayrollId: settled,
        note: note,
      );

  /// Seed: Ahmet 2 açık avans (1.000 + 2.500 ₺), Mehmet 1 açık (750 ₺),
  /// Ali daha önce "hesap görüldü" (kapalı), Zeynep eski hakediş mahsubu.
  FakeAdvanceRepository seedAdvances() => FakeAdvanceRepository([
        adv('a1',
            workerId: 'w1',
            workerName: 'Ahmet',
            amount: 100000,
            date: '2026-07-10',
            note: 'Mazot parası'),
        adv('a2',
            workerId: 'w1',
            workerName: 'Ahmet',
            amount: 250000,
            date: '2026-07-15'),
        adv('m1',
            workerId: 'w2',
            workerName: 'Mehmet',
            amount: 75000,
            date: '2026-07-18'),
        adv('k1',
            workerId: 'w4',
            workerName: 'Ali',
            amount: 50000,
            date: '2026-07-05',
            settled: Advance.manualSettlementId('2026-07-20')),
        adv('z1',
            workerId: 'w3',
            workerName: 'Zeynep',
            amount: 30000,
            date: '2026-06-28',
            settled: 'eski-hakedis-uuid'),
      ]);

  Future<void> pumpApp(
    WidgetTester tester,
    FakeAdvanceRepository repo, {
    FakeWorkerRepository? workers,
  }) async {
    await initializeDateFormatting('tr_TR', null);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(const AppUser(uid: 'u1', email: 'demo@ciftlik.tr')),
        ),
        settingsRepositoryProvider
            .overrideWithValue(FakeSettingsRepository(AppSettings.empty)),
        workerRepositoryProvider
            .overrideWithValue(workers ?? FakeWorkerRepository()),
        attendanceRepositoryProvider
            .overrideWithValue(FakeAttendanceRepository()),
        advanceRepositoryProvider.overrideWithValue(repo),
        ledgerRepositoryProvider.overrideWithValue(FakeLedgerRepository([])),
      ],
      child: const YevmiyeApp(),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openAdvancesTab(WidgetTester tester) async {
    await tester.tap(find.text('Avans').last);
    await tester.pumpAndSettle();
  }

  testWidgets('Hesap Görüldü tam akış: buton → onay → kapanış → Geri Al',
      (tester) async {
    final repo = seedAdvances();
    await pumpApp(tester, repo);
    await openAdvancesTab(tester);

    // Açık avanslar: Ahmet (2), Mehmet (1); kapalılar ayrı bölümde.
    expect(find.text('Açık Avanslar'), findsOneWidget);
    expect(find.text('Ahmet'), findsOneWidget);
    expect(find.text('Mehmet'), findsOneWidget);
    expect(find.text('Hesabı Görülenler (1)'), findsOneWidget);
    await binding.takeScreenshot('hesap-goruldu-01-acik-avanslar');

    // Ahmet'in ilk avansına dokun → düzenleme ekranı + buton.
    await tester.tap(find.textContaining('10 Temmuz').first);
    await tester.pumpAndSettle();
    final settleBtn = find.text('Hesap Görüldü (alacağı kalmadı)');
    await tester.ensureVisible(settleBtn);
    await tester.pumpAndSettle();
    expect(settleBtn, findsOneWidget);
    await binding.takeScreenshot('hesap-goruldu-02-duzenle-ekrani');

    // Onay diyaloğu: toplam 3.500 ₺ · 2 kayıt.
    await tester.tap(settleBtn);
    await tester.pumpAndSettle();
    expect(find.textContaining('2 kayıt'), findsOneWidget);
    await binding.takeScreenshot('hesap-goruldu-03-onay-diyalogu');

    // Onayla → listeye dön: SnackBar + Ahmet açıklardan düştü.
    await tester.tap(find.widgetWithText(FilledButton, 'Hesap Görüldü'));
    await tester.pumpAndSettle();
    expect(find.text('Ahmet için hesap görüldü.'), findsOneWidget);
    expect(find.text('Hesabı Görülenler (2)'), findsOneWidget);
    await binding.takeScreenshot('hesap-goruldu-04-kapanis-snackbar');

    // SnackBar'ın sönmesini bekle (listedeki "Geri Al" ile karışmasın).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Kapalılar bölümünü aç: Ahmet kartı "alacak kalmadı", eski mahsup satırı.
    await tester.tap(find.text('Hesabı Görülenler (2)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('alacak kalmadı'), findsNWidgets(2)); // Ahmet+Ali
    expect(find.textContaining('Mahsup edildi'), findsOneWidget); // Zeynep
    await binding.takeScreenshot('hesap-goruldu-05-hesabi-gorulenler');

    // Ahmet kartındaki "Geri Al" → onay → avanslar yeniden açık.
    await tester.tap(find.text('Geri Al').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Geri Al'));
    await tester.pumpAndSettle();
    expect(repo.byId('a1')!.isOpen, isTrue);
    expect(repo.byId('a2')!.isOpen, isTrue);
    expect(find.text('Hesabı Görülenler (1)'), findsOneWidget);
    await binding.takeScreenshot('hesap-goruldu-06-geri-al-sonrasi');

    expect(tester.takeException(), isNull);
  });

  testWidgets('DEVİR akışı: Avans Ver → işçi seç → Hesap Görüldü (açık toplam) '
      '→ devir tutarı → kapanış + devir açık avans olarak listede',
      (tester) async {
    final repo = seedAdvances();
    final workers = FakeWorkerRepository();
    await workers.add(const Worker(
      id: 'w1',
      name: 'Ahmet',
      type: WorkerType.gundelik,
      gender: Gender.male,
      dailyWageOverrideKurus: 100000,
    ));
    await workers.add(const Worker(
      id: 'w2',
      name: 'Mehmet',
      type: WorkerType.gundelik,
      gender: Gender.male,
      dailyWageOverrideKurus: 100000,
    ));
    await pumpApp(tester, repo, workers: workers);
    await openAdvancesTab(tester);

    // Sağ üstteki "Avans Ver" → yeni avans ekranı.
    await tester.tap(find.text('Avans Ver'));
    await tester.pumpAndSettle();

    // İşçi seç: Ahmet → açık toplamı gösteren buton belirir.
    await tester.tap(find.text('İşçi seçin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ahmet').last);
    await tester.pumpAndSettle();
    final settleBtn = find.textContaining('açık)');
    await tester.ensureVisible(settleBtn);
    await tester.pumpAndSettle();
    expect(settleBtn, findsOneWidget);
    await binding.takeScreenshot('hesap-goruldu-08-avans-ver-buton');

    // Diyalog: devreden alacağımız 1.500 ₺.
    await tester.tap(settleBtn);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('devir-amount')), '1500');
    await tester.pumpAndSettle();
    await binding.takeScreenshot('hesap-goruldu-09-devir-diyalogu');

    await tester.tap(find.widgetWithText(FilledButton, 'Hesap Görüldü'));
    await tester.pumpAndSettle();

    // Eski avanslar kapandı; devir yeni açık avans olarak listede.
    expect(find.textContaining('devretti'), findsOneWidget);
    expect(repo.byId('a1')!.isOpen, isFalse);
    expect(repo.byId('a2')!.isOpen, isFalse);
    expect(find.text('Önceki hesaptan devir'), findsOneWidget);
    await binding.takeScreenshot('hesap-goruldu-10-devir-sonrasi-liste');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Büyük sistem yazısında (2.0x) kapanış kartı taşmaz',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(tester, seedAdvances());
    await openAdvancesTab(tester);
    // 2.0x'te başlık ekran altında kalır → önce görünür yap, sonra dokun.
    final header = find.text('Hesabı Görülenler (1)');
    await tester.ensureVisible(header);
    await tester.pumpAndSettle();
    await tester.tap(header);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('alacak kalmadı').first);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('hesap-goruldu-07-kart-scale2');
    expect(tester.takeException(), isNull);
  });
}

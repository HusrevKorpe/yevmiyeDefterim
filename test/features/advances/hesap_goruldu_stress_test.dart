/// "Hesap Görüldü" hırpalama testleri — uç durumlar + tam widget akışı.
///
/// Kapsam: eşzamanlı çift tetik (tek uçuş), boş/hayalet id, bozuk işaret
/// verisi, repo hatası + yeniden dene, Vazgeç/Onay/Geri Al akışları, meşgul
/// kilidi, diğer işçinin/eski mahsubun avansına dokunulmaması, akış dışı
/// açılışta sessiz no-op (bilinen kırılganlık — belgelendi).
library;

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/core/date/app_date.dart';
import 'package:yevmiye_defterim/core/money/money.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_view_model.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';
import 'package:yevmiye_defterim/features/advances/presentation/advance_edit_screen.dart';
import 'package:yevmiye_defterim/features/advances/presentation/advances_screen.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../../support/fake_advance_repository.dart';

/// settle/reopen'ı Completer ile bekletebilen / hata fırlatabilen fake.
class ControlledAdvanceRepository extends FakeAdvanceRepository {
  ControlledAdvanceRepository(super.seed);

  Completer<void>? settleGate;
  Completer<void>? reopenGate;
  bool failSettle = false;
  bool failReopen = false;
  int settleCalls = 0;

  @override
  Future<void> settleAdvances(
    Iterable<String> ids,
    String settledDate, {
    Advance? carryover,
  }) async {
    settleCalls++;
    if (failSettle) throw Exception('yapay hata');
    if (settleGate != null) await settleGate!.future;
    await super.settleAdvances(ids, settledDate, carryover: carryover);
  }

  @override
  Future<void> reopenAdvances(
    Iterable<String> ids, {
    Iterable<String> deleteIds = const [],
  }) async {
    if (failReopen) throw Exception('yapay hata');
    if (reopenGate != null) await reopenGate!.future;
    await super.reopenAdvances(ids, deleteIds: deleteIds);
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  Advance adv(
    String id, {
    String workerId = 'w1',
    String workerName = 'Ahmet',
    int amount = 100000,
    String date = '2026-07-10',
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

  const worker = Worker(
    id: 'w1',
    name: 'Ahmet',
    type: WorkerType.gundelik,
    gender: Gender.male,
    dailyWageOverrideKurus: 100000,
  );

  // ---------------------------------------------------------------- birim ----

  group('Model uç durumları', () {
    test('boş/bozuk tarihli işaret: manuel sayılır, settledDate null düşer',
        () {
      final a = adv('a', settled: 'hesap-goruldu:');
      expect(a.isManuallySettled, isTrue);
      expect(a.settledDate, isNull);
      final b = adv('b', settled: 'hesap-goruldu:bozuk');
      expect(b.isManuallySettled, isTrue);
      expect(b.settledDate, isNull);
      final c = adv('c', settled: Advance.manualSettlementId('2026-07-22'));
      expect(c.settledDate, '2026-07-22');
    });

    test('bozuk tarih gösterimde ÇÖKMEZ — ham değer aynen döner (güvenlik ağı)',
        () {
      expect(formatHumanDateNoWeekday(''), '');
      expect(formatHumanDateNoWeekday('bozuk'), 'bozuk');
      expect(formatHumanDate('bozuk'), 'bozuk');
      expect(formatHumanDate('2026-07-22'), isNot('2026-07-22')); // geçerli
    });

    test('devir ID işareti: carryoverId/isCarryoverOf yalnız kendi kapanış '
        'tarihiyle eşleşir', () {
      final id = Advance.carryoverId('2026-07-23', 'uuid1');
      final c = adv(id);
      expect(c.isCarryoverOf('2026-07-23'), isTrue);
      expect(c.isCarryoverOf('2026-07-22'), isFalse);
      expect(adv('normal-id').isCarryoverOf('2026-07-23'), isFalse);
    });

    test('fromDoc: bozuk tipler güvenli varsayılana düşer (çökmez)', () {
      final a = Advance.fromDoc('x', {
        'workerId': 1,
        'workerName': 7,
        'date': true,
        'settledPayrollId': 42,
        'note': 5,
      });
      expect(a.workerId, '');
      expect(a.workerName, '');
      expect(a.date, '');
      expect(a.settledPayrollId, isNull);
      expect(a.note, isNull);
      expect(a.isOpen, isTrue);
    });
  });

  group('AccountSettlementViewModel uç durumları', () {
    late ControlledAdvanceRepository repo;
    late ProviderContainer container;

    void boot(List<Advance> seed) {
      repo = ControlledAdvanceRepository(seed);
      container = ProviderContainer(overrides: [
        advanceRepositoryProvider.overrideWithValue(repo),
      ]);
    }

    tearDown(() => container.dispose());

    AccountSettlementViewModel vm() =>
        container.read(accountSettlementViewModelProvider.notifier);

    test('boş id listesi: çökmez, hiçbir kayda dokunmaz', () async {
      boot([adv('a1')]);
      final ok = await vm().settle(const [], '2026-07-23');
      expect(ok, isTrue);
      expect(repo.byId('a1')!.isOpen, isTrue);
    });

    test('olmayan id: çökmez, var olanlar kapanır', () async {
      boot([adv('a1')]);
      final ok = await vm().settle(['a1', 'hayalet'], '2026-07-23');
      expect(ok, isTrue);
      expect(repo.byId('a1')!.isOpen, isFalse);
      expect(repo.byId('hayalet'), isNull);
    });

    test('eşzamanlı çift settle: ikincisi reddedilir (tek uçuş)', () async {
      boot([adv('a1')]);
      repo.settleGate = Completer<void>();
      final first = vm().settle(['a1'], '2026-07-23');
      final second = await vm().settle(['a1'], '2026-07-23');
      expect(second, isFalse, reason: 'meşgulken ikinci çağrı reddedilmeli');
      repo.settleGate!.complete();
      expect(await first, isTrue);
      expect(repo.settleCalls, 1);
    });

    test('settle sürerken reopen da reddedilir (aynı meşgul bayrağı)', () async {
      boot([adv('a1')]);
      repo.settleGate = Completer<void>();
      final first = vm().settle(['a1'], '2026-07-23');
      expect(await vm().reopen(['a1']), isFalse);
      repo.settleGate!.complete();
      await first;
      expect(repo.byId('a1')!.isOpen, isFalse);
    });

    test('repo hatası: false döner, meşgul bayrağı temizlenir', () async {
      boot([adv('a1')]);
      repo.failSettle = true;
      expect(await vm().settle(['a1'], '2026-07-23'), isFalse);
      expect(container.read(accountSettlementViewModelProvider), isFalse);
      // Hata sonrası tekrar denenebilir olmalı:
      repo.failSettle = false;
      expect(await vm().settle(['a1'], '2026-07-23'), isTrue);
    });

    test('zaten kapalı avansı settle: tarih üzerine yazılır (belgelenen)',
        () async {
      boot([adv('a1', settled: Advance.manualSettlementId('2026-07-01'))]);
      await vm().settle(['a1'], '2026-07-23');
      expect(repo.byId('a1')!.settledDate, '2026-07-23');
    });

    test('yalnız verilen id\'ler kapanır — diğer işçiye dokunulmaz', () async {
      boot([adv('a1'), adv('b1', workerId: 'w2', workerName: 'Mehmet')]);
      await vm().settle(['a1'], '2026-07-23');
      expect(repo.byId('a1')!.isOpen, isFalse);
      expect(repo.byId('b1')!.isOpen, isTrue);
    });

    test('eski hakediş (UUID) kaydı reopen edilirse de açılır (repo seviyesi)',
        () async {
      boot([adv('a1', settled: 'uuid-1234')]);
      await vm().reopen(['a1']);
      expect(repo.byId('a1')!.isOpen, isTrue);
    });

    test('DEVİR: carryover ile settle kapanış + yeni açık devir kaydını '
        'birlikte yazar; reopen deleteIds ile devri siler', () async {
      boot([adv('a1')]);
      final c = Advance(
        id: Advance.carryoverId('2026-07-23', 'u1'),
        workerId: 'w1',
        workerName: 'Ahmet',
        amountKurus: 50000,
        date: '2026-07-23',
        note: 'Önceki hesaptan devir',
      );
      expect(await vm().settle(['a1'], '2026-07-23', carryover: c), isTrue);
      expect(repo.byId('a1')!.isOpen, isFalse);
      expect(repo.byId(c.id)!.isOpen, isTrue, reason: 'devir açık kalmalı');
      expect(repo.byId(c.id)!.amountKurus, 50000);

      expect(await vm().reopen(['a1'], deleteIds: [c.id]), isTrue);
      expect(repo.byId('a1')!.isOpen, isTrue);
      expect(repo.byId(c.id), isNull, reason: 'geri almada devir silinmeli');
    });

    test('OFFLINE: yazma onayı hiç gelmezse ~5 sn sonra başarı sayılır, '
        'meşgul bayrağı çözülür (UI süresiz kilitlenmez)', () {
      fakeAsync((async) {
        boot([adv('a1')]);
        repo.settleGate = Completer<void>(); // onay asla gelmiyor (offline)
        bool? result;
        vm().settle(['a1'], '2026-07-23').then((v) => result = v);
        async.elapse(const Duration(seconds: 4));
        expect(result, isNull, reason: 'zaman aşımından önce beklemede');
        async.elapse(const Duration(seconds: 2));
        expect(result, isTrue, reason: 'kuyruğa alındı sayılmalı');
        expect(container.read(accountSettlementViewModelProvider), isFalse,
            reason: 'meşgul bayrağı temizlenmeli');
      });
    });

    test('OFFLINE: reopen (Geri Al) da aynı zaman aşımıyla çözülür', () {
      fakeAsync((async) {
        boot([adv('a1', settled: Advance.manualSettlementId('2026-07-22'))]);
        repo.reopenGate = Completer<void>();
        bool? result;
        vm().reopen(['a1']).then((v) => result = v);
        async.elapse(const Duration(seconds: 6));
        expect(result, isTrue);
        expect(container.read(accountSettlementViewModelProvider), isFalse);
      });
    });
  });

  // --------------------------------------------------------------- widget ----

  /// Gerçek akışı taklit eden kurulum: altta avans listesini izleyen bir ekran,
  /// üstüne push edilen düzenleme ekranı (uygulamada da böyle açılıyor).
  Widget buildApp(ControlledAdvanceRepository repo) {
    return ProviderScope(
      overrides: [
        advanceRepositoryProvider.overrideWithValue(repo),
        workersStreamProvider.overrideWith((ref) => Stream.value([worker])),
      ],
      child: const MaterialApp(
        locale: Locale('tr', 'TR'),
        supportedLocales: [Locale('tr', 'TR')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: _Launcher(),
      ),
    );
  }

  Future<void> openEdit(WidgetTester tester, String advanceId) async {
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('edit-$advanceId')));
    await tester.pumpAndSettle();
  }

  Finder settleButton() => find.text('Hesap Görüldü (alacağı kalmadı)');

  /// Butonu görünür yapıp dokunur (test viewport'u 800x600 — buton kaydırmada).
  Future<void> tapSettleButton(WidgetTester tester) async {
    await tester.ensureVisible(settleButton());
    await tester.pumpAndSettle();
    await tester.tap(settleButton());
    await tester.pumpAndSettle();
  }

  testWidgets('buton yalnız AÇIK avans düzenlemede görünür', (tester) async {
    final repo = ControlledAdvanceRepository([
      adv('a1'),
      adv('a2', settled: Advance.manualSettlementId('2026-07-01')),
    ]);
    await tester.pumpWidget(buildApp(repo));

    await openEdit(tester, 'a1');
    expect(settleButton(), findsOneWidget);
    Navigator.of(tester.element(find.byType(AdvanceEditScreen))).pop();
    await tester.pumpAndSettle();

    await openEdit(tester, 'a2'); // kapalı avans
    expect(settleButton(), findsNothing);
    expect(find.text('Avansı Sil'), findsNothing);
  });

  testWidgets('Avans Ver: seçili işçinin açık avansı varsa buton açık '
      'toplamla görünür; onaylayınca TÜM açık avanslar kapanır', (tester) async {
    final repo = ControlledAdvanceRepository([
      adv('a1', amount: 100000),
      adv('a2', amount: 250000, date: '2026-07-15'),
      adv('b1', workerId: 'w2', workerName: 'Mehmet'),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new-advance')));
    await tester.pumpAndSettle();

    // Buton yalnız Ahmet'in açık toplamını gösterir (1.000 + 2.500 TL).
    final btn = find.text('Hesap Görüldü (${formatKurus(350000)} açık)');
    expect(btn, findsOneWidget);

    await tester.ensureVisible(btn);
    await tester.pumpAndSettle();
    await tester.tap(btn);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Hesap Görüldü'));
    await tester.pumpAndSettle();

    expect(repo.byId('a1')!.settledDate, todayIso());
    expect(repo.byId('a2')!.settledDate, todayIso());
    expect(repo.byId('b1')!.isOpen, isTrue, reason: 'diğer işçiye dokunulmaz');
    expect(find.byType(AdvanceEditScreen), findsNothing,
        reason: 'başarıda ekran kapanmalı');
    expect(find.text('Ahmet için hesap görüldü.'), findsOneWidget);
  });

  testWidgets('Avans Ver: açık avansı olmayan işçide buton görünmez',
      (tester) async {
    final repo = ControlledAdvanceRepository([
      adv('a1', settled: Advance.manualSettlementId('2026-07-01')),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new-advance')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hesap Görüldü'), findsNothing);
  });

  testWidgets('onay diyaloğu toplamı ve kayıt sayısını doğru gösterir; '
      'Vazgeç hiçbir şeyi değiştirmez', (tester) async {
    final repo = ControlledAdvanceRepository([
      adv('a1', amount: 100000),
      adv('a2', amount: 250000, date: '2026-07-15'),
      adv('b1', workerId: 'w2', workerName: 'Mehmet', amount: 999999),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await openEdit(tester, 'a1');

    await tapSettleButton(tester);

    // Toplam yalnız Ahmet'in 2 açık avansı: 1.000 + 2.500 TL.
    final expectedTotal = formatKurus(350000);
    expect(
      find.textContaining(expectedTotal, findRichText: true),
      findsWidgets,
    );
    expect(find.textContaining('2 kayıt'), findsOneWidget);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(repo.byId('a1')!.isOpen, isTrue);
    expect(repo.byId('a2')!.isOpen, isTrue);
    expect(find.byType(AdvanceEditScreen), findsOneWidget,
        reason: 'Vazgeç sonrası ekran açık kalmalı');
  });

  testWidgets('onaylanınca işçinin TÜM açık avansları bugünle kapanır, '
      'diğer işçininki kalır; ekran kapanır, SnackBar + Geri Al çalışır',
      (tester) async {
    final repo = ControlledAdvanceRepository([
      adv('a1', amount: 100000),
      adv('a2', amount: 250000, date: '2026-07-15'),
      adv('a3', settled: 'eski-uuid'), // eski mahsup — DOKUNULMAMALI
      adv('b1', workerId: 'w2', workerName: 'Mehmet'),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await openEdit(tester, 'a1');

    await tapSettleButton(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Hesap Görüldü'));
    await tester.pumpAndSettle();

    expect(repo.byId('a1')!.settledDate, todayIso());
    expect(repo.byId('a2')!.settledDate, todayIso());
    expect(repo.byId('a3')!.settledPayrollId, 'eski-uuid');
    expect(repo.byId('b1')!.isOpen, isTrue);
    expect(find.byType(AdvanceEditScreen), findsNothing,
        reason: 'başarıda ekran kapanmalı');
    expect(find.text('Ahmet için hesap görüldü.'), findsOneWidget);

    // Geri Al → hepsi yeniden açılır.
    await tester.tap(find.text('Geri Al'));
    await tester.pumpAndSettle();
    expect(repo.byId('a1')!.isOpen, isTrue);
    expect(repo.byId('a2')!.isOpen, isTrue);
  });

  testWidgets('DEVİR: diyalogda tutar girilirse kapanışla birlikte yeni açık '
      'devir avansı oluşur; SnackBar "devretti" der; Geri Al devri de siler',
      (tester) async {
    final repo = ControlledAdvanceRepository([
      adv('a1', amount: 100000),
      adv('a2', amount: 250000, date: '2026-07-15'),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await openEdit(tester, 'a1');
    await tapSettleButton(tester);

    // Devreden alacağımız: 1.500 TL.
    await tester.enterText(find.byKey(const Key('devir-amount')), '1500');
    await tester.tap(find.widgetWithText(FilledButton, 'Hesap Görüldü'));
    await tester.pumpAndSettle();

    expect(repo.byId('a1')!.isOpen, isFalse);
    expect(repo.byId('a2')!.isOpen, isFalse);
    final carryovers =
        repo.all.where((x) => x.isCarryoverOf(todayIso())).toList();
    expect(carryovers, hasLength(1));
    final c = carryovers.single;
    expect(c.isOpen, isTrue, reason: 'devir yeni AÇIK avans olmalı');
    expect(c.amountKurus, 150000);
    expect(c.workerId, 'w1');
    expect(c.date, todayIso());
    expect(c.note, 'Önceki hesaptan devir');
    expect(find.textContaining('devretti'), findsOneWidget);

    // Geri Al → eski avanslar açılır, devir kaydı silinir (çifte sayım yok).
    await tester.tap(find.text('Geri Al'));
    await tester.pumpAndSettle();
    expect(repo.byId('a1')!.isOpen, isTrue);
    expect(repo.byId('a2')!.isOpen, isTrue);
    expect(repo.all.where((x) => x.isCarryoverOf(todayIso())), isEmpty);
  });

  testWidgets('DEVİR: geçersiz tutar diyaloğu KAPATMAZ, hata gösterir; '
      'düzeltilince devirli kapanır', (tester) async {
    final repo = ControlledAdvanceRepository([adv('a1')]);
    await tester.pumpWidget(buildApp(repo));
    await openEdit(tester, 'a1');
    await tapSettleButton(tester);

    await tester.enterText(find.byKey(const Key('devir-amount')), 'abc');
    await tester.tap(find.widgetWithText(FilledButton, 'Hesap Görüldü'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget,
        reason: 'geçersiz tutarda diyalog açık kalmalı');
    expect(find.text('Geçerli tutar girin (örn. 2.000).'), findsOneWidget);
    expect(repo.byId('a1')!.isOpen, isTrue, reason: 'hiçbir şey kapanmamalı');

    await tester.enterText(find.byKey(const Key('devir-amount')), '500');
    await tester.tap(find.widgetWithText(FilledButton, 'Hesap Görüldü'));
    await tester.pumpAndSettle();
    expect(repo.byId('a1')!.isOpen, isFalse);
    expect(repo.all.where((x) => x.isCarryoverOf(todayIso())), hasLength(1));
  });

  testWidgets('tek avansta "· N kayıt" eki görünmez', (tester) async {
    final repo = ControlledAdvanceRepository([adv('a1')]);
    await tester.pumpWidget(buildApp(repo));
    await openEdit(tester, 'a1');
    await tapSettleButton(tester);
    expect(find.textContaining('kayıt'), findsNothing);
  });

  testWidgets('repo hatasında ekran KAPANMAZ, hata SnackBar\'ı çıkar, '
      'avanslar açık kalır', (tester) async {
    final repo = ControlledAdvanceRepository([adv('a1')]);
    repo.failSettle = true;
    await tester.pumpWidget(buildApp(repo));
    await openEdit(tester, 'a1');

    await tapSettleButton(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Hesap Görüldü'));
    await tester.pumpAndSettle();

    expect(repo.byId('a1')!.isOpen, isTrue);
    expect(find.byType(AdvanceEditScreen), findsOneWidget);
    expect(
      find.text('İşaretlenemedi. İnternet bağlantınızı kontrol edin.'),
      findsOneWidget,
    );
  });

  testWidgets('işlem sürerken Kaydet/Sil/Hesap Görüldü kilitlenir',
      (tester) async {
    final repo = ControlledAdvanceRepository([adv('a1')]);
    repo.settleGate = Completer<void>();
    await tester.pumpWidget(buildApp(repo));
    await openEdit(tester, 'a1');

    await tapSettleButton(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Hesap Görüldü'));
    await tester.pump(); // settle askıda — meşgul durumu

    OutlinedButton settleBtn() => tester.widget<OutlinedButton>(
        find.ancestor(of: settleButton(), matching: find.byType(OutlinedButton)));
    expect(settleBtn().onPressed, isNull, reason: 'meşgulken kilitli olmalı');

    repo.settleGate!.complete();
    await tester.pumpAndSettle();
    expect(repo.byId('a1')!.isOpen, isFalse);
  });

  testWidgets('AdvancesScreen: Hesabı Görülenler grubu + Geri Al onaylı akış; '
      'eski mahsup satırında Geri Al yok', (tester) async {
    final repo = ControlledAdvanceRepository([
      adv('a1', settled: Advance.manualSettlementId('2026-07-20')),
      adv('a2',
          date: '2026-07-12',
          settled: Advance.manualSettlementId('2026-07-20')),
      adv('c1',
          workerId: 'w3', workerName: 'Zeynep', settled: 'eski-payroll-uuid'),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        advanceRepositoryProvider.overrideWithValue(repo),
        workersStreamProvider.overrideWith((ref) => Stream.value([worker])),
      ],
      child: const MaterialApp(
        locale: Locale('tr', 'TR'),
        supportedLocales: [Locale('tr', 'TR')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: AdvancesScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    // Grup sayısı 1 (Ahmet w1|2026-07-20) — eski mahsup gruba sayılmıyor.
    expect(find.text('Hesabı Görülenler (1)'), findsOneWidget);
    await tester.tap(find.text('Hesabı Görülenler (1)'));
    await tester.pumpAndSettle();

    expect(find.textContaining('alacak kalmadı'), findsOneWidget);
    expect(find.textContaining('Mahsup edildi'), findsOneWidget); // eski satır
    expect(find.text('Geri Al'), findsOneWidget,
        reason: 'yalnız manuel grup için Geri Al olmalı');

    await tester.tap(find.text('Geri Al'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Geri Al')); // onay
    await tester.pumpAndSettle();

    expect(repo.byId('a1')!.isOpen, isTrue);
    expect(repo.byId('a2')!.isOpen, isTrue);
    expect(repo.byId('c1')!.isOpen, isFalse, reason: 'eskiye dokunulmamalı');
    expect(find.text('Açık Avanslar'), findsOneWidget);
  });

  testWidgets('AdvancesScreen Geri Al: kapanışın devir kaydını da siler '
      '(onay metni belirtir); başka kapanışın devrine dokunmaz', (tester) async {
    const settledDate = '2026-07-20';
    final repo = ControlledAdvanceRepository([
      adv('a1', settled: Advance.manualSettlementId(settledDate)),
      // Bu kapanışın devri (açık) — geri almada silinmeli.
      adv(Advance.carryoverId(settledDate, 'u1'),
          amount: 50000, date: settledDate, note: 'Önceki hesaptan devir'),
      // Başka tarihli kapanışın devri — DOKUNULMAMALI.
      adv(Advance.carryoverId('2026-07-10', 'u2'),
          amount: 30000, date: '2026-07-10'),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        advanceRepositoryProvider.overrideWithValue(repo),
        workersStreamProvider.overrideWith((ref) => Stream.value([worker])),
      ],
      child: const MaterialApp(
        locale: Locale('tr', 'TR'),
        supportedLocales: [Locale('tr', 'TR')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: AdvancesScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hesabı Görülenler (1)'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Geri Al'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Geri Al'));
    await tester.pumpAndSettle();

    expect(find.textContaining('devir kaydı da silinecek'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Geri Al')); // onay
    await tester.pumpAndSettle();

    expect(repo.byId('a1')!.isOpen, isTrue);
    expect(repo.byId(Advance.carryoverId(settledDate, 'u1')), isNull,
        reason: 'bu kapanışın devri silinmeli');
    expect(repo.byId(Advance.carryoverId('2026-07-10', 'u2')), isNotNull,
        reason: 'başka kapanışın devrine dokunulmamalı');
  });

  testWidgets(
      'akış dışı açılış (stream verisi henüz yok): buton sessiz KALMAZ, '
      'en azından eldeki avansı kapatır', (tester) async {
    final repo = ControlledAdvanceRepository([adv('a1')]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        advanceRepositoryProvider.overrideWithValue(repo),
        workersStreamProvider.overrideWith((ref) => Stream.value([worker])),
      ],
      child: MaterialApp(
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Listeyi izleyen ekran YOK — avans akışı hiç dinlenmemiş durumda.
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AdvanceEditScreen(advance: adv('a1')),
                  ),
                ),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('aç'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // rota animasyonu

    await tester.ensureVisible(settleButton());
    await tester.pump();
    await tester.tap(settleButton());
    await tester.pump();

    expect(find.byType(AlertDialog), findsOneWidget,
        reason: 'veri yokken de diyalog açılmalı (eldeki avansla)');
    await tester.tap(find.widgetWithText(FilledButton, 'Hesap Görüldü'));
    await tester.pumpAndSettle();
    expect(repo.byId('a1')!.isOpen, isFalse);
    expect(find.text('Ahmet için hesap görüldü.'), findsOneWidget);
  });

  testWidgets('OFFLINE: yazma onayı gelmese de ekran ~5 sn içinde kapanır, '
      'Geri Al SnackBar\'ı gelir (süresiz kilit YOK)', (tester) async {
    final repo = ControlledAdvanceRepository([adv('a1')]);
    repo.settleGate = Completer<void>(); // sunucu onayı hiç gelmeyecek
    await tester.pumpWidget(buildApp(repo));
    await openEdit(tester, 'a1');

    await tapSettleButton(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Hesap Görüldü'));
    await tester.pumpAndSettle();
    expect(find.byType(AdvanceEditScreen), findsOneWidget,
        reason: 'zaman aşımından önce hâlâ beklemede');

    await tester.pump(const Duration(seconds: 6)); // kWriteAckTimeout dolar
    await tester.pumpAndSettle();
    expect(find.byType(AdvanceEditScreen), findsNothing,
        reason: 'kuyruğa alındı sayılıp ekran kapanmalı');
    expect(find.text('Ahmet için hesap görüldü.'), findsOneWidget);
  });

  testWidgets('bozuk kapanış tarihi/bozuk gün listede ÇÖKMEZ — tarihsiz '
      '"Hesap görüldü" kartı çizilir', (tester) async {
    final repo = ControlledAdvanceRepository([
      adv('a1', settled: 'hesap-goruldu:bozuk-tarih'),
      adv('a2', date: 'bozuk', settled: 'hesap-goruldu:bozuk-tarih'),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        advanceRepositoryProvider.overrideWithValue(repo),
        workersStreamProvider.overrideWith((ref) => Stream.value([worker])),
      ],
      child: const MaterialApp(
        locale: Locale('tr', 'TR'),
        supportedLocales: [Locale('tr', 'TR')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: AdvancesScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hesabı Görülenler (1)'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Hesap görüldü · alacak kalmadı'), findsOneWidget,
        reason: 'bozuk tarih → tarihsiz kapanış metni');
    expect(find.text('bozuk'), findsOneWidget,
        reason: 'bozuk gün ham değerle gösterilir, çökmez');
  });
}

/// Alt ekran: gerçek uygulamadaki AdvancesScreen gibi avans stream'ini izler ve
/// düzenleme ekranını üstüne push eder (SnackBar/pop davranışı gerçekçi olsun).
class _Launcher extends ConsumerWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advances =
        ref.watch(advancesStreamProvider).asData?.value ?? const <Advance>[];
    return Scaffold(
      body: ListView(
        children: [
          // Yeni "Avans Ver" ekranı — işçi ön-seçili (yeni-mod buton testleri).
          TextButton(
            key: const Key('new-advance'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AdvanceEditScreen(initialWorkerId: 'w1'),
              ),
            ),
            child: const Text('yeni'),
          ),
          for (final a in advances)
            TextButton(
              key: Key('edit-${a.id}'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AdvanceEditScreen(advance: a),
                ),
              ),
              child: Text('aç ${a.id}'),
            ),
        ],
      ),
    );
  }
}

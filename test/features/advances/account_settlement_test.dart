import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_view_model.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';

import '../../support/fake_advance_repository.dart';

void main() {
  Advance adv(String id, {String? workerId = 'w1', String? settled}) => Advance(
        id: id,
        workerId: workerId!,
        workerName: 'Ahmet',
        amountKurus: 100000,
        date: '2026-07-10',
        settledPayrollId: settled,
      );

  group('Advance "hesap görüldü" işaretleri', () {
    test('manuel işaret tanınır ve kapanış tarihi çözülür', () {
      final a = adv('a', settled: Advance.manualSettlementId('2026-07-22'));
      expect(a.isOpen, isFalse);
      expect(a.isManuallySettled, isTrue);
      expect(a.settledDate, '2026-07-22');
    });

    test('hakediş UUID işareti manuel sayılmaz (önek çakışmaz)', () {
      final a = adv('a', settled: 'b1f3-8ac2-uuid');
      expect(a.isOpen, isFalse);
      expect(a.isManuallySettled, isFalse);
      expect(a.settledDate, isNull);
    });

    test('açık avansın işareti yok', () {
      final a = adv('a');
      expect(a.isOpen, isTrue);
      expect(a.isManuallySettled, isFalse);
      expect(a.settledDate, isNull);
    });
  });

  group('AccountSettlementViewModel', () {
    late FakeAdvanceRepository repo;
    late ProviderContainer container;

    void boot(List<Advance> seed) {
      repo = FakeAdvanceRepository(seed);
      container = ProviderContainer(overrides: [
        advanceRepositoryProvider.overrideWithValue(repo),
      ]);
    }

    tearDown(() => container.dispose());

    AccountSettlementViewModel vm() =>
        container.read(accountSettlementViewModelProvider.notifier);

    test('settle: açık avansları kapatır + tarih işaretler', () async {
      boot([adv('a1'), adv('a2')]);
      final ok = await vm().settle(['a1', 'a2'], '2026-07-22');
      expect(ok, isTrue);
      expect(repo.byId('a1')!.isOpen, isFalse);
      expect(repo.byId('a1')!.isManuallySettled, isTrue);
      expect(repo.byId('a1')!.settledDate, '2026-07-22');
      expect(repo.byId('a2')!.isOpen, isFalse);
    });

    test('reopen: kapatılanı yeniden açar', () async {
      boot([adv('a1', settled: Advance.manualSettlementId('2026-07-22'))]);
      expect(repo.byId('a1')!.isOpen, isFalse);
      final ok = await vm().reopen(['a1']);
      expect(ok, isTrue);
      expect(repo.byId('a1')!.isOpen, isTrue);
      expect(repo.byId('a1')!.isManuallySettled, isFalse);
      expect(repo.byId('a1')!.settledDate, isNull);
    });

    test('settle → reopen tam tur: baştaki açık duruma döner', () async {
      boot([adv('a1'), adv('a2')]);
      await vm().settle(['a1', 'a2'], '2026-07-22');
      await vm().reopen(['a1', 'a2']);
      expect(repo.byId('a1')!.isOpen, isTrue);
      expect(repo.byId('a2')!.isOpen, isTrue);
    });

    Advance carry(int kurus) => Advance(
          id: 'devir-2026-07-22-x',
          workerId: 'w1',
          workerName: 'Ahmet',
          amountKurus: kurus,
          date: '2026-07-22',
        );

    // Gerçek Firestore düzeltmesinin (advance_repository.dart) sözleşme karşılığı:
    // kapanış işaretleri `set(merge:true)` ile yazılır, `update` ile DEĞİL →
    // hedeflerden biri commit anında yoksa batch REDDEDİLMEZ. `update` olsaydı
    // tüm batch düşer, DEVİR (yeni gerçek borç) sessizce kaybolurdu. Fake bu
    // toleranslı sözleşmeyi modeller (olmayan id atlanır); test onu sabitler.
    test('settle: bir kaynak avans EŞZAMANLI SİLİNMİŞSE devir yine yazılır ve '
        'kalanlar kapanır (batch reddi → devir kaybı yok)', () async {
      boot([adv('a1')]); // a2 kasıtlı YOK: başka cihaz bu arada sildi.
      final ok = await vm().settle(
        ['a1', 'a2'],
        '2026-07-22',
        carryover: carry(60000),
      );
      expect(ok, isTrue);
      expect(repo.byId('a1')!.isOpen, isFalse, reason: 'var olan kapanır');
      expect(repo.byId('a2'), isNull, reason: 'olmayan id atlanır (hayalet yok)');
      final c = repo.byId('devir-2026-07-22-x');
      expect(c, isNotNull, reason: 'DEVİR asla kaybolmaz');
      expect(c!.amountKurus, 60000);
      expect(c.isOpen, isTrue);
    });

    test('reopen: bir avans EŞZAMANLI SİLİNMİŞSE devir kayıtları yine silinir '
        '(batch reddi → geri-al yarım kalmaz)', () async {
      boot([adv('a1', settled: Advance.manualSettlementId('2026-07-22'))]);
      await repo.add(carry(60000)); // kapanışta oluşan devir kaydı.
      final ok = await vm().reopen(
        ['a1', 'a2'], // a2 YOK: eşzamanlı silinmiş.
        deleteIds: ['devir-2026-07-22-x'],
      );
      expect(ok, isTrue);
      expect(repo.byId('a1')!.isOpen, isTrue, reason: 'var olan yeniden açılır');
      expect(repo.byId('devir-2026-07-22-x'), isNull,
          reason: 'devir kaydı silinir (batch reddedilmedi)');
    });
  });
}

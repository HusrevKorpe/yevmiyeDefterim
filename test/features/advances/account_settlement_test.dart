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
  });
}

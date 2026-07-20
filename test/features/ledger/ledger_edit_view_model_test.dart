import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/core/constants/categories.dart';
import 'package:yevmiye_defterim/features/ledger/application/ledger_edit_view_model.dart';
import 'package:yevmiye_defterim/features/ledger/application/ledger_providers.dart';
import 'package:yevmiye_defterim/features/ledger/data/ledger_entry.dart';

import '../../support/fake_ledger_repository.dart';

void main() {
  LedgerEntry manual({String id = 'l1', LedgerType type = LedgerType.expense}) =>
      LedgerEntry(
        id: id,
        type: type,
        category: LedgerCategory.mazot,
        amountKurus: 120000,
        date: '2026-07-10',
        source: LedgerSource.manual,
      );

  LedgerEntry auto({String id = 'p1'}) => LedgerEntry(
        id: id,
        type: LedgerType.expense,
        category: LedgerCategory.maas,
        amountKurus: 400000,
        date: '2026-07-10',
        source: LedgerSource.payroll,
        payrollId: 'pay1',
        workerId: 'w1',
        workerName: 'Ahmet',
      );

  late FakeLedgerRepository repo;
  late ProviderContainer container;

  void boot([List<LedgerEntry> seed = const []]) {
    repo = FakeLedgerRepository(seed);
    container = ProviderContainer(overrides: [
      ledgerRepositoryProvider.overrideWithValue(repo),
    ]);
  }

  LedgerEditViewModel vm() =>
      container.read(ledgerEditViewModelProvider.notifier);

  tearDown(() => container.dispose());

  test('elle kayıt ekleme deposu yazar, done olur', () async {
    boot();
    await vm().submit(entry: manual(), isNew: true);
    expect(repo.count, 1);
    expect(container.read(ledgerEditViewModelProvider).done, isTrue);
  });

  test('güncelleme var olanı değiştirir', () async {
    boot([manual()]);
    await vm().submit(
      entry: manual().copyWith(amountKurus: 150000),
      isNew: false,
    );
    expect(repo.count, 1);
    expect(repo.byId('l1')!.amountKurus, 150000);
  });

  test('elle kayıt silinir', () async {
    boot([manual()]);
    await vm().delete(manual());
    expect(repo.count, 0);
    expect(container.read(ledgerEditViewModelProvider).done, isTrue);
  });

  test('otomatik kayıt silinemez → hata, kayıt durur', () async {
    boot([auto()]);
    await vm().delete(auto());
    expect(repo.count, 1); // silinmedi
    expect(container.read(ledgerEditViewModelProvider).error, isNotNull);
  });

  test('otomatik kayıt güncellenemez → hata, yazma yok', () async {
    boot([auto()]);
    await vm().submit(entry: auto().copyWith(amountKurus: 999999), isNew: false);
    expect(repo.byId('p1')!.amountKurus, 400000); // değişmedi
    expect(container.read(ledgerEditViewModelProvider).error, isNotNull);
  });
}

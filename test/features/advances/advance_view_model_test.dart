import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_view_model.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';

import '../../support/fake_advance_repository.dart';

void main() {
  Advance make({String id = 'a1', String? settled}) => Advance(
        id: id,
        workerId: 'w1',
        workerName: 'Ahmet',
        amountKurus: 150000,
        date: '2026-07-10',
        settledPayrollId: settled,
      );

  late FakeAdvanceRepository repo;
  late ProviderContainer container;

  void boot([List<Advance> seed = const []]) {
    repo = FakeAdvanceRepository(seed);
    container = ProviderContainer(overrides: [
      advanceRepositoryProvider.overrideWithValue(repo),
    ]);
  }

  AdvanceEditViewModel vm() =>
      container.read(advanceEditViewModelProvider.notifier);

  tearDown(() => container.dispose());

  test('ekleme deposu yazar, done olur', () async {
    boot();
    await vm().submit(advance: make(), isNew: true);
    expect(repo.count, 1);
    expect(container.read(advanceEditViewModelProvider).done, isTrue);
  });

  test('güncelleme var olanı değiştirir', () async {
    boot([make()]);
    await vm().submit(
      advance: make().copyWith(amountKurus: 200000),
      isNew: false,
    );
    expect(repo.count, 1);
    expect(repo.byId('a1')!.amountKurus, 200000);
  });

  test(
      'eşzamanlılık: düzenleme, başka cihazın "Hesap Görüldü" kapanışını GERİ AÇMAZ',
      () async {
    // A cihazı avansı açıkken açtı (elindeki kopyada settled=null).
    boot([make()]);
    // B cihazı bu arada hesabı gördü → depoda kapanış işareti var.
    await repo.settleAdvances(['a1'], '2026-07-20', uid: 'evt1');
    expect(repo.byId('a1')!.isOpen, isFalse);

    // A cihazı tutarı değiştirip Kaydet'e bastı (hâlâ settled=null kopya gönderir).
    await vm().submit(
      advance: make().copyWith(amountKurus: 200000),
      isNew: false,
    );

    // Tutar güncellendi AMA kapanış korundu (avans yeniden açılmadı).
    expect(repo.byId('a1')!.amountKurus, 200000);
    expect(repo.byId('a1')!.isOpen, isFalse,
        reason: 'düzenleme settledPayrollId\'yi ezmemeli');
  });

  test('açık avans silinir', () async {
    boot([make()]);
    await vm().delete(make());
    expect(repo.count, 0);
    expect(container.read(advanceEditViewModelProvider).done, isTrue);
  });

  test('kapanmış avans silinemez → hata, kayıt durur', () async {
    boot([make(settled: 'p1')]);
    await vm().delete(make(settled: 'p1'));
    expect(repo.count, 1); // silinmedi
    expect(container.read(advanceEditViewModelProvider).error, isNotNull);
  });
}

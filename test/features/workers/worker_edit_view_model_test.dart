import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/workers/application/worker_edit_view_model.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';
import 'package:yevmiye_defterim/features/workers/data/worker_repository.dart';

import '../../support/fake_worker_repository.dart';

/// Yazmayı sunucu onayına (Completer) kadar bekleten repo → offline benzetimi.
/// [addGate] set edilirse `add` yerel yazmayı uygular ama Future onaya dek
/// tamamlanmaz (Firestore'un offline davranışı).
class _GatedWorkerRepository implements WorkerRepository {
  Completer<void>? addGate;
  final Map<String, Worker> _store = {};
  int get count => _store.length;

  @override
  Future<void> add(Worker worker) async {
    _store[worker.id] = worker; // latency compensation: yerelde anında
    if (addGate != null) await addGate!.future; // onay offline'da hiç gelmez
  }

  @override
  Future<void> update(Worker worker) async => _store[worker.id] = worker;

  @override
  Future<void> setActive(String id, {required bool active}) async {}

  @override
  Future<void> delete(String id) async => _store.remove(id);

  @override
  Stream<List<Worker>> watchAll() => Stream.value(_store.values.toList());
}

void main() {
  const worker = Worker(
    id: 'w1',
    name: 'Ahmet',
    type: WorkerType.sabit,
    gender: Gender.male,
    dailyWageOverrideKurus: 210000,
  );

  late FakeWorkerRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeWorkerRepository();
    container = ProviderContainer(overrides: [
      workerRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
  });

  WorkerEditViewModel vm() =>
      container.read(workerEditViewModelProvider.notifier);

  test('yeni işçi ekler, depoda görünür', () async {
    await vm().submit(worker: worker, isNew: true);
    expect(repo.all.length, 1);
    expect(repo.all.single, worker);
    expect(container.read(workerEditViewModelProvider).done, true);
  });

  test('soft-delete: active:false yapar (hard-delete yok — kural §5)', () async {
    await vm().submit(worker: worker, isNew: true);
    await vm().setActive(id: 'w1', active: false);
    expect(repo.all.single.active, false);
    // İşçi hâlâ depoda (silinmedi), sadece pasif.
    expect(repo.all.length, 1);
  });

  test('geri alma: pasif işçiyi tekrar aktif yapar', () async {
    await vm().submit(worker: worker.copyWith(active: false), isNew: true);
    await vm().setActive(id: 'w1', active: true);
    expect(repo.all.single.active, true);
  });

  test('kalıcı silme: pasif işçiyi depodan tamamen kaldırır', () async {
    await vm().submit(worker: worker.copyWith(active: false), isNew: true);
    await repo.delete('w1');
    expect(repo.all, isEmpty);
  });

  test(
      'OFFLINE: yazma onayı hiç gelmezse submit ~5 sn sonra done olur '
      '(sonsuz "Kaydediliyor…" spinner YOK)', () {
    fakeAsync((async) {
      final gated = _GatedWorkerRepository()..addGate = Completer<void>();
      final c = ProviderContainer(overrides: [
        workerRepositoryProvider.overrideWithValue(gated),
      ]);
      addTearDown(c.dispose);
      final model = c.read(workerEditViewModelProvider.notifier);

      model.submit(worker: worker, isNew: true);
      expect(c.read(workerEditViewModelProvider).saving, isTrue);

      async.elapse(const Duration(seconds: 4));
      expect(c.read(workerEditViewModelProvider).done, isFalse,
          reason: 'zaman aşımından önce beklemede');

      async.elapse(const Duration(seconds: 2)); // awaitWriteAck 5 sn sınırı
      expect(c.read(workerEditViewModelProvider).done, isTrue,
          reason: 'onay gelmese de "kuyruğa alındı" sayılır → ekran kapanır');
      expect(c.read(workerEditViewModelProvider).saving, isFalse,
          reason: 'meşgul bayrağı temizlenir (UI süresiz kilitlenmez)');
      expect(gated.count, 1, reason: 'yerel yazma yine de uygulanmıştır');
    });
  });
}

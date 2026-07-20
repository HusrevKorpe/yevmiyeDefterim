import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/workers/application/worker_edit_view_model.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../../support/fake_worker_repository.dart';

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
}

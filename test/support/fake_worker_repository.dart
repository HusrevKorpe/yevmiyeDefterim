import 'dart:async';

import 'package:yevmiye_defterim/features/workers/data/worker.dart';
import 'package:yevmiye_defterim/features/workers/data/worker_repository.dart';

/// Bellek-içi işçi deposu (testler için). ID'ye göre saklar → çift kayıt yok.
class FakeWorkerRepository implements WorkerRepository {
  final Map<String, Worker> _store = {};
  final StreamController<void> _tick = StreamController<void>.broadcast();

  List<Worker> _sorted() {
    final list = _store.values.toList()..sort(compareWorkers);
    return list;
  }

  @override
  Stream<List<Worker>> watchAll() async* {
    yield _sorted();
    yield* _tick.stream.map((_) => _sorted());
  }

  @override
  Future<void> add(Worker worker) async {
    _store[worker.id] = worker;
    _tick.add(null);
  }

  @override
  Future<void> update(Worker worker) async {
    _store[worker.id] = worker;
    _tick.add(null);
  }

  @override
  Future<void> setActive(String id, {required bool active}) async {
    final w = _store[id];
    if (w != null) _store[id] = w.copyWith(active: active);
    _tick.add(null);
  }

  List<Worker> get all => _sorted();
}

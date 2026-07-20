import 'dart:async';

import 'package:yevmiye_defterim/features/advances/data/advance.dart';
import 'package:yevmiye_defterim/features/advances/data/advance_repository.dart';

/// Bellek-içi avans deposu (testler için).
class FakeAdvanceRepository implements AdvanceRepository {
  FakeAdvanceRepository([List<Advance> seed = const []]) {
    for (final a in seed) {
      _store[a.id] = a;
    }
  }

  final Map<String, Advance> _store = {};
  final StreamController<void> _tick = StreamController<void>.broadcast();

  List<Advance> get all => _store.values.toList();
  int get count => _store.length;
  Advance? byId(String id) => _store[id];

  @override
  Stream<List<Advance>> watchAll() async* {
    yield all;
    yield* _tick.stream.map((_) => all);
  }

  @override
  Future<void> add(Advance advance) async {
    _store[advance.id] = advance;
    _tick.add(null);
  }

  @override
  Future<void> update(Advance advance) async {
    _store[advance.id] = advance;
    _tick.add(null);
  }

  @override
  Future<void> delete(String id) async {
    _store.remove(id);
    _tick.add(null);
  }
}

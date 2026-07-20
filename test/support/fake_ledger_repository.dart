import 'dart:async';

import 'package:yevmiye_defterim/features/ledger/data/ledger_entry.dart';
import 'package:yevmiye_defterim/features/ledger/data/ledger_repository.dart';

/// Bellek-içi kasa deposu (testler için).
class FakeLedgerRepository implements LedgerRepository {
  FakeLedgerRepository([List<LedgerEntry> seed = const []]) {
    for (final e in seed) {
      _store[e.id] = e;
    }
  }

  final Map<String, LedgerEntry> _store = {};
  final StreamController<void> _tick = StreamController<void>.broadcast();

  List<LedgerEntry> get all => _store.values.toList();
  int get count => _store.length;
  LedgerEntry? byId(String id) => _store[id];

  @override
  Stream<List<LedgerEntry>> watchAll() async* {
    yield all;
    yield* _tick.stream.map((_) => all);
  }

  @override
  Stream<List<LedgerEntry>> watchByRange(String startDate, String endDate) {
    List<LedgerEntry> range() => all
        .where((e) =>
            e.date.compareTo(startDate) >= 0 &&
            e.date.compareTo(endDate) <= 0)
        .toList();
    return (() async* {
      yield range();
      yield* _tick.stream.map((_) => range());
    })();
  }

  @override
  Future<void> add(LedgerEntry entry) async {
    _store[entry.id] = entry;
    _tick.add(null);
  }

  @override
  Future<void> update(LedgerEntry entry) async {
    _store[entry.id] = entry;
    _tick.add(null);
  }

  @override
  Future<void> delete(String id) async {
    _store.remove(id);
    _tick.add(null);
  }
}

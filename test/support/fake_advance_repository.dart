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
  final Map<String, int> _rev = {};
  final StreamController<void> _tick = StreamController<void>.broadcast();

  List<Advance> get all => _store.values.toList();
  int get count => _store.length;
  Advance? byId(String id) => _store[id];

  /// Testte çakışma senaryosu kurmak için sürümü elle artır.
  void bumpRev(String id) => _rev[id] = (_rev[id] ?? 0) + 1;

  @override
  Stream<List<Advance>> watchAll() async* {
    yield all;
    yield* _tick.stream.map((_) => all);
  }

  @override
  Future<List<Advance>> getByWorker(String workerId) async =>
      [for (final a in _store.values) if (a.workerId == workerId) a];

  @override
  Future<void> add(Advance advance) async {
    _store[advance.id] = advance;
    bumpRev(advance.id);
    _tick.add(null);
  }

  @override
  Future<void> update(Advance advance) async {
    // Firestore impl'i gibi: düzenleme `settledPayrollId`'ye DOKUNMAZ (kapanış
    // durumu yalnız settle/reopen ile değişir). Saklı kapanış işareti, çağıran
    // eski (null) kopyayı gönderse bile korunur → eşzamanlı kapanış ezilmez.
    final existing = _store[advance.id];
    _store[advance.id] = existing == null
        ? advance
        : advance.copyWith(settledPayrollId: existing.settledPayrollId);
    bumpRev(advance.id);
    _tick.add(null);
  }

  @override
  Future<void> delete(String id) async {
    _store.remove(id);
    _tick.add(null);
  }

  @override
  Future<int> deleteByWorker(String workerId) async {
    final ids = [
      for (final a in _store.values)
        if (a.workerId == workerId) a.id,
    ];
    for (final id in ids) {
      _store.remove(id);
    }
    _tick.add(null);
    return ids.length;
  }

  @override
  Future<void> settleAdvances(
    Iterable<String> ids,
    String settledDate, {
    String? uid,
    Advance? carryover,
  }) async {
    // Gerçek Firestore impl'iyle aynı toleranslı sözleşme: olmayan (eşzamanlı
    // silinmiş) id ATLANIR, devir DAİMA yazılır. Firestore tarafı bunu
    // `set(merge:true)` ile sağlar (`batch.update` olsaydı olmayan hedef tüm
    // batch'i reddeder, devir kaybolurdu — bkz. advance_repository.dart).
    final marker = Advance.manualSettlementId(settledDate, uid);
    for (final id in ids) {
      final a = _store[id];
      if (a != null) {
        _store[id] = a.copyWith(settledPayrollId: marker);
        bumpRev(id);
      }
    }
    if (carryover != null) {
      _store[carryover.id] = carryover;
      bumpRev(carryover.id);
    }
    _tick.add(null);
  }

  @override
  Future<void> reopenAdvances(
    Iterable<String> ids, {
    Iterable<String> deleteIds = const [],
  }) async {
    for (final id in ids) {
      final a = _store[id];
      if (a != null) {
        _store[id] = a.copyWith(settledPayrollId: null);
        bumpRev(id);
      }
    }
    for (final id in deleteIds) {
      _store.remove(id);
    }
    _tick.add(null);
  }

  @override
  Future<int?> currentRev(String id) async =>
      _store.containsKey(id) ? (_rev[id] ?? 0) : null;
}

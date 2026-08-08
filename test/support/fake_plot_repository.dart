import 'dart:async';

import 'package:yevmiye_defterim/features/attendance/data/plot.dart';
import 'package:yevmiye_defterim/features/attendance/data/plot_repository.dart';

/// Bellek-içi tarla deposu (testler için). ID'ye göre saklar → çift kayıt yok.
class FakePlotRepository implements PlotRepository {
  FakePlotRepository([Iterable<Plot> seed = const []]) {
    for (final p in seed) {
      _store[p.id] = p;
    }
  }

  final Map<String, Plot> _store = {};
  final StreamController<void> _tick = StreamController<void>.broadcast();

  List<Plot> _sorted() {
    final list = _store.values.toList()..sort(comparePlots);
    return list;
  }

  @override
  Stream<List<Plot>> watchAll() =>
      // Senkron tick aboneliği + mikrotask'a ertelenmiş ilk değer → ilk-yazım
      // yarışı yok (gerekçe: fake_attendance_repository._watch).
      Stream.multi((c) {
        final sub = _tick.stream.listen((_) => c.add(_sorted()));
        c.onCancel = sub.cancel;
        scheduleMicrotask(() {
          if (!c.isClosed) c.add(_sorted());
        });
      });

  @override
  Future<void> add(Plot plot) async {
    _store[plot.id] = plot;
    _tick.add(null);
  }

  @override
  Future<void> update(Plot plot) async {
    _store[plot.id] = plot;
    _tick.add(null);
  }

  @override
  Future<void> setActive(String id, {required bool active}) async {
    final p = _store[id];
    if (p != null) _store[id] = p.copyWith(active: active);
    _tick.add(null);
  }

  List<Plot> get all => _sorted();
}

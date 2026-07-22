import 'dart:async';

import 'package:yevmiye_defterim/features/attendance/data/field.dart';
import 'package:yevmiye_defterim/features/attendance/data/field_repository.dart';

/// Bellek-içi tarla deposu (testler için). ID'ye göre saklar → çift kayıt yok.
class FakeFieldRepository implements FieldRepository {
  FakeFieldRepository([Iterable<Field> seed = const []]) {
    for (final f in seed) {
      _store[f.id] = f;
    }
  }

  final Map<String, Field> _store = {};
  final StreamController<void> _tick = StreamController<void>.broadcast();

  List<Field> _sorted() {
    final list = _store.values.toList()..sort(compareFields);
    return list;
  }

  @override
  Stream<List<Field>> watchAll() =>
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
  Future<void> add(Field field) async {
    _store[field.id] = field;
    _tick.add(null);
  }

  @override
  Future<void> update(Field field) async {
    _store[field.id] = field;
    _tick.add(null);
  }

  @override
  Future<void> setActive(String id, {required bool active}) async {
    final f = _store[id];
    if (f != null) _store[id] = f.copyWith(active: active);
    _tick.add(null);
  }

  List<Field> get all => _sorted();
}

import 'dart:async';

import 'package:yevmiye_defterim/features/attendance/data/job.dart';
import 'package:yevmiye_defterim/features/attendance/data/job_repository.dart';

/// Bellek-içi iş deposu (testler için). ID'ye göre saklar → çift kayıt yok.
class FakeJobRepository implements JobRepository {
  FakeJobRepository([Iterable<Job> seed = const []]) {
    for (final j in seed) {
      _store[j.id] = j;
    }
  }

  final Map<String, Job> _store = {};
  final StreamController<void> _tick = StreamController<void>.broadcast();

  List<Job> _sorted() {
    final list = _store.values.toList()..sort(compareJobs);
    return list;
  }

  @override
  Stream<List<Job>> watchAll() =>
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
  Future<void> add(Job job) async {
    _store[job.id] = job;
    _tick.add(null);
  }

  @override
  Future<void> update(Job job) async {
    _store[job.id] = job;
    _tick.add(null);
  }

  @override
  Future<void> setActive(String id, {required bool active}) async {
    final j = _store[id];
    if (j != null) _store[id] = j.copyWith(active: active);
    _tick.add(null);
  }

  List<Job> get all => _sorted();
}

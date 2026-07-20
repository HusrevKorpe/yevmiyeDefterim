import 'dart:async';

import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_repository.dart';

/// Bellek-içi yoklama deposu (testler için).
///
/// Kayıtlar deterministik ID'ye göre saklanır → aynı işçi-gün ikinci kez
/// yazılınca üzerine yazılır (çift kayıt olmaz — kural §3, merge davranışı).
class FakeAttendanceRepository implements AttendanceRepository {
  final Map<String, AttendanceRecord> _store = {};
  final StreamController<void> _tick = StreamController<void>.broadcast();

  List<AttendanceRecord> _forDate(String date) =>
      _store.values.where((r) => r.date == date).toList();

  @override
  Stream<List<AttendanceRecord>> watchByDate(String date) async* {
    yield _forDate(date);
    yield* _tick.stream.map((_) => _forDate(date));
  }

  List<AttendanceRecord> _forRange(String start, String end) => _store.values
      .where((r) =>
          r.date.compareTo(start) >= 0 && r.date.compareTo(end) <= 0)
      .toList();

  @override
  Stream<List<AttendanceRecord>> watchByRange(String startDate, String endDate) async* {
    yield _forRange(startDate, endDate);
    yield* _tick.stream.map((_) => _forRange(startDate, endDate));
  }

  List<AttendanceRecord> _forWorker(String workerId) =>
      _store.values.where((r) => r.workerId == workerId).toList();

  @override
  Stream<List<AttendanceRecord>> watchByWorker(String workerId) async* {
    yield _forWorker(workerId);
    yield* _tick.stream.map((_) => _forWorker(workerId));
  }

  @override
  Future<void> save(AttendanceRecord record) async {
    _store[record.id] = record;
    _tick.add(null);
  }

  @override
  Future<void> delete(String id) async {
    _store.remove(id);
    _tick.add(null);
  }

  /// Depodaki toplam kayıt sayısı (çift kayıt kontrolü için).
  int get count => _store.length;

  List<AttendanceRecord> get all => _store.values.toList();
}

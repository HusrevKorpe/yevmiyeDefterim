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

  /// Abone olunca mevcut durumu verir, her yazımda yeniden yayınlar.
  ///
  /// `async*` + `yield* _tick.stream` DEĞİL: async* gövdesi ilk `yield`'de
  /// askıya alınır ve `_tick`'e ancak SONRAKİ mikrotask'ta abone olur; o aralığa
  /// denk gelen yazım (broadcast tamponlamaz) sonsuza dek kaybolurdu → emisyon
  /// hiç gelmez, `waitUntil` zaman aşımına uğrardı. Burada `_tick` aboneliği
  /// dinleme anında SENKRON kurulur (yazım düşmez); ilk değer ise bilerek
  /// mikrotask'a ertelenir ki aynı olay turunda dinlemeden hemen sonra yapılan
  /// yazımlar da ilk emisyona girsin (anlık görüntü erken sabitlenmesin).
  Stream<List<AttendanceRecord>> _watch(
          List<AttendanceRecord> Function() snapshot) =>
      Stream.multi((c) {
        final sub = _tick.stream.listen((_) => c.add(snapshot()));
        c.onCancel = sub.cancel;
        scheduleMicrotask(() {
          if (!c.isClosed) c.add(snapshot());
        });
      });

  List<AttendanceRecord> _forDate(String date) =>
      _store.values.where((r) => r.date == date).toList();

  @override
  Stream<List<AttendanceRecord>> watchByDate(String date) =>
      _watch(() => _forDate(date));

  List<AttendanceRecord> _forRange(String start, String end) => _store.values
      .where((r) =>
          r.date.compareTo(start) >= 0 && r.date.compareTo(end) <= 0)
      .toList();

  @override
  Stream<List<AttendanceRecord>> watchByRange(String startDate, String endDate) =>
      _watch(() => _forRange(startDate, endDate));

  List<AttendanceRecord> _forWorker(String workerId) =>
      _store.values.where((r) => r.workerId == workerId).toList();

  @override
  Stream<List<AttendanceRecord>> watchByWorker(String workerId) =>
      _watch(() => _forWorker(workerId));

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

  @override
  Future<void> markDaySaved(String date) async {
    markedDays.add(date);
  }

  /// "Kaydet" ile işaretlenen günler (push bildirim tetiği testleri için).
  final List<String> markedDays = [];

  /// Depodaki toplam kayıt sayısı (çift kayıt kontrolü için).
  int get count => _store.length;

  List<AttendanceRecord> get all => _store.values.toList();
}

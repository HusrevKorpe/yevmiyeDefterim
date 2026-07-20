/// Yoklama deposu (kural §3: deterministik ID + merge, offline yazma).
///
/// Soyut arayüz + Firestore implementasyonu (testlerde fake ile override).
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/date/app_date.dart';
import '../../../core/firestore/refs.dart';
import '../../../core/firestore/write_stamp.dart';
import 'attendance_record.dart';

abstract class AttendanceRepository {
  /// Belirli günün yoklama kayıtları.
  Stream<List<AttendanceRecord>> watchByDate(String date);

  /// Tarih aralığındaki (uçlar dahil) yoklama kayıtları — hakediş için.
  Stream<List<AttendanceRecord>> watchByRange(String startDate, String endDate);

  /// Bir işçinin tüm yoklama kayıtları — işçi geçmişi (Faz 4).
  Stream<List<AttendanceRecord>> watchByWorker(String workerId);

  /// Kaydı yazar. ID deterministik ({date}_{workerId}), `merge:true` →
  /// aynı işçi-gün çift kayıt olmaz (kural §3).
  Future<void> save(AttendanceRecord record);

  /// Kaydı siler (deterministik ID). Yoklama alınmayan/geri alınan gün için:
  /// kayıt hiç tutulmaz → gün "Yok" sayılmaz, hiçbir hesaba girmez.
  Future<void> delete(String id);
}

class FirestoreAttendanceRepository implements AttendanceRepository {
  FirestoreAttendanceRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<AttendanceRecord>> watchByDate(String date) => attendanceCol(_db)
      .where('date', isEqualTo: date)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => AttendanceRecord.fromDoc(d.id, d.data()))
          .toList());

  @override
  Stream<List<AttendanceRecord>> watchByRange(String startDate, String endDate) =>
      attendanceCol(_db)
          // 'date' tek-alan aralığı ('yyyy-MM-dd' sözlük sırası = kronolojik).
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => AttendanceRecord.fromDoc(d.id, d.data()))
              .toList());

  @override
  Stream<List<AttendanceRecord>> watchByWorker(String workerId) =>
      attendanceCol(_db)
          // Tek-alan eşitlik → composite index gerekmez (kural §3 kalıbı).
          .where('workerId', isEqualTo: workerId)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => AttendanceRecord.fromDoc(d.id, d.data()))
              .toList());

  @override
  Future<void> save(AttendanceRecord record) =>
      attendanceCol(_db).doc(record.id).set({
        ...record.toMap(),
        // Sorgu/aralık için iş gününün yerel gün-başı damgası (kural §2).
        'ts': Timestamp.fromDate(parseIsoDate(record.date)),
        ...writeStamp(),
      }, SetOptions(merge: true));

  @override
  Future<void> delete(String id) => attendanceCol(_db).doc(id).delete();
}

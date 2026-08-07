/// Yapılan iş deposu — CRUD + soft-delete (kural §5, §7).
///
/// Soyut arayüz + Firestore implementasyonu (testlerde fake ile override).
/// ID cihazda üretilir (kural §3); zaman damgaları burada eklenir (kural §2).
/// Koleksiyon adı tarihseldir (`fields` = işler, bkz. [Job]).
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/refs.dart';
import '../../../core/firestore/write_stamp.dart';
import 'job.dart';

abstract class JobRepository {
  /// Tüm işler (aktif + pasif), ada göre sıralı.
  Stream<List<Job>> watchAll();

  /// Yeni iş ekler (createdAt damgalanır).
  Future<void> add(Job job);

  /// Var olan işi günceller (ad değişikliği; createdAt'e dokunmaz).
  Future<void> update(Job job);

  /// Soft-delete / geri alma (kural §5): `active` bayrağını değiştirir.
  Future<void> setActive(String id, {required bool active});
}

class FirestoreJobRepository implements JobRepository {
  FirestoreJobRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<Job>> watchAll() => jobsCol(_db).snapshots().map((snap) {
        final list = snap.docs.map((d) => Job.fromDoc(d.id, d.data())).toList()
          ..sort(compareJobs);
        return list;
      });

  @override
  Future<void> add(Job job) => jobsCol(_db).doc(job.id).set({
        ...job.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        ...writeStamp(),
      });

  @override
  Future<void> update(Job job) => jobsCol(_db).doc(job.id).set({
        ...job.toMap(),
        ...writeStamp(),
      }, SetOptions(merge: true));

  @override
  Future<void> setActive(String id, {required bool active}) =>
      jobsCol(_db).doc(id).set({
        'active': active,
        ...writeStamp(),
      }, SetOptions(merge: true));
}

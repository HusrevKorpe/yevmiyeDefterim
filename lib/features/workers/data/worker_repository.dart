/// İşçi deposu — CRUD + soft-delete (kural §5, §7).
///
/// Soyut arayüz + Firestore implementasyonu (testlerde fake ile override).
/// ID cihazda üretilir (kural §3); zaman damgaları burada eklenir (kural §2).
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/refs.dart';
import '../../../core/firestore/write_stamp.dart';
import 'worker.dart';

abstract class WorkerRepository {
  /// Tüm işçiler (aktif + pasif), tür sonra ada göre sıralı.
  Stream<List<Worker>> watchAll();

  /// Yeni işçi ekler (createdAt damgalanır).
  Future<void> add(Worker worker);

  /// Var olan işçiyi günceller (createdAt'e dokunmaz).
  Future<void> update(Worker worker);

  /// Soft-delete / geri alma (kural §5): `active` bayrağını değiştirir.
  Future<void> setActive(String id, {required bool active});

  /// Kalıcı silme: işçi dokümanını Firestore'dan tamamen kaldırır (geri
  /// alınamaz). Yalnız zaten pasif (soft-delete edilmiş) işçiler için kullanılır.
  /// Geçmiş yoklama/avans kayıtları işçinin adını denormalize sakladığından
  /// raporlarda görünmeye devam eder; yalnız işçi listesinden kaybolur.
  Future<void> delete(String id);
}

class FirestoreWorkerRepository implements WorkerRepository {
  FirestoreWorkerRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<Worker>> watchAll() => workersCol(_db).snapshots().map((snap) {
        final list = snap.docs
            .map((d) => Worker.fromDoc(d.id, d.data()))
            .toList()
          ..sort(compareWorkers);
        return list;
      });

  @override
  Future<void> add(Worker worker) => workersCol(_db).doc(worker.id).set({
        ...worker.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        ...writeStamp(),
      });

  @override
  Future<void> update(Worker worker) => workersCol(_db).doc(worker.id).set({
        ...worker.toMap(),
        ...writeStamp(),
      }, SetOptions(merge: true));

  @override
  Future<void> setActive(String id, {required bool active}) =>
      workersCol(_db).doc(id).set({
        'active': active,
        ...writeStamp(),
      }, SetOptions(merge: true));

  @override
  Future<void> delete(String id) => workersCol(_db).doc(id).delete();
}

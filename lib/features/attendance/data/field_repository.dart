/// Tarla deposu — CRUD + soft-delete (kural §5, §7).
///
/// Soyut arayüz + Firestore implementasyonu (testlerde fake ile override).
/// ID cihazda üretilir (kural §3); zaman damgaları burada eklenir (kural §2).
library;

// `hide Field`: cloud_firestore da `Field` adında bir sınıf export ediyor;
// bizim tarla modelimizle (data/field.dart) çakışmasın.
import 'package:cloud_firestore/cloud_firestore.dart' hide Field;

import '../../../core/firestore/refs.dart';
import '../../../core/firestore/write_stamp.dart';
import 'field.dart';

abstract class FieldRepository {
  /// Tüm tarlalar (aktif + pasif), ada göre sıralı.
  Stream<List<Field>> watchAll();

  /// Yeni tarla ekler (createdAt damgalanır).
  Future<void> add(Field field);

  /// Var olan tarlayı günceller (ad değişikliği; createdAt'e dokunmaz).
  Future<void> update(Field field);

  /// Soft-delete / geri alma (kural §5): `active` bayrağını değiştirir.
  Future<void> setActive(String id, {required bool active});
}

class FirestoreFieldRepository implements FieldRepository {
  FirestoreFieldRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<Field>> watchAll() => fieldsCol(_db).snapshots().map((snap) {
        final list = snap.docs
            .map((d) => Field.fromDoc(d.id, d.data()))
            .toList()
          ..sort(compareFields);
        return list;
      });

  @override
  Future<void> add(Field field) => fieldsCol(_db).doc(field.id).set({
        ...field.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        ...writeStamp(),
      });

  @override
  Future<void> update(Field field) => fieldsCol(_db).doc(field.id).set({
        ...field.toMap(),
        ...writeStamp(),
      }, SetOptions(merge: true));

  @override
  Future<void> setActive(String id, {required bool active}) =>
      fieldsCol(_db).doc(id).set({
        'active': active,
        ...writeStamp(),
      }, SetOptions(merge: true));
}

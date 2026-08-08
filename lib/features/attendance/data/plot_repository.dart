/// Tarla deposu — CRUD + soft-delete (kural §5, §7).
///
/// Soyut arayüz + Firestore implementasyonu (testlerde fake ile override).
/// ID cihazda üretilir (kural §3); zaman damgaları burada eklenir (kural §2).
/// [JobRepository] ile birebir aynı davranış, ayrı koleksiyon (`plots`).
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/refs.dart';
import '../../../core/firestore/write_stamp.dart';
import 'plot.dart';

abstract class PlotRepository {
  /// Tüm tarlalar (aktif + pasif), ada göre sıralı.
  Stream<List<Plot>> watchAll();

  /// Yeni tarla ekler (createdAt damgalanır).
  Future<void> add(Plot plot);

  /// Var olan tarlayı günceller (ad değişikliği; createdAt'e dokunmaz).
  Future<void> update(Plot plot);

  /// Soft-delete / geri alma (kural §5): `active` bayrağını değiştirir.
  Future<void> setActive(String id, {required bool active});
}

class FirestorePlotRepository implements PlotRepository {
  FirestorePlotRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<Plot>> watchAll() => plotsCol(_db).snapshots().map((snap) {
        final list = snap.docs.map((d) => Plot.fromDoc(d.id, d.data())).toList()
          ..sort(comparePlots);
        return list;
      });

  @override
  Future<void> add(Plot plot) => plotsCol(_db).doc(plot.id).set({
        ...plot.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        ...writeStamp(),
      });

  @override
  Future<void> update(Plot plot) => plotsCol(_db).doc(plot.id).set({
        ...plot.toMap(),
        ...writeStamp(),
      }, SetOptions(merge: true));

  @override
  Future<void> setActive(String id, {required bool active}) =>
      plotsCol(_db).doc(id).set({
        'active': active,
        ...writeStamp(),
      }, SetOptions(merge: true));
}

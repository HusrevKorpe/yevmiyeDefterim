/// Avans deposu — CRUD (kural §6: tek kaynak; §7: repository).
///
/// Soyut arayüz + Firestore implementasyonu (testlerde fake ile override).
/// ID cihazda üretilir (kural §3); zaman damgaları burada eklenir (kural §2).
/// Kapanmış (mahsup edilmiş) avans düzenlenmez/silinmez — çağıran engeller.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/date/app_date.dart';
import '../../../core/firestore/refs.dart';
import '../../../core/firestore/write_stamp.dart';
import 'advance.dart';

abstract class AdvanceRepository {
  /// Tüm avanslar (kapanmış + açık). Filtre/sıralama sağlayıcıda yapılır.
  Stream<List<Advance>> watchAll();

  /// Yeni avans ekler (createdAt damgalanır).
  Future<void> add(Advance advance);

  /// Var olan avansı günceller (createdAt'e dokunmaz).
  Future<void> update(Advance advance);

  /// Avansı siler (yalnız kapanmamış avans için — çağıran doğrular).
  Future<void> delete(String id);

  /// Verilen avansları "Hesap görüldü" ile kapatır (tek batch). Her birine
  /// [settledDate] tarihli işaret yazılır → açık listeden düşer, alacak kalmaz.
  /// [carryover] verilirse (devreden alacağımız) AYNI batch'te yeni açık avans
  /// olarak yazılır → sonraki hesaba devreder.
  Future<void> settleAdvances(
    Iterable<String> ids,
    String settledDate, {
    Advance? carryover,
  });

  /// "Hesap görüldü" ile kapatılan avansları yeniden açar (geri al, tek batch).
  /// [deleteIds] (o kapanışta oluşan devir kayıtları) AYNI batch'te silinir.
  Future<void> reopenAdvances(
    Iterable<String> ids, {
    Iterable<String> deleteIds = const [],
  });

  /// Dokümanın güncel sürüm numarası (`rev`) — düzenleme çakışması tespiti için.
  /// Doküman yoksa null. Online'da sunucu değerini, offline'da önbelleği getirir.
  Future<int?> currentRev(String id);
}

class FirestoreAdvanceRepository implements AdvanceRepository {
  FirestoreAdvanceRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<Advance>> watchAll() => advancesCol(_db).snapshots().map((snap) =>
      snap.docs.map((d) => Advance.fromDoc(d.id, d.data())).toList());

  @override
  Future<void> add(Advance advance) => advancesCol(_db).doc(advance.id).set({
        ...advance.toMap(),
        // Sorgu/aralık için avans gününün yerel gün-başı damgası (kural §2).
        'ts': Timestamp.fromDate(parseIsoDate(advance.date)),
        'createdAt': FieldValue.serverTimestamp(),
        ...writeStamp(),
      });

  @override
  Future<void> update(Advance advance) => advancesCol(_db).doc(advance.id).set({
        ...advance.toMap(),
        'ts': Timestamp.fromDate(parseIsoDate(advance.date)),
        ...writeStamp(),
      }, SetOptions(merge: true));

  @override
  Future<void> delete(String id) => advancesCol(_db).doc(id).delete();

  @override
  Future<void> settleAdvances(
    Iterable<String> ids,
    String settledDate, {
    Advance? carryover,
  }) {
    final batch = _db.batch();
    final marker = Advance.manualSettlementId(settledDate);
    for (final id in ids) {
      batch.set(
        advancesCol(_db).doc(id),
        {'settledPayrollId': marker, ...writeStamp()},
        SetOptions(merge: true),
      );
    }
    if (carryover != null) {
      // Devir kaydı = normal yeni avans dokümanı (add ile aynı alanlar) —
      // kapanışla atomik yazılır ki yarım durum (kapandı ama devir yok) olmasın.
      batch.set(advancesCol(_db).doc(carryover.id), {
        ...carryover.toMap(),
        'ts': Timestamp.fromDate(parseIsoDate(carryover.date)),
        'createdAt': FieldValue.serverTimestamp(),
        ...writeStamp(),
      });
    }
    return batch.commit();
  }

  @override
  Future<void> reopenAdvances(
    Iterable<String> ids, {
    Iterable<String> deleteIds = const [],
  }) {
    final batch = _db.batch();
    for (final id in ids) {
      batch.set(
        advancesCol(_db).doc(id),
        {'settledPayrollId': null, ...writeStamp()},
        SetOptions(merge: true),
      );
    }
    for (final id in deleteIds) {
      batch.delete(advancesCol(_db).doc(id));
    }
    return batch.commit();
  }

  @override
  Future<int?> currentRev(String id) async {
    final snap = await advancesCol(_db).doc(id).get();
    return snap.exists ? revOfData(snap.data()) : null;
  }
}

/// Kasa deposu — gelir/gider CRUD (plan §5, kural §6, §7).
///
/// Soyut arayüz + Firestore implementasyonu (testlerde fake ile override).
/// ID cihazda üretilir (kural §3); zaman damgaları burada eklenir (kural §2).
/// Yalnız elle (`source: manual`) kayıtlar düzenlenir/silinir — hakediş "Öde"
/// akışının yazdığı otomatik kayıtlar dokunulmaz; çağıran ([isManual]) doğrular.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/date/app_date.dart';
import '../../../core/firestore/refs.dart';
import 'ledger_entry.dart';

abstract class LedgerRepository {
  /// Tüm kayıtlar (elle + otomatik). Filtre/sıralama sağlayıcıda yapılır.
  Stream<List<LedgerEntry>> watchAll();

  /// Tarih aralığındaki (uçlar dahil) kayıtlar — dönem özeti/listesi için.
  Stream<List<LedgerEntry>> watchByRange(String startDate, String endDate);

  /// Yeni elle kayıt ekler (createdAt damgalanır).
  Future<void> add(LedgerEntry entry);

  /// Var olan elle kaydı günceller (createdAt'e dokunmaz).
  Future<void> update(LedgerEntry entry);

  /// Kaydı siler (yalnız elle kayıt için — çağıran doğrular).
  Future<void> delete(String id);
}

class FirestoreLedgerRepository implements LedgerRepository {
  FirestoreLedgerRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<LedgerEntry>> watchAll() => ledgerCol(_db).snapshots().map(
      (snap) => snap.docs
          .map((d) => LedgerEntry.fromDoc(d.id, d.data()))
          .toList());

  @override
  Stream<List<LedgerEntry>> watchByRange(String startDate, String endDate) =>
      ledgerCol(_db)
          // 'date' tek-alan aralığı ('yyyy-MM-dd' sözlük sırası = kronolojik).
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => LedgerEntry.fromDoc(d.id, d.data()))
              .toList());

  @override
  Future<void> add(LedgerEntry entry) => ledgerCol(_db).doc(entry.id).set({
        ...entry.toMap(),
        // Sorgu/aralık için kayıt gününün yerel gün-başı damgası (kural §2).
        'ts': Timestamp.fromDate(parseIsoDate(entry.date)),
        'createdAt': FieldValue.serverTimestamp(),
        ..._touch(),
      });

  @override
  Future<void> update(LedgerEntry entry) => ledgerCol(_db).doc(entry.id).set({
        ...entry.toMap(),
        'ts': Timestamp.fromDate(parseIsoDate(entry.date)),
        ..._touch(),
      }, SetOptions(merge: true));

  @override
  Future<void> delete(String id) => ledgerCol(_db).doc(id).delete();

  Map<String, dynamic> _touch() => {
        'updatedAt': FieldValue.serverTimestamp(),
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
      };
}

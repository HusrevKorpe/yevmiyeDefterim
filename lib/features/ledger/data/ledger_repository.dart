/// Kasa deposu — gider CRUD (plan §5, kural §6, §7).
///
/// Soyut arayüz + Firestore implementasyonu (testlerde fake ile override).
/// ID cihazda üretilir (kural §3); zaman damgaları burada eklenir (kural §2).
/// Yalnız elle (`source: manual`) kayıtlar düzenlenir/silinir — hakediş "Öde"
/// akışının yazdığı otomatik kayıtlar dokunulmaz; çağıran ([isManual]) doğrular.
///
/// Uygulama artık yalnız gider takip eder. Eski sürümde girilmiş gelir
/// (`type == 'income'`) ile hakediş "Öde" akışının yazdığı otomatik maaş/elebaşı
/// kayıtları okurken elenir → Kasa/rapor toplamlarını bozmaz.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/categories.dart';
import '../../../core/date/app_date.dart';
import '../../../core/firestore/refs.dart';
import '../../../core/firestore/write_stamp.dart';
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

  /// Dokümanın güncel sürüm numarası (`rev`) — düzenleme çakışması tespiti için.
  /// Doküman yoksa null. Online'da sunucu değerini getirir (başka cihazın
  /// yazımını görür); offline'da önbellekten.
  Future<int?> currentRev(String id);
}

class FirestoreLedgerRepository implements LedgerRepository {
  FirestoreLedgerRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<LedgerEntry>> watchAll() => ledgerCol(_db).snapshots().map(
      (snap) => snap.docs
          .where(_isVisibleExpense)
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
              .where(_isVisibleExpense)
              .map((d) => LedgerEntry.fromDoc(d.id, d.data()))
              .toList());

  /// Kasa'da görünmemesi gereken dokümanları okurken eler. İki kural:
  ///
  /// 1. **Gelir** (`type == 'income'`) — gelir kavramı kaldırıldı, KALICI elenir.
  /// 2. **Otomatik maaş/elebaşı** (`source: payroll/elebasi`) — hakediş "Öde"
  ///    akışının yazdığı salt-okunur kayıtlar. Hakediş rafa kalkınca bunları
  ///    silecek arayüz kalmadığından Kasa'da asılı kalıyorlardı → eleniyorlar.
  ///    --- HAKEDİŞ ŞİMDİLİK RAFTA ---: hakediş geri açılınca bu source süzgecini
  ///    kaldır ki maaş ödemeleri Kasa'ya yeniden yansısın (kural §6 çifte-sayım).
  static bool _isVisibleExpense(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    if (data['type'] == 'income') return false;
    final source = data['source'];
    return source != LedgerSource.payroll && source != LedgerSource.elebasi;
  }

  @override
  Future<void> add(LedgerEntry entry) => ledgerCol(_db).doc(entry.id).set({
        ...entry.toMap(),
        // Sorgu/aralık için kayıt gününün yerel gün-başı damgası (kural §2).
        'ts': Timestamp.fromDate(parseIsoDate(entry.date)),
        'createdAt': FieldValue.serverTimestamp(),
        ...writeStamp(),
      });

  @override
  Future<void> update(LedgerEntry entry) => ledgerCol(_db).doc(entry.id).set({
        ...entry.toMap(),
        'ts': Timestamp.fromDate(parseIsoDate(entry.date)),
        ...writeStamp(),
      }, SetOptions(merge: true));

  @override
  Future<void> delete(String id) => ledgerCol(_db).doc(id).delete();

  @override
  Future<int?> currentRev(String id) async {
    final snap = await ledgerCol(_db).doc(id).get();
    return snap.exists ? revOfData(snap.data()) : null;
  }
}

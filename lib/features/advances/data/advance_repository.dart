/// Avans deposu — CRUD (kural §6: tek kaynak; §7: repository).
///
/// Soyut arayüz + Firestore implementasyonu (testlerde fake ile override).
/// ID cihazda üretilir (kural §3); zaman damgaları burada eklenir (kural §2).
/// Kapanmış (mahsup edilmiş) avans düzenlenmez/silinmez — çağıran engeller.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/date/app_date.dart';
import '../../../core/firestore/batch_delete.dart';
import '../../../core/firestore/refs.dart';
import '../../../core/firestore/write_stamp.dart';
import 'advance.dart';

abstract class AdvanceRepository {
  /// Tüm avanslar (kapanmış + açık). Filtre/sıralama sağlayıcıda yapılır.
  Stream<List<Advance>> watchAll();

  /// Bir işçinin TÜM avanslarını (açık + kapanmış) TEK SEFERLİK okur (dinlemez).
  /// İşçi düzenleme ekranı, yevmiye zammının geriye ne kadar işleyeceğini
  /// (son "Hesap görüldü" tarihini) bulmak için kullanır — Avanslar sekmesi hiç
  /// açılmamış olsa bile veri gelsin diye akış yerine tek atımlık okuma.
  Future<List<Advance>> getByWorker(String workerId);

  /// Yeni avans ekler (createdAt damgalanır).
  Future<void> add(Advance advance);

  /// Var olan avansı günceller (createdAt'e dokunmaz).
  Future<void> update(Advance advance);

  /// Avansı siler (yalnız kapanmamış avans için — çağıran doğrular).
  Future<void> delete(String id);

  /// Bir işçinin TÜM avanslarını (açık + kapanmış) siler; silinen kayıt sayısını
  /// döndürür. Yalnız kalıntı/deneme verisi temizliği içindir — normal akışta
  /// kapanmış avans SİLİNMEZ. Çağıran onay almakla yükümlüdür.
  Future<int> deleteByWorker(String workerId);

  /// Verilen avansları "Hesap görüldü" ile kapatır (tek batch). Her birine
  /// [settledDate] tarihli işaret yazılır → açık listeden düşer, alacak kalmaz.
  /// [uid] verilirse işaret olay-benzersiz olur (aynı gün ikinci kapanış ayrı
  /// grup). [carryover] verilirse (devreden alacağımız) AYNI batch'te yeni açık
  /// avans olarak yazılır → sonraki hesaba devreder.
  Future<void> settleAdvances(
    Iterable<String> ids,
    String settledDate, {
    String? uid,
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
  Future<List<Advance>> getByWorker(String workerId) async {
    // Varsayılan kaynak (sunucu + önbellek): çevrimdışıyken yerel önbellekten
    // döner → uçakta da zam geçmişe uygulanabilir. Tek-alan eşitlik sorgusu →
    // composite index gerekmez.
    final snap =
        await advancesCol(_db).where('workerId', isEqualTo: workerId).get();
    return snap.docs.map((d) => Advance.fromDoc(d.id, d.data())).toList();
  }

  @override
  Future<void> add(Advance advance) => advancesCol(_db).doc(advance.id).set({
        ...advance.toMap(),
        // Sorgu/aralık için avans gününün yerel gün-başı damgası (kural §2).
        'ts': Timestamp.fromDate(parseIsoDate(advance.date)),
        'createdAt': FieldValue.serverTimestamp(),
        ...writeStamp(),
      });

  @override
  Future<void> update(Advance advance) {
    // Düzenleme YALNIZ tutar/tarih/not/isim değiştirir. `settledPayrollId`'yi
    // BİLEREK yazmayız (map'ten çıkarılır): `merge:true` ile açık avansın
    // `null`'ını yazmak, başka cihazın bu arada yaptığı "Hesap Görüldü"
    // kapanışını EZERDİ (kapanışı sessizce geri açardı). Kapanış/açılış yalnız
    // settleAdvances/reopenAdvances üzerinden değişir; merge, yazılmayan alanın
    // sunucudaki değerini korur.
    final fields = advance.toMap()..remove('settledPayrollId');
    return advancesCol(_db).doc(advance.id).set({
      ...fields,
      'ts': Timestamp.fromDate(parseIsoDate(advance.date)),
      ...writeStamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> delete(String id) => advancesCol(_db).doc(id).delete();

  @override
  Future<int> deleteByWorker(String workerId) async {
    final snap =
        await advancesCol(_db).where('workerId', isEqualTo: workerId).get();
    return deleteDocsInBatches(_db, snap.docs.map((d) => d.reference));
  }

  @override
  Future<void> settleAdvances(
    Iterable<String> ids,
    String settledDate, {
    String? uid,
    Advance? carryover,
  }) async {
    final marker = Advance.manualSettlementId(settledDate, uid);
    // İşaretler `set(merge:true)` ile yazılır, `update` ile DEĞİL. Neden: kapanış
    // + devir TEK batch'tedir ve `batch.update` hedef doküman commit anında yoksa
    // TÜM batch'i sunucuda reddeder. Başka cihaz bu avanslardan birini biz
    // `_existingIds` okuduktan SONRA ama batch sunucuya gitmeden silerse, `update`
    // silinmiş dokümanı bulamaz → kapanışlar VE devir (yeni GERÇEK borç) sessizce
    // geri alınır (awaitWriteAck çoktan "başarı" demiş, kullanıcı devri görmüştür).
    // `set` asla reddetmez → devir asla kaybolmaz. `_existingIds` yine de
    // en-iyi-çaba hayalet azaltıcıdır: zaten silinip senkronlanmış avanslara
    // işaret yazmayız. Kalan dar yarış (okumadan sonra, commit'ten önce silme)
    // yalnız ₺0 boş-isimli KAPALI kozmetik kayıt bırakır (Advance.fromDoc
    // toleranslı; isOpen=false → bakiyeye etkisi 0). Fake repo sözleşmesiyle aynı:
    // olmayan id atlanır, var olanlar kapanır, devir DAİMA yazılır (tek batch).
    final existing = await _existingIds(ids);
    final batch = _db.batch();
    for (final id in existing) {
      batch.set(
        advancesCol(_db).doc(id),
        {'settledPayrollId': marker, ...writeStamp()},
        SetOptions(merge: true),
      );
    }
    if (carryover != null) {
      // Devir kaydı = normal yeni avans dokümanı (add ile aynı alanlar).
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
  }) async {
    // Yeniden açma da `set(merge:true)` kullanır (bkz. [settleAdvances]): aynı
    // batch'te o kapanışın devir kayıtları da silinir ([deleteIds]). `batch.update`
    // yeniden açılacak avanslardan biri eşzamanlı silinmişse TÜM batch'i reddedip
    // "Geri Al"ı sessizce başarısız kılardı → devir kayıtları silinmeden kalır,
    // borç çift görünürdü. `set` reddetmez. `_existingIds` en-iyi-çaba ghost
    // azaltıcı; kalan dar yarış yalnız ₺0 AÇIK kozmetik kayıt bırakır (bakiye 0).
    // `batch.delete` olmayan dokümanda zaten no-op.
    final existing = await _existingIds(ids);
    final batch = _db.batch();
    for (final id in existing) {
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

  /// Verilen ID'lerden Firestore'da HÂLÂ var olanları döndürür (paralel okuma).
  /// Silinmiş dokümana yazıp "hayalet" yaratmayı önlemek için batch öncesi süzme.
  Future<List<String>> _existingIds(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return const [];
    final snaps = await Future.wait(
      list.map((id) => advancesCol(_db).doc(id).get()),
    );
    return [for (final s in snaps) if (s.exists) s.id];
  }

  @override
  Future<int?> currentRev(String id) async {
    final snap = await advancesCol(_db).doc(id).get();
    return snap.exists ? revOfData(snap.data()) : null;
  }
}

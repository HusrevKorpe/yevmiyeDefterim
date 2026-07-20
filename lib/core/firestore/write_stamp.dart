/// Ortak yazma damgası — her Firestore yazımına eklenir (kural §2, §3).
///
/// İçerik:
/// - `updatedAt`     : sunucu zaman damgası (offline'da null gelir, senkronda dolar).
/// - `clientUpdatedAt`: cihaz saati (ms) — sıralama/kaba sürüm izi.
/// - `rev`           : her yazımda +1 (offline uyumlu `FieldValue.increment`).
///                     İki cihaz aynı dokümanı düzenlerse sürüm artışından
///                     çakışma tespit edilir (bkz. `currentRev` + düzenleme onayı).
/// - `updatedByUid`  : yazan kullanıcının kimliği — denetim izi (kim değiştirdi).
/// - `updatedByEmail`: okunur kimlik (3 kullanıcı e-postası).
///
/// Neden serbest fonksiyon: repository'ler sade sınıflar; testlerde repo'lar
/// fake ile override edilir → bu fonksiyon (ve `FirebaseAuth`) hiç çağrılmaz.
/// Bu yüzden ekstra provider/enjeksiyon gerekmez, testler etkilenmez.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Yazma sırasında eklenecek meta alanlar. `...writeStamp()` ile domain
/// alanlarının yanına serpiştirilir.
Map<String, dynamic> writeStamp() {
  final user = FirebaseAuth.instance.currentUser;
  return {
    'updatedAt': FieldValue.serverTimestamp(),
    'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
    // Yeni dokümanda 0'dan 1'e; mevcut dokümanda atomik artar (offline dahil).
    'rev': FieldValue.increment(1),
    if (user != null) 'updatedByUid': user.uid,
    if (user?.email != null) 'updatedByEmail': user!.email,
  };
}

/// Dokümandan okunan sürüm numarası (yoksa 0). Çakışma tespitinde kullanılır.
int revOfData(Map<String, dynamic>? data) {
  final v = (data ?? const {})['rev'];
  if (v is int) return v;
  if (v is num) return v.toInt();
  return 0;
}

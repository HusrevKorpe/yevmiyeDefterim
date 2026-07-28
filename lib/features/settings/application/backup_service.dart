/// Uygulama içi tam veri yedeği — tüm Firestore koleksiyonlarını tek bir JSON
/// dosyasına aktarır ve paylaşım yaprağıyla dışa verir (kural §3 dayanıklılık).
///
/// Neden bu var: Firestore commit edilmiş veriyi kaybetmez ama YANLIŞLIKLA
/// silinen/ezilen kayıtların otomatik "geçmişe dönüşü" yoktur. Bu yedek, 3
/// cihazlı kullanımda kaza/silme riskine karşı elle alınabilen bir kopya sağlar.
/// Spark (ücretsiz) planında da çalışır — bulut zamanlanmış export gerekmez.
///
/// Not: geri yükleme (restore) BİLEREK yok — üzerine yazma riskli; ayrı ve
/// onaylı bir akış olarak sonra eklenebilir. Yedek dosyası düz JSON olduğundan
/// gerektiğinde elle/araçla da geri yüklenebilir.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/collections.dart';
import '../../../core/firestore/refs.dart';

/// Yedek üretim sonucu: JSON metni + veri (kısmen) önbellekten mi geldi.
///
/// [fromCache] true ise en az bir koleksiyon SUNUCUDAN değil cihazdaki
/// önbellekten okundu (çevrimdışı) → yedek eksik/eski olabilir; çağıran
/// kullanıcıyı uyarır (bkz. settings_screen). Yedek burada tek güvenlik ağı
/// olduğundan sessiz kalması pahalıdır — bu yüzden bayrak taşınır.
typedef BackupResult = ({String json, bool fromCache});

/// Tüm koleksiyonları okuyup yedeği JSON metni olarak üretir.
///
/// [now] test edilebilirlik için dışarıdan verilebilir (damga).
Future<BackupResult> buildBackupJson(
  FirebaseFirestore db, {
  DateTime? now,
}) async {
  final cols = <String, CollectionReference<Map<String, dynamic>>>{
    FsCollections.workers: workersCol(db),
    FsCollections.attendance: attendanceCol(db),
    FsCollections.advances: advancesCol(db),
    FsCollections.ledger: ledgerCol(db),
    FsCollections.payrolls: payrollsCol(db),
  };

  // get() varsayılan kaynak = sunucu+önbellek: çevrimdışıysa hata vermeden
  // önbellekten döner. Bu sessiz düşüşü yakalamak için her okumanın
  // metadata.isFromCache'ini biriktiririz; biri bile önbellekten geldiyse
  // yedek eksik/eski olabilir.
  var fromCache = false;
  final collections = <String, dynamic>{};
  for (final entry in cols.entries) {
    final snap = await entry.value.get();
    if (snap.metadata.isFromCache) fromCache = true;
    collections[entry.key] = {
      for (final doc in snap.docs) doc.id: _sanitize(doc.data()),
    };
  }

  final settingsSnap = await settingsDocRef(db).get();
  if (settingsSnap.metadata.isFromCache) fromCache = true;

  final root = <String, dynamic>{
    'app': 'yevmiye_defterim',
    'kind': 'firestore-backup',
    'version': 1,
    'workspace': kWorkspaceId,
    'exportedAt': (now ?? DateTime.now()).toIso8601String(),
    // Çevrimdışı alınan yedek dosyada da işaretlensin (elle geri yüklerken
    // "bu kopya eksik olabilir" görülebilsin).
    'fromCache': fromCache,
    'collections': collections,
    'settings': settingsSnap.exists ? _sanitize(settingsSnap.data()) : null,
  };

  return (
    json: const JsonEncoder.withIndent('  ').convert(root),
    fromCache: fromCache,
  );
}

/// Yedeği JSON dosyası olarak paylaşır (Drive/e-posta/dosyalar vb.).
///
/// Dönüş: veri (kısmen) çevrimdışı önbellekten alındıysa `true` → çağıran
/// kullanıcıyı "yedek eksik olabilir" diye uyarır.
Future<bool> shareBackup(FirebaseFirestore db, {DateTime? now}) async {
  final stamp = now ?? DateTime.now();
  final result = await buildBackupJson(db, now: stamp);
  final bytes = Uint8List.fromList(utf8.encode(result.json));
  final file = XFile.fromData(
    bytes,
    mimeType: 'application/json',
    name: 'yevmiye-yedek-${_fileStamp(stamp)}.json',
  );
  await SharePlus.instance.share(
    ShareParams(files: [file], subject: 'Yevmiye Defteri Yedeği'),
  );
  return result.fromCache;
}

/// Dosya adı için `yyyy-MM-dd-HHmm` (yerel).
String _fileStamp(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}-${two(d.hour)}${two(d.minute)}';
}

/// Firestore değerlerini JSON-güvenli hale getirir (özellikle [Timestamp]).
/// Bilinmeyen/serileştirilemeyen tipler son çare olarak metne çevrilir.
Object? _sanitize(Object? value) {
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }
  if (value is Timestamp) {
    return {'__type': 'timestamp', 'iso': value.toDate().toIso8601String()};
  }
  if (value is DateTime) {
    return {'__type': 'timestamp', 'iso': value.toIso8601String()};
  }
  if (value is GeoPoint) {
    return {'__type': 'geopoint', 'lat': value.latitude, 'lng': value.longitude};
  }
  if (value is Map) {
    return {
      for (final e in value.entries) e.key.toString(): _sanitize(e.value),
    };
  }
  if (value is Iterable) {
    return value.map(_sanitize).toList();
  }
  return value.toString();
}

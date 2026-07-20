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

/// Tüm koleksiyonları okuyup yedeği JSON metni olarak üretir.
///
/// [now] test edilebilirlik için dışarıdan verilebilir (damga).
Future<String> buildBackupJson(
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

  final collections = <String, dynamic>{};
  for (final entry in cols.entries) {
    final snap = await entry.value.get();
    collections[entry.key] = {
      for (final doc in snap.docs) doc.id: _sanitize(doc.data()),
    };
  }

  final settingsSnap = await settingsDocRef(db).get();

  final root = <String, dynamic>{
    'app': 'yevmiye_defterim',
    'kind': 'firestore-backup',
    'version': 1,
    'workspace': kWorkspaceId,
    'exportedAt': (now ?? DateTime.now()).toIso8601String(),
    'collections': collections,
    'settings': settingsSnap.exists ? _sanitize(settingsSnap.data()) : null,
  };

  return const JsonEncoder.withIndent('  ').convert(root);
}

/// Yedeği JSON dosyası olarak paylaşır (Drive/e-posta/dosyalar vb.).
Future<void> shareBackup(FirebaseFirestore db, {DateTime? now}) async {
  final stamp = now ?? DateTime.now();
  final json = await buildBackupJson(db, now: stamp);
  final bytes = Uint8List.fromList(utf8.encode(json));
  final file = XFile.fromData(
    bytes,
    mimeType: 'application/json',
    name: 'yevmiye-yedek-${_fileStamp(stamp)}.json',
  );
  await SharePlus.instance.share(
    ShareParams(files: [file], subject: 'Yevmiye Defteri Yedeği'),
  );
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

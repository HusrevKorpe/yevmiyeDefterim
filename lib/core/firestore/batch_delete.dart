/// Toplu doküman silme yardımcısı (kalıntı/deneme verisi temizliği).
///
/// Firestore batch'i en fazla 500 işlem alır → referanslar parçalara bölünür.
/// Commit'ler [awaitWriteAck] ile sarılır: offline'da silme yerel önbelleğe
/// ANINDA uygulanır (stream'ler hemen güncellenir, satır tablodan kalkar) ama
/// sunucu onayı gelmez; onayı sonsuza dek beklemek UI'ı kilitlerdi.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'write_ack.dart';

/// Tek batch'e sığan en fazla işlem sayısı (Firestore sınırı 500).
const int kBatchLimit = 400;

/// [refs] dokümanlarını parçalar hâlinde siler; silinen doküman sayısını
/// döndürür (yerel olarak uygulanan — offline'da senkron arkaplanda sürer).
Future<int> deleteDocsInBatches(
  FirebaseFirestore db,
  Iterable<DocumentReference<Object?>> refs,
) async {
  final list = refs.toList();
  for (var i = 0; i < list.length; i += kBatchLimit) {
    final batch = db.batch();
    for (final ref in list.skip(i).take(kBatchLimit)) {
      batch.delete(ref);
    }
    await awaitWriteAck(batch.commit());
  }
  return list.length;
}

/// Firestore yazma onayını SINIRLI süre bekleme (offline kutsal).
///
/// Offline'da Firestore yazma Future'ları sunucu onayına dek TAMAMLANMAZ;
/// yazmanın kendisi ise `persistenceEnabled` sayesinde anında yerel önbelleğe
/// uygulanır (latency compensation — stream'ler hemen güncellenir) ve bağlantı
/// gelince kendiliğinden senkronlanır. Onayı sonsuza dek beklemek UI'ı kilitler
/// (ör. "Hesap Görüldü" meşgul kalır, ekran kapanmaz). Bu yardımcı onayı en
/// fazla [kWriteAckTimeout] bekler; süre dolarsa yazmayı "kuyruğa alındı"
/// sayıp başarıyla döner. Gerçek hatalar (ör. izin reddi) pratikte bu süre
/// içinde gelir ve aynen fırlar; süre SONRASI oluşan bir hata `Future.timeout`
/// tarafından sessizce yutulur (yerel kuyruk tutarlılığı Firestore'dadır).
///
/// Aynı desenin kökeni: yoklamadaki `markDaySaved` bilerek unawaited bırakılır.
library;

import 'dart:async';

/// Yazma onayı üst sınırı — offline'da UI bu süreden uzun kilitlenmez.
const Duration kWriteAckTimeout = Duration(seconds: 5);

/// [write] onayını en fazla [kWriteAckTimeout] bekler; zaman aşımı = başarı
/// (yazma yerel kuyruğa girdi, arkaplanda senkronlanacak). Diğer hatalar
/// çağırana aynen fırlar.
Future<void> awaitWriteAck(Future<void> write) async {
  try {
    await write.timeout(kWriteAckTimeout);
  } on TimeoutException {
    // Offline/yavaş ağ: yazma yerelde uygulandı; senkron arkaplanda sürecek.
  }
}

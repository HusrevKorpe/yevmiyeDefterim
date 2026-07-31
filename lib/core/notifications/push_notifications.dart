/// Push bildirimi kurulumu (FCM) — "yoklama alındı" bildirimi altyapısı.
///
/// Görevleri:
/// - Girişten sonra cihazın FCM token'ını `fcmTokens/{token}` altına yazmak
///   (uid ile) → Cloud Function bildirimi bu listeye gönderir, kaydedenin
///   kendi cihazlarını uid'den eler.
/// - Token yenilenince kaydı tazelemek, ÇIKIŞTA kaydı silmek (elden çıkarılan
///   / oturumu kapatılan cihaza bildirim gitmesin).
/// - Ön planda (uygulama açıkken) gelen bildirimi göstermek: iOS sistem
///   bandını kendisi gösterir (presentation options), Android'de SnackBar.
/// - Bildirime DOKUNULUNCA o günün yoklamasını açmak ([pushTappedDate] →
///   dinleyicisi `MainShell`).
///
/// Neden serbest fonksiyon + doğrudan Firebase erişimi (writeStamp deseniyle
/// aynı gerekçe): testlerde bu dosya hiç çağrılmaz (main.dart'tan başlatılır,
/// testler YevmiyeApp'i fake repo'larla pump eder) → provider/enjeksiyon
/// gerekmez. Her adım try/catch'li: bildirim kurulumu uygulamayı asla düşürmez.
library;

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../firestore/refs.dart';
import '../firestore/write_ack.dart';
import '../firestore/write_stamp.dart';

/// MaterialApp'e verilen kök messenger — ön planda gelen push'u SnackBar
/// olarak göstermek için (yalnız Android; iOS sistem bandı gösterir).
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Kullanıcının dokunduğu bildirimin yoklama günü (`'yyyy-MM-dd'`); yoksa null.
///
/// Bildirim uygulamayı açtığında (kapalıyken ya da arka plandayken) burada
/// buluşulur: `MainShell` dinler, Yoklama sekmesine geçip o günü seçer ve
/// değeri null'a çeker (bir kez tüketilir). Testlerde bu dosya hiç
/// çalışmadığından değer daima null kalır → davranış değişmez.
final ValueNotifier<String?> pushTappedDate = ValueNotifier<String?>(null);

/// Bildirim izni verildi mi? Kurulum çalışana dek `null` ("bilinmiyor").
/// Yönetim ekranı bunu okuyup izin kapalıysa kullanıcıyı uyarır.
final ValueNotifier<bool?> pushPermissionGranted = ValueNotifier<bool?>(null);

/// Bu oturumda `fcmTokens` altına yazdığımız token (çıkışta silmek için).
String? _kayitliToken;

/// main()'den bir kez çağrılır (Firebase.initializeApp SONRASI, await'siz).
Future<void> initPushNotifications() async {
  // Yalnız telefon platformları; masaüstünde (macOS/linux) sessizce atla.
  if (!(Platform.isAndroid || Platform.isIOS)) return;
  try {
    final messaging = FirebaseMessaging.instance;

    // iOS: uygulama AÇIKKEN de bildirim sistem bandında görünsün.
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Girişten sonra (uid belli olunca) cihaz token'ını kaydet. Uygulama
    // açılışında oturum zaten varsa akış hemen mevcut kullanıcıyla başlar.
    // Oturum kapanınca (user == null) yalnız yerel iz temizlenir; kaydın
    // Firestore'dan SİLİNMESİ çıkış düğmesinde, oturum daha AÇIKKEN yapılır
    // (bkz. [releasePushToken]) — çıkıştan sonra yazma yetkisi kalmaz.
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        unawaited(_registerToken(messaging));
      } else {
        _kayitliToken = null;
      }
    });

    // Token yenilenirse kaydı tazele.
    messaging.onTokenRefresh.listen((_) => unawaited(_registerToken(messaging)));

    // Ön planda gelen bildirim: Android sistem bandı GÖSTERMEZ → SnackBar.
    FirebaseMessaging.onMessage.listen((message) {
      final n = message.notification;
      if (n == null || !Platform.isAndroid) return;
      final text = [n.title, n.body].whereType<String>().join(' — ');
      if (text.isEmpty) return;
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      );
    });

    // Bildirime dokunulunca o günün yoklamasını aç. İki yol var: uygulama
    // arka plandaydı (onMessageOpenedApp) ya da tamamen kapalıydı ve bildirim
    // onu açtı (getInitialMessage — açılışta bir kez okunur).
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
    unawaited(messaging.getInitialMessage().then((m) {
      if (m != null) _handleTap(m);
    }));
  } catch (_) {
    // Bildirim kurulum hatası uygulamayı asla etkilemesin (offline kutsal).
  }
}

/// Dokunulan bildirimin taşıdığı yoklama gününü [pushTappedDate]'e koyar.
/// Gün bilgisi yoksa (eski sürüm bildirimi) sessizce yok sayılır → uygulama
/// normal açılır.
void _handleTap(RemoteMessage message) {
  final date = message.data['tarih'];
  if (date is String && date.isNotEmpty) pushTappedDate.value = date;
}

/// Cihaz token'ını `fcmTokens/{token}` altına yazar (merge). Deterministik
/// doc ID = token → aynı cihaz çift kayıt olmaz; kullanıcı değişirse uid
/// üzerine yazılır.
Future<void> _registerToken(FirebaseMessaging messaging) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final permission = await messaging.requestPermission();
    final izinli =
        permission.authorizationStatus != AuthorizationStatus.denied;
    pushPermissionGranted.value = izinli;
    if (!izinli) return;

    final token = await _tokenAl(messaging);
    if (token == null) return;

    // Yazımdan ÖNCE işaretle: çevrimdışıyken kayıt yerel önbelleğe hemen
    // uygulanıp sonra senkronlanır, ama sunucu onayı (yani aşağıdaki Future)
    // gelmez. İşaret yazımın ardına bırakılsaydı çevrimdışı açılan oturumda
    // çıkışta kayıt silinmeden kalırdı.
    _kayitliToken = token;
    await awaitWriteAck(
      fcmTokensCol(FirebaseFirestore.instance).doc(token).set({
        'uid': user.uid,
        if (user.email != null) 'email': user.email,
        'platform': Platform.operatingSystem,
        ...writeStamp(),
      }, SetOptions(merge: true)),
    );
  } catch (_) {
    // Sessiz geç — push kaydı olmazsa uygulama normal çalışmaya devam eder.
  }
}

/// FCM token'ı alır; iOS'ta APNs token'ı hazır olana dek kısa süre bekler.
///
/// iOS'ta APNs kaydı izin verildikten SONRA birkaç saniye sürebilir; o anda
/// `getToken()` hata verir ya da boş döner. Tek denemede pes edilirse (eski
/// davranış) cihaz o oturum boyunca hiç kaydolmaz — yeni kurulumda, yani izin
/// diyaloğunun kabul edildiği ilk açılışta, tam da olan buydu. Kısa aralıklı
/// birkaç deneme bu yarışı kapatır; yine olmazsa sonraki açılışta/token
/// yenilenmesinde tekrar denenir.
Future<String?> _tokenAl(FirebaseMessaging messaging) async {
  for (var deneme = 0; deneme < 3; deneme++) {
    if (deneme > 0) await Future<void>.delayed(const Duration(seconds: 2));
    // Hata YUTULUR ve denemeye devam edilir: APNs hazır değilken getToken()
    // yalnız boş dönmez, istisna da atabilir; istisna dışarı sızsaydı tekrar
    // deneme hiç çalışmazdı.
    try {
      if (Platform.isIOS && await messaging.getAPNSToken() == null) continue;
      final token = await messaging.getToken();
      if (token != null) return token;
    } catch (_) {
      // Bu deneme olmadı; kısa bekleyip yeniden dene.
    }
  }
  return null;
}

/// Çıkış yapılmadan ÖNCE çağrılır (oturum hâlâ açıkken): cihazın token kaydını
/// siler → oturumu kapatılmış / elden çıkarılmış cihaza bir daha "yoklama
/// alındı" bildirimi düşmez.
///
/// Sıra önemli: `signOut()` sonrası kimlik kalmadığı için Firestore kuralı
/// silmeyi reddeder. Bu oturumda hiç token kaydedilmediyse (ör. izin verilmedi,
/// testler) anında ve Firebase'e hiç dokunmadan döner.
Future<void> releasePushToken() async {
  final token = _kayitliToken;
  if (token == null) return;
  _kayitliToken = null;
  try {
    // Çevrimdışıyken sunucu onayı gelmez; çıkışı bekletme (silme kuyrukta
    // kalır, bağlanınca gider).
    await awaitWriteAck(
        fcmTokensCol(FirebaseFirestore.instance).doc(token).delete());
    // Token'ı da geçersiz kıl: sonraki girişte yenisi alınır.
    await FirebaseMessaging.instance.deleteToken();
  } catch (_) {
    // Sessiz geç — silinemezse Cloud Function ilk başarısız gönderimde
    // "kayıtsız token" cevabıyla kaydı zaten temizler.
  }
}

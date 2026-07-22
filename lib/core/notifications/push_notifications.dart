/// Push bildirimi kurulumu (FCM) — "yoklama alındı" bildirimi altyapısı.
///
/// Görevleri:
/// - Girişten sonra cihazın FCM token'ını `fcmTokens/{token}` altına yazmak
///   (uid ile) → Cloud Function bildirimi bu listeye gönderir, kaydedenin
///   kendi cihazlarını uid'den eler.
/// - Token yenilenince kaydı tazelemek.
/// - Ön planda (uygulama açıkken) gelen bildirimi göstermek: iOS sistem
///   bandını kendisi gösterir (presentation options), Android'de SnackBar.
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
import '../firestore/write_stamp.dart';

/// MaterialApp'e verilen kök messenger — ön planda gelen push'u SnackBar
/// olarak göstermek için (yalnız Android; iOS sistem bandı gösterir).
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

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
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) unawaited(_registerToken(messaging));
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
  } catch (_) {
    // Bildirim kurulum hatası uygulamayı asla etkilemesin (offline kutsal).
  }
}

/// Cihaz token'ını `fcmTokens/{token}` altına yazar (merge). Deterministik
/// doc ID = token → aynı cihaz çift kayıt olmaz; kullanıcı değişirse uid
/// üzerine yazılır.
Future<void> _registerToken(FirebaseMessaging messaging) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final permission = await messaging.requestPermission();
    if (permission.authorizationStatus == AuthorizationStatus.denied) return;

    // iOS: APNs token'ı hazır değilse getToken hata verebilir → sonraki
    // açılışta / token yenilenince yeniden denenir.
    if (Platform.isIOS && await messaging.getAPNSToken() == null) return;

    final token = await messaging.getToken();
    if (token == null) return;

    await fcmTokensCol(FirebaseFirestore.instance).doc(token).set({
      'uid': user.uid,
      if (user.email != null) 'email': user.email,
      'platform': Platform.operatingSystem,
      ...writeStamp(),
    }, SetOptions(merge: true));
  } catch (_) {
    // Sessiz geç — push kaydı olmazsa uygulama normal çalışmaya devam eder.
  }
}

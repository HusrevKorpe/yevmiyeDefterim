/// Merkezi tanılama / hata günlüğü (Crashlytics sarmalayıcı).
///
/// **Amaç:** "uygulama bozuldu / şu olmadı" gibi bir durumu SONRADAN teşhis
/// edebilmek. main.dart yalnız ÇÖKMEYİ (fatal) yakalar; asıl sorunlar ise
/// genelde çökmez — bir yazma başarısız olur, kullanıcıya Türkçe uyarı çıkar
/// ve iz kalmaz. Bu modül o "sessiz" hataları da Firebase Crashlytics'e taşır:
///
/// - [logHandledError] : yakalanmış (çökmeyen) hatayı, işlem adı + ek bilgiyle
///   kaydeder. Console'da "non-fatal" olarak, hangi hesapta ve hataya giden
///   ekran iziyle birlikte görünür.
/// - [logBreadcrumb]   : ekran/işlem izi bırakır → çökme/hata raporunda "hataya
///   giden son adımlar" bu izlerden okunur.
/// - [setDiagnosticsUser] : oturum kimliğini (e-posta/uid) rapora işler →
///   hangi hesabın/cihazın başına geldiği Console'da görünür.
/// - [initDiagnostics] : main()'den bir kez; giriş/çıkış oldukça kimliği tazeler.
///
/// **Neden serbest fonksiyon + doğrudan Firebase (writeStamp deseniyle aynı):**
/// testlerde Firebase başlatılmaz. Buradaki HER çağrı baştan sona try/catch'e
/// sarılıdır → Crashlytics erişilemezse (test/başlatılmadı) sessizce no-op olur;
/// tanılama uygulamayı ASLA etkilemez, testleri bozmaz. Bu yüzden ek
/// provider/enjeksiyon gerekmez.
///
/// **Gizlilik:** loglara para tutarı / kişi adı YAZMA. Yalnız işlem adı ve
/// teknik kimlik (kayıt id'si, e-posta) — teşhis için yeterli, hassas değil.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Çökmeye yol açmayan (yakalanmış) bir hatayı kaydeder. Kullanıcıya zaten
/// arayüzde Türkçe uyarı gösterilir; bu çağrı SESSİZDİR ve arayüzü etkilemez.
///
/// [reason] işlemi tanımlar ("avans-ekle", "yoklama-kaydet"…) → Console'da
/// başlık olur, aramayı kolaylaştırır. [info] ek teknik anahtarlar (kayıt id'si
/// gibi) — para/isim gibi hassas veri KOYMA.
Future<void> logHandledError(
  Object error,
  StackTrace? stack, {
  required String reason,
  Map<String, Object?>? info,
}) async {
  try {
    final crashlytics = FirebaseCrashlytics.instance;
    if (info != null) {
      for (final entry in info.entries) {
        await crashlytics.setCustomKey(entry.key, '${entry.value}');
      }
    }
    await crashlytics.recordError(error, stack, reason: reason, fatal: false);
  } catch (_) {
    // Tanılama uygulamayı asla etkilemez; test/başlatılmadıysa sessiz geç.
  }
}

/// Ekran/işlem izi bırakır (Crashlytics "log"). Sonraki hata/çökme raporunda
/// hataya giden son adımlar bu izlerden okunur.
void logBreadcrumb(String message) {
  try {
    FirebaseCrashlytics.instance.log(message);
  } catch (_) {
    // Sessiz geç (test/başlatılmadı).
  }
}

/// Oturum kimliğini rapora işler → hangi hesap/cihaz olduğu Console'da görünür.
/// Giriş yoksa "anonim" olarak işaretlenir.
Future<void> setDiagnosticsUser({String? email, String? uid}) async {
  try {
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setUserIdentifier(uid ?? email ?? 'anonim');
    await crashlytics.setCustomKey('email', email ?? '-');
  } catch (_) {
    // Sessiz geç (test/başlatılmadı).
  }
}

/// main()'den bir kez çağrılır (Firebase.initializeApp SONRASI, await'siz).
/// Giriş/çıkış oldukça Crashlytics kullanıcı kimliğini günceller → her rapor
/// doğru hesaba etiketlenir.
void initDiagnostics() {
  try {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      setDiagnosticsUser(email: user?.email, uid: user?.uid);
    });
  } catch (_) {
    // Sessiz geç (test/başlatılmadı).
  }
}

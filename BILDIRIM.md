# Yoklama Push Bildirimi — Kurulum ve Kalan Adımlar

Yoklamada **"Kaydet"** düğmesine basılınca **diğer cihazlara** (kaydeden hariç)
"Yoklama alındı ✓ — 22 Temmuz Salı yoklaması kaydedildi (kullanıcı)" push
bildirimi gider. Uygulama kapalıyken bile telefonun bildirim çubuğuna düşer.

## Nasıl çalışır (özet)

1. Girişten sonra her cihaz FCM token'ını `workspaces/main/fcmTokens/{token}`
   altına yazar (uid ile) — `lib/core/notifications/push_notifications.dart`.
2. "Kaydet" → `workspaces/main/attendanceDays/{tarih}` işaret dokümanı yazılır
   (`markDaySaved`). Günde tek doküman; 60 sn içindeki tekrar basışlar tek
   bildirim sayılır.
3. Cloud Function (`functions/index.js` → `yoklamaBildirimi`) bu yazımı dinler,
   `fcmTokens` listesinden **kaydedenin uid'sine ait cihazları eleyip** kalanına
   bildirim gönderir. Geçersizleşen token kayıtlarını otomatik siler.
4. Uygulama AÇIKKEN gelen bildirim: iOS sistem bandında, Android'de SnackBar
   olarak görünür. Kapalıyken: normal push bildirimi.

Firestore kuralı DEĞİŞMEDİ — mevcut `match /{document=**}` kuralı yeni
koleksiyonları zaten kapsıyor; Console'dan kural yayınlamak GEREKMEZ.

## Senin yapman gerekenler (sırayla)

### 1) Blaze planına geç (Cloud Functions şartı)
- https://console.firebase.google.com/project/yevmiyedefterim-f8a83/usage/details
- "Planı yükselt" → **Blaze (kullandıkça öde)**. Kredi kartı ister; bu kullanım
  ölçeğinde (3 cihaz, günde 1-2 bildirim) aylık fatura fiilen **₺0** olur.
  İstersen bütçe uyarısı koy (ör. 1 $).

### 2) iOS için APNs anahtarı (.p8) oluştur ve Firebase'e yükle
1. https://developer.apple.com/account/resources/authkeys/list → **Keys → +**
2. Ad ver (ör. `YevmiyePush`), **Apple Push Notifications service (APNs)** kutusunu
   işaretle → Continue → Register → **.p8 dosyasını indir** (tek sefer inebilir,
   sakla) ve **Key ID**'yi not al. Team ID: `VJ96R83FLT`.
3. Firebase Console → Proje ayarları → **Cloud Messaging** sekmesi →
   "Apple uygulaması yapılandırması" → **APNs Kimlik Doğrulama Anahtarı → Yükle**
   → .p8 dosyası + Key ID + Team ID.

### 3) Firebase CLI'yı güncelle ve fonksiyonu yayınla
Kurulu CLI (12.6.0) eski; Node 22 runtime için güncelle:
```sh
brew upgrade firebase-cli        # (brew ile kuruluysa; olmadıysa: npm i -g firebase-tools)
cd ~/development/yevmiye_defterim
firebase deploy --only functions
```
- İlk deploy'da gerekli API'leri (Cloud Functions, Eventarc, Artifact Registry)
  açmak isteyecek → onayla.
- **"trigger location must match database"** benzeri hata verirse:
  Console → Firestore → veritabanı bölgesini öğren, `functions/index.js` içindeki
  `region: "europe-west1"` değerini o bölgeyle değiştir, tekrar deploy et.
- **DNS/ağ hatası** olursa (daha önce `firebaserules` API'sinde yaşandı):
  telefondan hotspot ile tekrar dene.

### 4) Uygulamayı 3 cihaza yeniden yükle
Yeni sürümü derleyip dağıt (TestFlight / APK). İlk açılışta bildirim izni sorar
→ **İzin ver**. Girişten sonra cihaz kendini `fcmTokens`'a kaydeder.

### 5) Test
- A cihazında Yoklama → **Kaydet** → B ve C cihazlarına birkaç saniye içinde
  "Yoklama alındı ✓" bildirimi düşmeli (A'ya düşmez — kaydeden o).
- Uygulama kapalıyken de dene. **Gerçek cihazda test et** (simülatörde push
  güvenilir çalışmaz).
- Gelmezse: Console → Functions → `yoklamaBildirimi` → Günlükler'e bak;
  Firestore'da `fcmTokens` altında cihaz kayıtları oluşmuş mu kontrol et.

## Kod tarafında yapılanlar (bilgi)

- `pubspec.yaml`: `firebase_messaging` eklendi.
- `lib/core/notifications/push_notifications.dart`: token kaydı + ön plan gösterimi.
- `lib/main.dart`: `initPushNotifications()` (await'siz, açılışı geciktirmez).
- `lib/app/app.dart`: kök `scaffoldMessengerKey` (Android ön plan SnackBar'ı).
- `attendance_repository.markDaySaved` + VM + Kaydet düğmesi bağlantısı.
- Android: `POST_NOTIFICATIONS` izni. iOS: `Runner.entitlements`
  (aps-environment) + `UIBackgroundModes: remote-notification` + Xcode
  `CODE_SIGN_ENTITLEMENTS` (3 config).
- `functions/`: `yoklamaBildirimi` Cloud Function; `firebase.json`'a
  `functions` bölümü eklendi.

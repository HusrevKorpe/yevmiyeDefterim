# Push Bildirimleri — Kurulum ve Kalan Adımlar

**Diğer cihazlara** (işlemi yapan hariç) iki olayda push bildirimi gider;
uygulama kapalıyken bile telefonun bildirim çubuğuna düşer:

| Olay | Bildirim |
| --- | --- |
| Yoklama → **Kaydet** | "Yoklama alındı ✓ — 22 Temmuz Salı yoklaması kaydedildi (kullanıcı)" |
| Yeni **avans** girilmesi | "Avans verildi 💵 — Mehmet Yılmaz'a ₺1.500 avans verildi (kullanıcı)" |

Avans bildirimi **yalnız yeni avans girilince** çıkar. Bilerek bildirim
üretmeyenler: avans **düzenleme/silme**, "Hesap görüldü" kapanışı ve o
kapanıştan kalan **devir** kaydı (yeni para verilmiş değil), ₺0'lık kalıntı
kayıtlar. Avans başka güne tarihlenmişse metnin sonuna o gün de eklenir
("— 5 Ağustos Çarşamba"). Avans ekranı ve tutarları kısıtlı ("para göremez")
hesapta da açık olduğundan bildirim tüm cihazlara gider.

## Nasıl çalışır (özet)

1. Girişten sonra her cihaz FCM token'ını `workspaces/main/fcmTokens/{token}`
   altına yazar (uid ile) — `lib/core/notifications/push_notifications.dart`.
   Çıkış yapılırken kayıt **silinir** (oturum hâlâ açıkken — `releasePushToken`),
   böylece elden çıkarılan cihaza bildirim gitmez.
2. "Kaydet" → `workspaces/main/attendanceDays/{tarih}` işaret dokümanı yazılır
   (`markDaySaved`). Günde tek doküman; **aynı kişinin** 60 sn içindeki tekrar
   basışları tek bildirim sayılır (ölçü sunucu damgası `updatedAt`; cihaz saati
   kullanılsaydı offline kuyrukta bekleyen kayıt "geçmişten geliyor" görünüp
   bildirimi sessizce yutardı).
3. Avansta ayrı işaret dokümanı YOK: avans kaydının kendisi tetikler
   (`advances/{id}` oluşması). Devir kayıtları id öneki (`devir-`), kalıntı
   kayıtlar da tutar/isim kontrolüyle elenir.
4. Cloud Function'lar (`functions/index.js` → `yoklamaBildirimi`,
   `avansBildirimi`) bu yazımları dinler, `fcmTokens` listesinden **işlemi
   yapanın uid'sine ait cihazları eleyip** kalanına bildirim gönderir (ortak
   `cihazlaraGonder`). Token kaydını yalnız token'a özgü hatalarda siler
   (`registration-token-not-registered` / `invalid-registration-token`);
   diğer hatalar günlüğe düşer — tek bir payload hatası bütün kayıtları
   süpürmesin.
5. Uygulama AÇIKKEN gelen bildirim: iOS sistem bandında, Android'de SnackBar
   olarak görünür. Kapalıyken: normal push bildirimi. **Bildirime dokununca**
   uygulama hedef ekranı açar (push'taki `data.tip`/`data.tarih` →
   `pushTapped` → `MainShell`): yoklamada o günün yoklaması, avansta Avanslar
   sekmesi.

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
- A cihazında **Avans Ver** → B ve C'ye "Avans verildi 💵 — ...'a ₺... avans
  verildi" düşmeli; dokununca Avanslar sekmesi açılmalı.
- Uygulama kapalıyken de dene. **Gerçek cihazda test et** (simülatörde push
  güvenilir çalışmaz).
- Gelmezse: Console → Functions → `yoklamaBildirimi` / `avansBildirimi` →
  Günlükler'e bak; Firestore'da `fcmTokens` altında cihaz kayıtları oluşmuş mu
  kontrol et.

## Kod tarafında yapılanlar (bilgi)

- `pubspec.yaml`: `firebase_messaging` eklendi.
- `lib/core/notifications/push_notifications.dart`: token kaydı + ön plan
  gösterimi + dokunma yönlendirmesi + çıkışta kayıt bırakma.
- `lib/main.dart`: `initPushNotifications()` (await'siz, açılışı geciktirmez).
- `lib/app/app.dart`: kök `scaffoldMessengerKey` (Android ön plan SnackBar'ı).
- `lib/app/main_shell.dart`: `pushTapped` dinleyicisi → yoklama bildiriminde
  gün seçilip Yoklama, avans bildiriminde Avanslar açılır.
- `lib/features/dashboard/...`: çıkıştan ÖNCE `releasePushToken()`.
- `lib/features/settings/...`: Yönetim'de "Bildirimler açık/kapalı" satırı.
- `attendance_repository.markDaySaved` + VM + Kaydet düğmesi bağlantısı.
- Android: `POST_NOTIFICATIONS` izni; bildirim ikonu
  (`res/drawable/ic_stat_yevmiye.xml`), rengi ve `yoklama` kanalı
  (manifest meta-data + `MainActivity.onCreate`) — bunlar olmadan durum
  çubuğunda beyaz kare çıkıyordu. iOS: `Runner.entitlements` (aps-environment)
  + `UIBackgroundModes: remote-notification` + Xcode `CODE_SIGN_ENTITLEMENTS`
  (3 config).
- `functions/`: `yoklamaBildirimi` + `avansBildirimi` Cloud Function'ları
  (ortak gönderim/token temizliği yardımcısı); `firebase.json`'a `functions`
  bölümü eklendi.

## Bildirim gelmiyorsa (kontrol sırası)

1. **iOS'ta hiç gelmiyor** → APNs .p8 anahtarı yüklendi mi (yukarıdaki adım 2)?
   Yüklenmeden iOS'a push gitmez.
2. **Debug'da geliyor, TestFlight'ta gelmiyor** → `ios/Runner/Runner.entitlements`
   içindeki `aps-environment` `development`. Xcode dağıtım için dışa aktarırken
   bunu normalde `production`'a çevirir; çevirmediyse (ör. elle imzalama)
   sandbox token'ıyla üretim APNs'e gidilir ve bildirim düşmez.
3. **Hiçbir cihaza gitmiyor** → Console → Functions → `yoklamaBildirimi`
   günlükleri: "hiçbir cihaza bildirim gitmedi" satırı varsa token'lar ölmüş
   demektir; cihazlar yeniden giriş yapınca kaydolur.
4. **Cihazın kaydı yok** → Firestore `workspaces/main/fcmTokens` altında o
   cihazın satırı var mı? Yoksa uygulamada Yönetim ekranındaki "Bildirimler"
   satırına bakın: kapalıysa telefon ayarlarından izin verin.

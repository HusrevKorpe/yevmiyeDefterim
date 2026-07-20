# Dağıtım Rehberi (Faz 5)

Bu dosya, uygulamayı 3 kullanıcının telefonuna ulaştırmak için gereken adımları
tutar. **Kodla ilgili kısım (marka adı, ikon, splash) bitti** — aşağıdaki adımlar
hesap/kimlik gerektirdiği için **elle** yapılır.

## Proje kimlikleri (hazır)
| Alan | Değer |
|---|---|
| Firebase project | `yevmiyedefterim-f8a83` |
| Paket adı / bundle id | `com.husrevkorpe.yevmiyedefterim` |
| Android App ID | `1:605554417931:android:567e8fe74341e34ac2020e` |
| iOS App ID | `1:605554417931:ios:60b3e6c6b360b5ecc2020e` |
| Sürüm | `1.0.0+1` (pubspec.yaml `version`) |

---

## Bu oturumda yapıldı ✅
- Marka adı her platformda **"Yevmiye Defterim"** (Android etiketi, iOS `CFBundleName`,
  web manifest/başlık). iOS ana ekran adı zaten doğruydu.
- **Uygulama ikonu:** `assets/icon/app_icon.png` (yeşil defter + tik) → iOS + Android
  (adaptive) + web ikonları üretildi. iOS 1024 ikonu **alpha'sız** (App Store şartı).
- **Splash ekranı:** marka yeşili `#2E7D32` + logo (`flutter_native_splash`).
- `flutter analyze` temiz, **181 test yeşil**.
- İkon/splash'i yeniden üretmek gerekirse:
  ```sh
  dart run flutter_launcher_icons
  dart run flutter_native_splash:create
  ```
  Kaynak görseli değiştirmek için: `assets/icon/app_icon.png` (tam-taşan) ve
  `assets/icon/app_icon_foreground.png` (adaptive/splash ön-planı). Çizim betiği yoksa
  elle 1024×1024 PNG koyup yukarıdaki komutları çalıştır.

---

## 1. Firebase Console: Auth + kullanıcılar + kurallar
> Konsol: https://console.firebase.google.com/project/yevmiyedefterim-f8a83

1. **Authentication → Sign-in method →** Email/Password'ı **etkinleştir**.
2. **Authentication → Users →** 3 kullanıcıyı elle ekle (açık kayıt kapalı):
   e-posta + geçici şifre. (Şifreyi kullanıcıya ilk girişte güvenli ilet.)
3. **Firestore kurallarını yayınla.** Repo'daki `firestore.rules` hazır.
   - **DNS engeli (Faz 0):** Bu yerel ağda `firebase deploy --only firestore:rules`
     çalışmaz (`firebaserules.googleapis.com` REFUSED). İki yol:
     - **Kolay:** Console → Firestore → **Rules** sekmesine `firestore.rules` içeriğini
       yapıştır → **Publish**.
     - **CLI istersen:** mobil hotspot'a bağlan **veya** DNS'i `8.8.8.8` yap, sonra:
       ```sh
       firebase deploy --only firestore:rules
       ```

---

## 2. Android → Firebase App Distribution (1 kullanıcı)
Firebase CLI (v12.6.0) kurulu. Release APK derle → App Distribution'a yükle.

```sh
# 1) Derle (debug imzası App Distribution için yeterli — Play Store değil)
flutter build apk --release
# Çıktı: build/app/outputs/flutter-apk/app-release.apk

# 2) Firebase'e giriş (bir kez)
firebase login

# 3) Dağıt (tester e-postasını kendi adresinle değiştir)
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app 1:605554417931:android:567e8fe74341e34ac2020e \
  --testers "android-kullanici@ornek.com" \
  --release-notes "Yevmiye Defterim 1.0.0 — ilk sürüm"
```
- İlk dağıtımda Console → **App Distribution**'ı etkinleştirmen istenebilir.
- Tester e-postasına davet gelir → **App Tester** uygulamasından indirir.
- **Opsiyonel — gerçek imza:** `android/app/build.gradle.kts` şu an release'i
  **debug anahtarıyla** imzalıyor (`// TODO`). App Distribution için sorun değil.
  İleride Play Store istersen `keystore` üret + `signingConfigs` ekle.

---

## 3. iOS → TestFlight (2 kullanıcı)
**Ön koşul:** Apple Developer Program üyeliği ($99/yıl).

```sh
# 1) IPA derle
flutter build ipa --release
# Çıktı: build/ios/ipa/*.ipa
```
2. **App Store Connect**'te uygulama kaydı oluştur (bundle id
   `com.husrevkorpe.yevmiyedefterim`).
3. IPA'yı yükle: **Transporter** uygulaması (App Store) **veya** Xcode →
   Organizer → Distribute App. (İlk kez Xcode ile açıp signing team seçmek gerekebilir:
   `open ios/Runner.xcworkspace`.)
4. **TestFlight → Internal Testing:** iki Apple ID'yi internal tester ekle.
   Internal test **beta inceleme beklemez**, anında dağıtılır.
5. **Crashlytics dSYM (Faz 4'ten devir):** sembolleştirme için Xcode build phase'ine
   dSYM upload run-script ekle. Eklemesen de crash yine gelir, sadece satır bilgisi olmaz.

---

## 4. Her yeni sürümde
`pubspec.yaml` → `version: 1.0.0+1` satırında **build numarasını (+1) artır**
(iOS/Android bunu `versionCode`/`CFBundleVersion` olarak kullanır; aynı numara reddedilir).
Örn ikinci yükleme: `version: 1.0.1+2`.

## 5. İlk giriş — SAHA NOTU (önemli)
Offline auth token için **her cihaz ilk girişi Wi-Fi/veri varken** yapmalı
(plan §8). Token alındıktan sonra tarlada internetsiz çalışır (Firestore offline
persistence açık).

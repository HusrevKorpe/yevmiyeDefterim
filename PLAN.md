# Yevmiye Defterim — Proje Planı

Tarım iş vereni için yevmiyeci (gündelikçi işçi) takip uygulaması.
İşçi yoklaması, maaş/hakediş hesabı, avans ve gelir/gider defteri.

## Kararlar (netleşti)
- **Teknoloji:** Flutter + Firebase
- **Platform:** iOS (2 telefon) + Android (1 telefon), toplam 3 kullanıcı, **tek ortak veri**
- **Elebaşı modeli:** Bireysel işçi takibi YOK. Elebaşı için her güne **kişi sayısı** girilir, elebaşıya **toplu ödeme** yapılır.
- **Yevmiye:** Kadın/erkek **farklı sabit** ücret (ayarlardan; işçi bazında override edilebilir).
- **Offline zorunlu:** Tarlada internet olmayabilir → Firestore offline persistence açık.

---

## 1. Teknoloji Yığını
| Alan | Paket | Neden |
|---|---|---|
| Backend | `firebase_core`, `firebase_auth`, `cloud_firestore` | Auth + veri + yerleşik offline |
| Crash raporu | `firebase_crashlytics` | 3 saha kullanıcısını uzaktan takip |
| State | `flutter_riverpod` + `riverpod_generator` | Firestore stream'leri ile birebir; az boilerplate |
| Yönlendirme | `go_router` (`StatefulShellRoute`) | Auth kapısı + kalıcı alt menü |
| Model | `freezed` + `json_serializable` | Değişmez modeller, otomatik `fromJson/toJson` |
| Format | `intl` + `flutter_localizations` | `tr_TR` tarih ve `₺` para formatı |
| ID | `uuid` | Cihazda ID üretimi → tam offline yazma |

> Sürümler kod aşamasında pub.dev'e göre sabitlenecek.

## 2. Klasör Yapısı (feature-first)
```
lib/
  main.dart                 # Firebase init, ProviderScope, offline persistence
  firebase_options.dart     # flutterfire configure üretir
  app/                      # app.dart, router.dart, theme.dart
  core/                     # money, date, firestore refs, ortak widget'lar
  features/
    auth/  workers/  attendance/  payroll/
    advances/  ledger/  settings/  dashboard/
      data/          # model + repository
      application/   # riverpod providers, hesaplama
      presentation/  # ekranlar
test/                       # payroll_calculator_test.dart (en kritik)
```

## 3. Firestore Veri Modeli
Tek ortak workspace altında iç içe koleksiyonlar (`workspaces/main/...`).

**Para = tam sayı kuruş** (1000₺ = 100000). Asla `double` kullanma.
**Tarih = yerel `'yyyy-MM-dd'` string** + sorgu için `ts: Timestamp`. Kullanıcı tarihi için `serverTimestamp` kullanma.

| Koleksiyon | Önemli alanlar |
|---|---|
| `settings/config` | `defaultWageMaleKurus`, `defaultWageFemaleKurus`, `defaultCrewRateKurus` |
| `workers/{uuid}` | `name`, `type` (sabit/gundelik/elebasi), `gender`, `dailyWageOverrideKurus?`, `active` (soft-delete) |
| `attendance/{date_workerId}` | **deterministik ID** → çift kayıt engellenir. `status` (full/half/absent), `wageSnapshotKurus` (o günkü ücret dondurulur); elebaşı için `headcount`, `crewRateSnapshotKurus`, `agreedPayKurus?` |
| `advances/{uuid}` | `workerId`, `amountKurus`, `date`, `settledPayrollId?` |
| `ledger/{uuid}` | `type` (income/expense), `category` (mazot/maas/elebasi/genel...), `amountKurus`, `source` (manual/payroll/elebasi) |
| `payrolls/{uuid}` | Dondurulmuş hakediş: `grossKurus`, `advancesDeductedKurus`, `netPaidKurus`, `status:paid`, `ledgerEntryId` |

**Offline & çoklu kullanıcı:** Yazmalar cihazda ID üreterek anında local cache'e yazılır, bağlanınca senkron olur. Aynı işçi/gün çakışması deterministik ID + `merge:true` ile "son yazan kazanır" olur (çift satır olmaz). Listeler `serverTimestamp` yerine `ts`/`clientUpdatedAt` ile sıralanır.

**Güvenlik:** Kural = `uid in workspace.memberUids`. Kurallar basit tutulur (offline yazma sonradan reddedilip geri alınmasın). 3 kullanıcı elle oluşturulur, açık kayıt kapalı.

## 4. Maaş / Hakediş Hesabı
Saf fonksiyon (`payroll_calculator.dart`, Firestore'suz → unit test edilir).

**Ücret çözümü:** `override ?? (erkek ? maleWage : femaleWage)` — ve bu değer **yoklama anında** `wageSnapshotKurus` olarak donar (sonradan ücret zammı geçmişi değiştirmez).

**Normal işçi:**
```
gross = Σ (full ? wage : half ? wage~/2 : 0)     # her günün snapshot ücreti
avans = Σ dönemdeki avanslar
net   = gross - avans        # negatifse: max(0,net) öde, kalan avans gelecek döneme devreder
```

**Öde:** Tek `WriteBatch` → (1) `payrolls` kaydı dondurulur, (2) `ledger` gider kaydı (`category:maas`, tutar=net), (3) kullanılan avanslara `settledPayrollId` yazılır.

**Elebaşı (ayrı):** Yarım gün/cinsiyet/avans yok. `günlük = agreedPay ?? headcount*crewRate`, dönem toplamı elebaşıya ödenir → `category:elebasi` gider. Hakediş ekranında "İşçiler" ve "Elebaşılar" iki ayrı bölüm.

**Çifte sayım yok:** Avanslar tek kaynak `advances`'te; payroll gider kaydı `net` tutar → `avans + net = gross` tam bir kez.

## 5. Ekranlar & Navigasyon (düşük teknoloji dostu)
5 büyük alt menü, Türkçe etiket + büyük ikon:

| Menü | Rota | İçerik |
|---|---|---|
| **Ana Sayfa** | `/` | Bugün özeti + dev "Bugün Yoklama Al" butonu |
| **Yoklama** | `/yoklama` | Tarih + işçi listesi; Tam/Yarım/Yok segmentli düğme; elebaşı için +/− kişi sayacı |
| **İşçiler** | `/isciler` | sabit/gündelik/elebaşı gruplu liste, ekle/düzenle |
| **Hakediş** | `/hakedis` | Dönem seç → kişi başı net → "Öde" |
| **Kasa** | `/kasa` | Gelir/Gider listesi + toplam; **Mazot** filtresi/ayrı ekran |

UX kuralları: büyük font/kontrast (yeşil=geldi, sarı=yarım, gri=yok), açılır menü yerine segment düğmeleri, sayı için +/− stepper, `₺` önekli sayısal klavye, her tehlikeli işlemde "Emin misiniz?", ikon+yazı birlikte, her yerde makul varsayılan (bugün).

## 6. Fazlar (yapım sırası)
- **Faz 0 — Kurulum:** `flutterfire configure`, paketler, ProviderScope + router + TR tema, offline persistence, auth kapısı, 3 kullanıcı + workspace seed. → Giriş yapıp boş iskelet.
- **Faz 1 — MVP:** Ayarlar (varsayılan ücretler), İşçiler CRUD, Yoklama (snapshot ücret, elebaşı kişi sayısı), Ana Sayfa özeti. → **Tarlada tam kullanılır çekirdek.**
- **Faz 2 — Hakediş + Avans:** hesaplayıcı + testler, avans CRUD, dönem hakediş, "Öde", devir mantığı, elebaşı ödemesi.
- **Faz 3 — Kasa:** Gelir/gider CRUD, kategoriler, Mazot ekranı, çifte-saymayan raporlama.
- **Faz 4 — Rapor & cila:** dönem özetleri, işçi geçmişi, düzenleme kilitleri, Crashlytics, (opsiyonel) PDF/CSV paylaşımı.
- **Faz 5 — Dağıtım:** ikon/splash/marka, TestFlight (iOS) + Firebase App Distribution (Android), 3 kullanıcı ilk girişi (Wi-Fi'da).

## 7. Dağıtım
- **Android (1):** Firebase App Distribution — ücretsiz, kolay. `flutter build apk` → CLI ile yükle → kullanıcı e-postası ekle.
- **iOS (2):** **Apple Developer Program ($99/yıl) gerekli.** Önerilen: **TestFlight internal** — iki Apple ID'yi tester ekle, `flutter build ipa` yükle, beta inceleme yok. (Alternatif: tek pipeline istersen App Distribution ad-hoc + UDID.)
- **Kurulum adımları:** `flutterfire configure` → `google-services.json` (Android) + `GoogleService-Info.plist` (iOS). Android `minSdk = 23`, iOS `platform :ios, '15.0'`. Konsolda Email/Password auth aç, 3 kullanıcı oluştur, Firestore production + güvenlik kuralları.

## 8. Riskler / Kenar Durumlar
- **Ödenmiş yoklamayı düzenleme:** payroll dondurulur; `paidThroughDate` ile eski tarih düzenlemede uyarı ver, otomatik değiştirme.
- **İşçi silme:** hard-delete yok → `active:false`. Geçmiş kayıtlar `workerId` + denormalize isimle korunur.
- **Zaman dilimi:** iş günü = kullanıcının seçtiği yerel `'yyyy-MM-dd'` (UTC gece yarısı değil).
- **Yuvarlama:** her yerde tam sayı kuruş; yarım gün = `wage~/2` (tam lira → kuruş çift → kayıpsız).
- **Offline auth:** yeni cihaz sahada çalışmadan önce bir kez Wi-Fi'da giriş yapmalı (token için).

## 9. Senden gerekenler (Faz 0 için)
1. **Firebase projesi** (Google hesabınla oluşturulacak) — `flutterfire configure` senin login'inle çalışır.
2. **Apple Developer Program** kaydı ($99/yıl) — iOS dağıtımı için.
3. **3 kullanıcının e-postaları** (giriş hesapları için) + iki iPhone'un Apple ID'leri.
4. **Varsayılan yevmiyeler:** erkek ... ₺ / kadın ... ₺, elebaşı kişi başı ... ₺ (müşteriden).

# kural.md — Yevmiye Defterim Kod Kuralları

Bu dosya projenin değişmez kurallarını tutar. Kod yazarken bu kurallara uyulur.
(Kullanıcı yeni kural anlattıkça en alttaki bölüme eklenir.)

---

## 1. Para (EN ÖNEMLİ)
- **Giriş TL cinsindendir.** Kullanıcı "2000" yazınca = **2000 TL** (2000 kuruş DEĞİL).
- Ondalık (kuruş) için **virgül**: "2000,50" = 2000 TL 50 kuruş.
- İç depolama HER ZAMAN **tam sayı kuruş**: `TL × 100`. Örn: 2000 TL → `200000`, 2000,50 → `200050`.
- Virgül yalnızca **giriş ve gösterim** içindir; hesap/depolama double DEĞİL, tam sayı kuruştur.
- Giriş → kuruş çevrimi tek bir yardımcıda (`core/money`): "2.000,50" gibi TR formatını (nokta=binlik, virgül=ondalık) parse eder.
- **Asla `double`/`float` ile para hesabı yapma.**
- Gösterim: `NumberFormat.currency(locale: 'tr_TR', symbol: '₺')`.
- Yarım gün = `wage ~/ 2` (tam sayı bölme).

## 2. Tarih
- İş günü = kullanıcının seçtiği **yerel** tarih, `'yyyy-MM-dd'` string.
- Yanına sorgu için `ts: Timestamp` yazılır.
- Kullanıcı tarihi için `serverTimestamp()` KULLANMA (offline'da null gelir).
- `createdAt/updatedAt` için `serverTimestamp()` + ayrıca `clientUpdatedAt` yaz (sıralama için).

## 3. Offline & Senkronizasyon (DİKKAT)
- Firestore offline persistence AÇIK, cache limitsiz.
- Doküman ID'leri **cihazda** üretilir (`uuid`), sunucudan beklenmez.
- Yoklama ID'si deterministik: `'{date}_{workerId}'` + `merge:true` → çift kayıt yok.
- Listeler `ts`/`clientUpdatedAt` ile sıralanır, `serverTimestamp` ile değil.
- Bekleyen yazma (`metadata.hasPendingWrites`) için "senkronize ediliyor" göstergesi.
- **Yazma kaybı olmayacak:** çoklu-yazma işlemleri (öde, avans kes, hakediş kapat) tek `WriteBatch`/`runTransaction`.
- İki cihaz aynı kaydı değiştirince "son yazan kazanır" bilinçli tercih; riskli yerde alan-bazlı `merge`, tüm dokümanı ezme.
- Toplam/sayaç değerleri okurken client'ta türetilir; sunucu-tarafı artırma (yarış durumu) YOK.
- Senkron mantığı ayrıca test edilir: offline yaz → online ol → tek kayıt, doğru değer.

## 4. Ücret dondurma
- Ücret yoklama anında `wageSnapshotKurus` olarak donar.
- Hesaplayıcı geçmiş ücreti asla yeniden türetmez, hep snapshot okur.
- Ücret çözümü: `override ?? (erkek ? maleWage : femaleWage)`.

## 5. Silme = soft-delete
- Hiçbir işçi/kayıt hard-delete edilmez → `active: false`.
- Geçmiş kayıtlar `workerId` + denormalize `name`/`workerType` ile korunur.
- Pasif işçiler yoklama ve seçim listelerinde görünmez, raporlarda görünür.

## 6. Çifte sayım yasak
- Avanslar tek kaynak: `advances` koleksiyonu. Ayrıca ledger'a yazılmaz.
- Payroll gider kaydı `net` tutardır → `avans + net = gross` tam bir kez.
- Kayıt kaynağı `source` alanıyla izlenir (manual/payroll/elebasi).

## 7. Mimari & kod stili
- **Feature-first** klasör: her feature `data / application / presentation`.
- **MVVM — her ekranın bir ViewModel'i var.** ViewModel = Riverpod `Notifier`/`AsyncNotifier` (`application/`).
  - Ekran (presentation) sadece state'i **okur** ve ViewModel metodunu **çağırır**; iş mantığı/Firestore çağrısı/hesap ekranda DEĞİL, ViewModel'de.
  - Repository'yi ViewModel çağırır; widget doğrudan repository'ye dokunmaz.
- **Hiçbir `.dart` dosyası 500 satırı geçmez.** Geçerse böl (widget'ı ayrı dosyaya al, extension/parçaya ayır).
- State: **Riverpod** (generator). Firestore stream → `StreamProvider`, ekran state → ViewModel Notifier.
- Modeller: **freezed**, değişmez (immutable).
- Hesaplama mantığı **saf fonksiyon** (Firestore'suz) → unit test edilir.
- Ekranlar `.dart` Türkçe rota adları (`/yoklama`, `/isciler`, `/hakedis`, `/kasa`).
- Sabitler `core/constants` içinde (koleksiyon adları, kategoriler) — string tekrar etme.

## 8. UI kuralları (düşük teknoloji dostu)
- Tüm metinler **Türkçe**.
- Büyük font/kontrast; yeşil=geldi, sarı=yarım, gri=yok.
- Açılır menü yerine **segment düğme**; sayı için **+/− stepper**.
- Her buton **ikon + yazı** (sadece ikon yok).
- Tehlikeli işlemde **"Emin misiniz?"** onayı.
- Makul varsayılan: yoklama/yeni kayıt bugünle açılır.

## 9. Güvenlik
- Firestore kuralı basit: `uid in workspace.memberUids`.
- Karmaşık kural yazma (offline yazma sonradan reddedilmesin).
- Açık kayıt kapalı, 3 kullanıcı elle oluşturulur.

## 10. Elebaşı (ayrı akış)
- Bireysel işçi takibi yok: her gün `headcount` girilir.
- `günlük = agreedPay ?? headcount * crewRate`.
- Elebaşıya toplu ödeme → `category: elebasi` gider.
- Hakediş ekranında "İşçiler" ve "Elebaşılar" ayrı bölüm.

---

## 11. Testler & Commit (DİKKAT)
- **Her commit'ten ÖNCE test çalıştır:** `flutter test` + `flutter analyze` yeşil olmadan commit YOK.
- Testler sağlam ve kapsamlı — özellikle ileride çıkabilecek **bug / gözden kaçan hatalar** için.
- Öncelikli test alanları:
  - **Para/hesap:** kuruş çevrimi, "2000"→200000, virgül parse ("2000,50"), yarım gün, avans düşme, negatif net.
  - **Senkronizasyon:** offline→online, deterministik ID, aynı gün iki cihaz → çift kayıt yok.
  - **Hakediş:** karışık ücretli dönem, elebaşı toplu ödeme, avans devri.
- Kenar durumlar test edilir: 0 gün, sadece yarım günler, avans > kazanç, pasif işçi, dönem sınırı tarihleri.
- Hesap/senkron mantığı **saf fonksiyon** tutulur ki gerçekçi ve kolay test edilsin.
- Kural: yeni özellik = yeni test. Bug bulundu = önce onu yakalayan test, sonra düzeltme.

---

## Kullanıcının anlattığı ham kurallar (kaynak)
Kullanıcıdan gelen maddeler; yukarıdaki bölümlere işlendi:
1. Hiçbir `.dart` dosyası 500 satırı geçmeyecek. → §7
2. Her yerde ViewModel kullan (MVVM). → §7
3. Her commit'ten önce testleri çalıştır; testler sağlam, ileri bug'ları yakalasın. → §11
4. En iyi kodu yaz; özellikle **senkronizasyona** dikkat. → §3
5. Giriş "2000" = 2000 TL; kuruşta virgül kullanılabilir ("2000,50"). → §1

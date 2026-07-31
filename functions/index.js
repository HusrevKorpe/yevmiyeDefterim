/**
 * Yoklama push bildirimi (plan: BILDIRIM.md).
 *
 * Tetik: uygulamada Yoklama > "Kaydet" → `workspaces/main/attendanceDays/{date}`
 * işaret dokümanı yazılır (attendance_repository.markDaySaved). Bu fonksiyon o
 * yazımı dinler ve `workspaces/main/fcmTokens` altındaki KAYDEDEN HARİÇ tüm
 * cihazlara "yoklama alındı" bildirimi gönderir.
 *
 * Notlar:
 * - Kaydedenin kendi cihaz(lar)ı `uid` karşılaştırmasıyla elenir → kendi
 *   bastığın Kaydet için sana bildirim gelmez, diğer cihazlara gider.
 * - AYNI kişinin aynı güne 60 sn içinde art arda bastığı Kaydet'ler tek
 *   bildirim sayılır. Ölçü SUNUCU damgasıdır (`updatedAt`), cihaz saati değil:
 *   `clientUpdatedAt` yazan telefonun saatidir, offline kuyrukta bekleyen bir
 *   yazım sonradan sunucuya düştüğünde ondan ÖNCEKİ kayıttan daha "eski"
 *   görünür (fark negatif) → susturma koşulu yanlışlıkla tutar ve bildirim
 *   sessizce yutulurdu. Farklı kişinin kaydı da hiç susturulmaz.
 * - Geçersiz/eskimiş token'lar gönderim cevabına göre silinir (kayıt temiz
 *   kalır). Silme YALNIZ token'a özgü hata kodlarında yapılır: `invalid-argument`
 *   bozuk MESAJ gövdesi için de dönebilir → onunla silinseydi tek bir payload
 *   hatası bütün cihaz kayıtlarını süpürürdü.
 * - Bölge: europe-west1. Deploy "trigger location must match database" hatası
 *   verirse Firestore veritabanının bölgesini yazın (Console > Firestore).
 */
const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

/** Aynı kişinin art arda basışlarını tek bildirime indiren pencere. */
const SUSTURMA_MS = 60_000;

/** Token kaydını silmeyi hak eden hatalar (yalnız token'a özgü olanlar). */
const OLU_TOKEN_KODLARI = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

/** TR ay adları (index 1-12). */
const AYLAR = ["", "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
  "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
/** TR gün adları (Date.getUTCDay(): 0 = Pazar). */
const GUNLER = ["Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe",
  "Cuma", "Cumartesi"];

/** "2026-07-22" → "22 Temmuz Salı" (bozuk tarihte olduğu gibi döner). */
function trTarih(iso) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso || "");
  if (!m) return iso || "";
  const [, y, mo, d] = m;
  const gun = GUNLER[new Date(Date.UTC(+y, +mo - 1, +d)).getUTCDay()];
  return `${+d} ${AYLAR[+mo]} ${gun}`;
}

/** Dokümanın SUNUCU yazma damgası (ms). Yoksa/çözülmemişse null. */
function sunucuDamgasiMs(data) {
  const t = data && data.updatedAt;
  return t && typeof t.toMillis === "function" ? t.toMillis() : null;
}

exports.yoklamaBildirimi = onDocumentWritten(
    {
      document: "workspaces/main/attendanceDays/{date}",
      region: "europe-west1",
    },
    async (event) => {
      const after = event.data && event.data.after && event.data.after.data();
      if (!after) return; // doküman silindi → bildirim yok

      const savedByUid = after.updatedByUid || null;

      // AYNI kişinin aynı güne art arda Kaydet'i: 60 sn içindeki tekrarı sustur.
      // Ölçü sunucu damgası; damga okunamıyorsa SUSTURMA (bildirimi kaçırmaktansa
      // fazladan göndermek yeğdir).
      const before = event.data.before && event.data.before.data();
      const oncekiMs = sunucuDamgasiMs(before);
      const simdikiMs = sunucuDamgasiMs(after);
      if (oncekiMs !== null &&
          simdikiMs !== null &&
          simdikiMs - oncekiMs < SUSTURMA_MS &&
          (before.updatedByUid || null) === savedByUid) {
        return;
      }

      const db = getFirestore();
      const snap = await db.collection("workspaces/main/fcmTokens").get();

      // Kaydedenin kendi cihazlarını ele; kalan token'lara gönder.
      const hedefler = snap.docs.filter((d) => d.get("uid") !== savedByUid);
      if (hedefler.length === 0) return;

      // Kaydedeni okunur adla söyle (e-postanın @ öncesi).
      const email = after.updatedByEmail || "";
      const kim = email.includes("@") ? email.split("@")[0] : "";

      const tokens = hedefler.map((d) => d.id);
      const cevap = await getMessaging().sendEachForMulticast({
        tokens,
        notification: {
          title: "Yoklama alındı ✓",
          body: `${trTarih(event.params.date)} yoklaması kaydedildi` +
              (kim ? ` (${kim})` : ""),
        },
        // Bildirime dokununca uygulama o günün yoklamasını açsın (uygulama
        // tarafı `message.data['tarih']`i okur — push_notifications.dart).
        data: {tip: "yoklama", tarih: event.params.date},
        apns: {payload: {aps: {sound: "default"}}},
        android: {notification: {sound: "default"}},
      });

      // Eskimiş/geçersiz token kayıtlarını sil (cihaz silindi / app kaldırıldı).
      // Diğer hatalar (payload/kimlik bilgisi vb.) kaydı SİLDİRMEZ, günlüğe düşer.
      const silinecek = [];
      cevap.responses.forEach((r, i) => {
        const kod = r.error && r.error.code;
        if (!kod) return;
        if (OLU_TOKEN_KODLARI.has(kod)) {
          silinecek.push(hedefler[i].ref.delete());
        } else {
          console.warn(`bildirim gönderilemedi (kayıt korundu): ${kod}`);
        }
      });
      await Promise.all(silinecek);

      if (cevap.successCount === 0) {
        console.error(
            `hiçbir cihaza bildirim gitmedi (${tokens.length} token denendi)`);
      }
    });

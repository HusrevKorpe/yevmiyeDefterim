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
 * - Aynı güne 60 sn içinde art arda basılan Kaydet'ler tek bildirim sayılır
 *   (clientUpdatedAt farkı ile susturulur).
 * - Geçersiz/eskimiş token'lar gönderim cevabına göre silinir (kayıt temiz kalır).
 * - Bölge: europe-west1. Deploy "trigger location must match database" hatası
 *   verirse Firestore veritabanının bölgesini yazın (Console > Firestore).
 */
const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

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

exports.yoklamaBildirimi = onDocumentWritten(
    {
      document: "workspaces/main/attendanceDays/{date}",
      region: "europe-west1",
    },
    async (event) => {
      const after = event.data && event.data.after && event.data.after.data();
      if (!after) return; // doküman silindi → bildirim yok

      // Aynı güne art arda Kaydet: 60 sn içindeki tekrarı sustur.
      const before = event.data.before && event.data.before.data();
      if (before &&
          typeof before.clientUpdatedAt === "number" &&
          typeof after.clientUpdatedAt === "number" &&
          after.clientUpdatedAt - before.clientUpdatedAt < 60_000) {
        return;
      }

      const savedByUid = after.updatedByUid || null;
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
        apns: {payload: {aps: {sound: "default"}}},
        android: {notification: {sound: "default"}},
      });

      // Eskimiş/geçersiz token kayıtlarını sil (cihaz silindi / app kaldırıldı).
      const silinecek = [];
      cevap.responses.forEach((r, i) => {
        const kod = r.error && r.error.code;
        if (kod === "messaging/registration-token-not-registered" ||
            kod === "messaging/invalid-argument") {
          silinecek.push(hedefler[i].ref.delete());
        }
      });
      await Promise.all(silinecek);
    });

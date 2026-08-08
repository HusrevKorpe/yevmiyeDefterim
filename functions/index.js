/**
 * Push bildirimleri (plan: BILDIRIM.md) — iki olay:
 *
 * 1. `yoklamaBildirimi`: Yoklama > "Kaydet" → `attendanceDays/{date}` işaret
 *    dokümanı yazılır (attendance_repository.markDaySaved).
 * 2. `avansBildirimi`: yeni avans dokümanı oluşturulur (`advances/{id}`).
 *
 * İkisi de `workspaces/main/fcmTokens` altındaki İŞLEMİ YAPAN HARİÇ tüm
 * cihazlara bildirim gönderir (ortak yardımcı: [cihazlaraGonder]).
 *
 * Notlar:
 * - İşlemi yapanın kendi cihaz(lar)ı `uid` karşılaştırmasıyla elenir → kendi
 *   yaptığın işlem için sana bildirim gelmez, diğer cihazlara gider.
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
const {onDocumentWritten,
  onDocumentCreated} = require("firebase-functions/v2/firestore");
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

/** İşlemi yapanı okunur adla söyler (e-postanın @ öncesi); yoksa "". */
function kimYapti(data) {
  const email = (data && data.updatedByEmail) || "";
  return email.includes("@") ? email.split("@")[0] : "";
}

/**
 * Kuruşu TR gösterimine çevirir: 150000 → "₺1.500", 150050 → "₺1.500,50".
 * Kuruş hanesi 0 ise yazılmaz (bildirim metni kısa kalsın).
 */
function trPara(kurus) {
  const negatif = kurus < 0;
  const mutlak = Math.abs(Math.round(kurus));
  const lira = String(Math.floor(mutlak / 100))
      .replace(/\B(?=(\d{3})+(?!\d))/g, ".");
  const kalan = mutlak % 100;
  const kurusStr = kalan === 0 ? "" : `,${String(kalan).padStart(2, "0")}`;
  return `${negatif ? "-" : ""}₺${lira}${kurusStr}`;
}

/** Türkçe ünlüler / kalın ünlüler (büyük İ ve I ayrı harflerdir). */
const UNLULER = "aeıioöuüAEIİOÖUÜ";
const KALIN_UNLULER = "aıouAIOU";

/**
 * İsmin yönelme ("-e") hâli: "Ahmet" → "Ahmet'e", "Hasan" → "Hasan'a",
 * "Ayşe" → "Ayşe'ye", "Mustafa" → "Mustafa'ya". Son ünlü kalınsa "a", inceyse
 * "e"; ad ünlüyle bitiyorsa araya kaynaştırma "y" girer. Hiç ünlü yoksa
 * (bozuk/kısaltma ad) ince ek varsayılır — metin yine okunur kalır.
 */
function eHali(ad) {
  const s = (ad || "").trim();
  if (!s) return "";
  let sonUnlu = "";
  for (let i = s.length - 1; i >= 0; i--) {
    if (UNLULER.includes(s[i])) {
      sonUnlu = s[i];
      break;
    }
  }
  const ek = KALIN_UNLULER.includes(sonUnlu) ? "a" : "e";
  const kaynastirma = UNLULER.includes(s[s.length - 1]) ? "y" : "";
  return `${s}'${kaynastirma}${ek}`;
}

/** Türkiye saatiyle bugünün ISO günü ("yyyy-MM-dd"); çözülemezse null. */
function istanbulBugun() {
  try {
    // en-CA yerel biçimi zaten "yyyy-MM-dd" üretir (ICU, Node 22'de tam).
    return new Date().toLocaleDateString("en-CA", {timeZone: "Europe/Istanbul"});
  } catch (_) {
    return null;
  }
}

/**
 * `fcmTokens` altındaki cihazlara bildirim gönderir; [gonderenUid]'ye ait
 * cihazlar elenir (kendi yaptığın işlem için sana bildirim gelmez).
 * Eskimiş token kayıtları temizlenir (bkz. dosya başı notu).
 */
async function cihazlaraGonder({gonderenUid, title, body, data}) {
  const db = getFirestore();
  const snap = await db.collection("workspaces/main/fcmTokens").get();

  const hedefler = snap.docs.filter((d) => d.get("uid") !== gonderenUid);
  if (hedefler.length === 0) return;

  const tokens = hedefler.map((d) => d.id);
  const cevap = await getMessaging().sendEachForMulticast({
    tokens,
    notification: {title, body},
    data,
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

      const kim = kimYapti(after);
      await cihazlaraGonder({
        gonderenUid: savedByUid,
        title: "Yoklama alındı ✓",
        body: `${trTarih(event.params.date)} yoklaması kaydedildi` +
            (kim ? ` (${kim})` : ""),
        // Bildirime dokununca uygulama o günün yoklamasını açsın (uygulama
        // tarafı `message.data['tarih']`i okur — push_notifications.dart).
        data: {tip: "yoklama", tarih: event.params.date},
      });
    });

/**
 * Avans bildirimi: yeni avans girilince diğer cihazlara "kime ne kadar avans
 * verildi" düşer. Tetik doküman OLUŞMASI (`onDocumentCreated`) — düzenleme ve
 * silme bilerek bildirim ÜRETMEZ (asıl olay paranın verilmesi).
 *
 * Bildirim ÜRETMEYEN oluşumlar:
 * - "Hesap görüldü" devir kaydı (`devir-` önekli id): yeni para verilmedi,
 *   kapanıştan kalan alacak sonraki hesaba taşındı — kullanıcıya "avans
 *   verildi" demek yanıltıcı olurdu.
 * - Tutarı 0/negatif ya da işçisiz kayıt: kapanış/geri alma batch'i, arada
 *   silinmiş bir avansa `set(merge)` yaparsa geriye ₺0'lık kozmetik "hayalet"
 *   doküman kalabilir (bkz. advance_repository.settleAdvances) → bildirime
 *   dönüşmesin.
 */
exports.avansBildirimi = onDocumentCreated(
    {
      document: "workspaces/main/advances/{id}",
      region: "europe-west1",
    },
    async (event) => {
      const doc = event.data && event.data.data();
      if (!doc) return;

      if (String(event.params.id || "").startsWith("devir-")) return;

      const tutar = typeof doc.amountKurus === "number" ? doc.amountKurus : 0;
      const isim = typeof doc.workerName === "string" ? doc.workerName.trim() : "";
      if (tutar <= 0 || isim === "") return;

      const kim = kimYapti(doc);
      const tarih = typeof doc.date === "string" ? doc.date : "";
      // Geçmişe/ileriye tarihli avansta günü de söyle; bugüne girilende metni
      // kalabalıklaştırma.
      const bugun = istanbulBugun();
      const gun = tarih && tarih !== bugun ? ` — ${trTarih(tarih)}` : "";

      await cihazlaraGonder({
        gonderenUid: doc.updatedByUid || null,
        title: "Avans verildi 💵",
        body: `${eHali(isim)} ${trPara(tutar)} avans verildi` +
            (kim ? ` (${kim})` : "") + gun,
        // Dokununca Avanslar sekmesi açılsın (push_notifications.dart).
        // `tarih` BİLEREK yok: cihazlardaki ESKİ sürüm yalnız `tarih` okur ve
        // onu yoklama günü sanar → avans bildirimine dokunulunca yanlışlıkla o
        // günün yoklamasını açardı. Alansız kalınca eski sürüm dokunuşu sessizce
        // yok sayar (uygulama normal açılır), yeni sürüm `tip`ten Avanslar'a
        // gider. Gün zaten bildirim METNİNDE yazıyor.
        data: {tip: "avans"},
      });
    });

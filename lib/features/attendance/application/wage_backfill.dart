/// Yevmiye değişince geçmiş yoklama günlerini yeniden fiyatlama (zam / eksik
/// fiyat).
///
/// Ücret yoklama ANINDA dondurulur (kural §4). Ama sahada yevmiye "o günden
/// sonrası" değil, GÖRÜLMEMİŞ HESABIN TAMAMI için değişir: elebaşına/işçiye zam
/// yapılınca, hesabı en son ne zaman görüldüyse ondan SONRAKİ bütün günler yeni
/// yevmiyeye geçer. Kapanmış (hesabı görülmüş) günler ise para el değiştirdiği
/// için asla oynatılmaz.
///
/// Sınır = son "Hesap görüldü" tarihi ([lastSettlementDate]); net bakiyeyi de bu
/// sınır belirler (bkz. `worker_history.dart`) → iki hesap aynı yerden bölünür.
/// Kapanış hiç yoksa tüm geçmiş açıktır ve tamamı yeni yevmiyeye geçer.
///
/// İstisna: kapanış GÜNÜ ve öncesindeki ₺0 (hiç fiyatlanmamış) günler. Onlar bir
/// "ücret" değil EKSİK VERİDİR (yevmiyesi girilmeden alınan yoklama) → kapanışın
/// arkasında kalsalar bile fiyatlanırlar; aksi halde o günler sonsuza dek ₺0
/// kalırdı.
///
/// Saf liste dönüşümü (Firestore'suz → unit test); yazma ayrı adımda ve
/// kullanıcı onayıyla yapılır.
library;

import '../../../core/firestore/write_ack.dart';
import '../data/attendance_record.dart';
import '../data/attendance_repository.dart';

/// [records] içinden [rateKurus] ile yeniden fiyatlanacak günlerin GÜNCELLENMİŞ
/// kopyalarını döndürür. Değişmesi gerekmeyen kayıt listeye girmez (boş liste →
/// yazılacak bir şey yok).
///
/// [settledThrough] son "Hesap görüldü" tarihi (`'yyyy-MM-dd'`); null → hiç
/// kapanış yok, tüm geçmiş açıktır. O tarihten SONRAKİ günler koşulsuz yeniden
/// fiyatlanır; o tarih ve öncesi yalnız ₺0 (fiyatlanmamış) ise fiyatlanır.
///
/// Atlananlar (bilerek):
/// * [rateKurus] ≤ 0 → fiyat yok, hiçbir şey yapılmaz.
/// * Zaten [rateKurus] ile dondurulmuş günler → yazacak bir şey yok.
/// * Kazanca girmeyen günler: "Yok" işaretli birey, 0 kişilik ekip → tutarları
///   zaten 0; yazmak boşuna (ve "bu ekip gelmedi" işaretini kirletirdi).
/// * Elebaşıda toplu anlaşma tutarı ([CrewAttendance.agreedPayKurus]) girilmiş
///   gün → kazanç kişi ücretinden türetilmiyor, dokunulmaz.
/// * Mesai saat ücreti ([IndividualAttendance.overtimeRateSnapshotKurus]) →
///   yevmiyeden ayrı bir sayıdır, günlük zam onu değiştirmez.
List<AttendanceRecord> repriceDays(
  List<AttendanceRecord> records,
  int rateKurus, {
  String? settledThrough,
}) {
  if (rateKurus <= 0) return const [];
  final out = <AttendanceRecord>[];
  for (final r in records) {
    // ISO tarih → sözlüksel karşılaştırma = kronolojik. Kapanış yoksa her gün
    // "kapanıştan sonra" sayılır (hesap hiç görülmemiş).
    final afterSettlement =
        settledThrough == null || r.date.compareTo(settledThrough) > 0;
    switch (r) {
      case IndividualAttendance(
          :final status,
          :final wageSnapshotKurus,
        ):
        if (status != AttendanceStatus.absent &&
            wageSnapshotKurus != rateKurus &&
            (afterSettlement || wageSnapshotKurus <= 0)) {
          out.add(r.copyWith(wageSnapshotKurus: rateKurus));
        }
      case CrewAttendance(
          :final headcount,
          :final crewRateSnapshotKurus,
          :final agreedPayKurus,
        ):
        if (headcount > 0 &&
            agreedPayKurus == null &&
            crewRateSnapshotKurus != rateKurus &&
            (afterSettlement || crewRateSnapshotKurus <= 0)) {
          out.add(r.copyWith(crewRateSnapshotKurus: rateKurus));
        }
    }
  }
  return out;
}

/// [workerId] işçisinin yeniden fiyatlanacak günlerini okur ve güncellenmiş
/// hallerini döndürür — HİÇBİR ŞEY YAZMAZ. Kullanıcıya "N gün güncellensin mi?"
/// diye sormak için önce bu çağrılır.
///
/// [settledThrough]: bkz. [repriceDays]. Çağıran, işçinin avanslarından
/// `lastSettlementDate` ile hesaplar.
Future<List<AttendanceRecord>> findRepriceableDays({
  required AttendanceRepository attendance,
  required String workerId,
  required int rateKurus,
  String? settledThrough,
}) async {
  if (rateKurus <= 0) return const [];
  final records = await attendance.getByWorker(workerId);
  return repriceDays(records, rateKurus, settledThrough: settledThrough);
}

/// [findRepriceableDays] sonucunu yazar; yazılan gün sayısını döndürür.
///
/// Yazımlar paralel gider ve onay [awaitWriteAck] ile sınırlı beklenir:
/// çevrimdışıyken kayıtlar yerel önbelleğe anında uygulanır, ekran kilitlenmez.
Future<int> applyRepricedDays({
  required AttendanceRepository attendance,
  required List<AttendanceRecord> records,
}) async {
  if (records.isEmpty) return 0;
  await awaitWriteAck(
    Future.wait([for (final r in records) attendance.save(r)]).then((_) {}),
  );
  return records.length;
}

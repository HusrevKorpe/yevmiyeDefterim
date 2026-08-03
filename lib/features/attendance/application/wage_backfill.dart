/// Ücreti girilmeden kaydedilmiş yoklama günlerini sonradan fiyatlama.
///
/// Ücret yoklama ANINDA dondurulur (kural §4) — geçmiş kazanç sonradan yapılan
/// zamlarla oynamasın diye. Ama işçi/elebaşı yevmiyesi HİÇ girilmemişken alınan
/// yoklama ₺0 dondurur ve bu bir "ücret" değil, EKSİK VERİDİR: kullanıcı
/// ücreti sonradan girince o günler ₺0 kalır ("fiyat ekledim ama görünmüyor").
///
/// Bu dosya yalnız ₺0 (fiyatlanmamış) günleri hedefler; gerçek bir ücretle
/// dondurulmuş hiçbir gün DEĞİŞTİRİLMEZ → kural §4 korunur. Saf liste dönüşümü
/// (Firestore'suz → unit test), yazma ayrı adımda ve kullanıcı onayıyla yapılır.
library;

import '../../../core/firestore/write_ack.dart';
import '../data/attendance_record.dart';
import '../data/attendance_repository.dart';

/// [records] içinden ücreti girilmemiş (₺0) günleri bulup [rateKurus] ile
/// fiyatlanmış KOPYALARINI döndürür. Değişmesi gerekmeyen kayıt listeye girmez
/// (boş liste → yazılacak bir şey yok).
///
/// Atlananlar (bilerek):
/// * [rateKurus] ≤ 0 → fiyat yok, hiçbir şey yapılmaz.
/// * Ücreti zaten dondurulmuş (>0) günler → kural §4, geçmiş ücret oynatılmaz.
/// * Kazanca girmeyen günler: "Yok" işaretli birey, 0 kişilik ekip → tutarları
///   zaten 0; yazmak boşuna (ve "bu ekip gelmedi" işaretini kirletirdi).
/// * Elebaşıda toplu anlaşma tutarı ([CrewAttendance.agreedPayKurus]) girilmiş
///   gün → kazanç kişi ücretinden türetilmiyor, dokunulmaz.
List<AttendanceRecord> repriceUnpricedDays(
  List<AttendanceRecord> records,
  int rateKurus,
) {
  if (rateKurus <= 0) return const [];
  final out = <AttendanceRecord>[];
  for (final r in records) {
    switch (r) {
      case IndividualAttendance(
          :final status,
          :final wageSnapshotKurus,
        ):
        if (status != AttendanceStatus.absent && wageSnapshotKurus <= 0) {
          out.add(r.copyWith(wageSnapshotKurus: rateKurus));
        }
      case CrewAttendance(
          :final headcount,
          :final crewRateSnapshotKurus,
          :final agreedPayKurus,
        ):
        if (headcount > 0 &&
            crewRateSnapshotKurus <= 0 &&
            agreedPayKurus == null) {
          out.add(r.copyWith(crewRateSnapshotKurus: rateKurus));
        }
    }
  }
  return out;
}

/// [workerId] işçisinin fiyatlanmamış günlerini okur ve [rateKurus] ile
/// fiyatlanmış hallerini döndürür — HİÇBİR ŞEY YAZMAZ. Kullanıcıya "N gün
/// güncellensin mi?" diye sormak için önce bu çağrılır.
Future<List<AttendanceRecord>> findUnpricedDays({
  required AttendanceRepository attendance,
  required String workerId,
  required int rateKurus,
}) async {
  if (rateKurus <= 0) return const [];
  final records = await attendance.getByWorker(workerId);
  return repriceUnpricedDays(records, rateKurus);
}

/// [findUnpricedDays] sonucunu yazar; yazılan gün sayısını döndürür.
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

/// Yoklama Riverpod sağlayıcıları (kural §7).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date.dart';
import '../../../core/firestore/firestore_providers.dart';
import '../data/attendance_record.dart';
import '../data/attendance_repository.dart';

/// Yoklama deposu. Testlerde `overrideWithValue(...)`.
final Provider<AttendanceRepository> attendanceRepositoryProvider =
    Provider<AttendanceRepository>(
  (ref) => FirestoreAttendanceRepository(ref.watch(firestoreProvider)),
);

/// Yoklama ekranının seçili günü (`'yyyy-MM-dd'`), varsayılan bugün.
class SelectedDateNotifier extends Notifier<String> {
  @override
  String build() => todayIso();

  void set(String isoDate) => state = isoDate;
  void shift(int days) => state = shiftIsoDate(state, days);
  void today() => state = todayIso();

  /// Gece yarısı devri: uygulama arka planda kalıp ertesi gün öne alınınca
  /// "bugün"e sabitlenen ekranlar dünü gösterir (bkz. [MainShell] yaşam
  /// döngüsü). Seçili gün HÂLÂ [previousDay] ise (kullanıcı elle başka güne
  /// gitmediyse) yeni güne kaydırır; elle seçilmiş geçmiş/gelecek gün KORUNUR.
  void rolloverIfOnDay(String previousDay) {
    if (state == previousDay) state = todayIso();
  }
}

final NotifierProvider<SelectedDateNotifier, String> selectedDateProvider =
    NotifierProvider<SelectedDateNotifier, String>(SelectedDateNotifier.new);

/// Yoklama düzenleme onayı: onay verilen gün (`'yyyy-MM-dd'`) burada tutulur.
///
/// Korumaya giren günler (bkz. attendance_screen): (a) "Kaydet"e basılmış gün
/// [daySavedForSelectedDateProvider] — gece yarısı beklenmez, kaydedildiği andan
/// itibaren; (b) bugün DIŞINDAKİ günler (hiç kaydedilmemiş olsa da). O günlerde
/// ilk değişiklik dokunuşu onay diyaloğundan geçer. Onaylanınca gün buraya
/// yazılır → aynı günde tekrar sorulmaz (bir düzeltme turunda her dokunuşta
/// diyalog çıkmasın). Başka güne geçilince eşleşme bozulur; "Kaydet"ten sonra
/// [relock] ile kilit geri kapanır → sonraki dokunuş yeniden sorar.
class AttendanceEditUnlockNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void unlock(String isoDate) => state = isoDate;

  /// Kilidi geri kapatır — "Kaydet" sonrası çağrılır: kaydedilmiş günde yapılan
  /// SONRAKİ değişiklik yeniden onay ister (kullanıcının istediği akış).
  void relock() => state = null;
}

final NotifierProvider<AttendanceEditUnlockNotifier, String?>
    attendanceEditUnlockedDateProvider =
    NotifierProvider<AttendanceEditUnlockNotifier, String?>(
        AttendanceEditUnlockNotifier.new);

/// Seçili günün "yoklama kaydedildi" işareti var mı (canlı, cihazlar arası).
///
/// "Kaydet"e basınca yazılan `attendanceDays/{date}` dokümanını dinler. Ekran
/// bunu düzenleme koruması için okur: kaydedilmiş güne dokunmak onay ister.
///
/// Değer AİT OLDUĞU TARİHLE birlikte taşınır: gün değişiminde stream yeniden
/// abone olurken önceki değer korunur (AsyncLoading + previous) → çıplak bir
/// `bool` bir an ÖNCEKİ günün işaretini gösterirdi (yanlış güne koruma ya da
/// korumasızlık). Tarih eşleşmesi bunu eler — view model'deki `_existing` ile
/// aynı desen.
final StreamProvider<({String date, bool saved})>
    daySavedForSelectedDateProvider =
    StreamProvider<({String date, bool saved})>((ref) {
  final date = ref.watch(selectedDateProvider);
  return ref
      .watch(attendanceRepositoryProvider)
      .watchDaySaved(date)
      .map((saved) => (date: date, saved: saved));
});

/// [daySavedForSelectedDateProvider]'ın senkron okunabilir hâli.
///
/// Yükleme/hata durumunda (ve değer başka güne aitken) `false` döner
/// (fail-open): işaret okunamadı diye yoklama girişi diyalogla tıkanmasın.
/// Ekran bunu `watch` eder (Kaydet düğmesinde ✓ rozeti) → dokunma anında değer
/// hazır olur.
final Provider<bool> selectedDaySavedProvider = Provider<bool>((ref) {
  final date = ref.watch(selectedDateProvider);
  final async = ref.watch(daySavedForSelectedDateProvider);
  if (!async.hasValue) return false;
  final v = async.requireValue;
  return v.date == date && v.saved;
});

/// Yoklama ekranındaki sekmeler (sıra ekrandaki sekme sırasıyla aynıdır).
enum AttendanceTab { males, females, crews }

/// Ana Sayfa özet kartından gelen "şu sekmeyi aç" isteği (2026-08-07).
///
/// Ana Sayfa'daki Kadın/Erkek/Elebaşı kartına dokunulunca istenen grup buraya
/// yazılır ve Yoklama sekmesine geçilir; Yoklama listesi isteği görüp o sekmeye
/// kayar ve isteği TÜKETİR ([consume]) → sekmeyi elle değiştirince geri
/// zıplamaz, aynı karta ikinci kez dokunmak yeniden çalışır.
class AttendanceTabRequestNotifier extends Notifier<AttendanceTab?> {
  @override
  AttendanceTab? build() => null;

  void request(AttendanceTab tab) => state = tab;
  void consume() => state = null;
}

final NotifierProvider<AttendanceTabRequestNotifier, AttendanceTab?>
    attendanceTabRequestProvider =
    NotifierProvider<AttendanceTabRequestNotifier, AttendanceTab?>(
        AttendanceTabRequestNotifier.new);

/// Seçili günün yoklama kayıtları.
final StreamProvider<List<AttendanceRecord>> attendanceForSelectedDateProvider =
    StreamProvider<List<AttendanceRecord>>((ref) {
  final date = ref.watch(selectedDateProvider);
  return ref.watch(attendanceRepositoryProvider).watchByDate(date);
});

/// Seçili günün kayıtları `workerId → kayıt` haritası olarak.
///
/// Yoklama satırları (tile) bu haritayı `.select` ile dinler → bir işçiye
/// dokunmak (Firestore write → stream re-emit) yalnız O TILE'ı yeniden çizer,
/// tüm listeyi değil (kural §7: dar kapsamlı rebuild). Harita her emisyonda bir
/// kez kurulur; tile'lar O(1) `map[workerId]` ile kendi durumunu seçer.
///
/// `.valueOrNull` (asData yerine): gün değişiminde stream yeniden abone olurken
/// (AsyncLoading) önceki değer korunur → segmentler bir kare "boşalıp" dolmaz
/// (seçim titremesi yok). Yeni günün verisi (offline önbellekten anında) gelince
/// harita güncellenir.
final Provider<Map<String, AttendanceRecord>> attendanceByWorkerForDateProvider =
    Provider<Map<String, AttendanceRecord>>((ref) {
  final async = ref.watch(attendanceForSelectedDateProvider);
  // hasValue: gün değişiminde (yeniden abonelik) önceki veri korunur → requireValue
  // önceki günü döndürür, segmentler bir kare "boşalmaz". Hata/ilk yükleme (önceki
  // değer yok) → boş harita: eski `.asData?.value ?? []` gibi hatayı yutar, tile'lar
  // patlamaz (value getter önceki-değersiz hatada rethrow ederdi — ondan kaçınılır).
  final records =
      async.hasValue ? async.requireValue : const <AttendanceRecord>[];
  return {for (final r in records) r.workerId: r};
});

/// Bugünün yoklama kayıtları — Ana Sayfa özeti için (seçili tarihten bağımsız).
final StreamProvider<List<AttendanceRecord>> todayAttendanceProvider =
    StreamProvider<List<AttendanceRecord>>(
  (ref) => ref.watch(attendanceRepositoryProvider).watchByDate(todayIso()),
);

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
}

final NotifierProvider<SelectedDateNotifier, String> selectedDateProvider =
    NotifierProvider<SelectedDateNotifier, String>(SelectedDateNotifier.new);

/// Geçmiş gün düzenleme onayı: onay verilen gün (`'yyyy-MM-dd'`) burada tutulur.
///
/// Yoklamada bugün DIŞINDAKİ bir güne ilk değişiklik dokunuşu onay
/// diyaloğundan geçer (yanlışlıkla dokunup geçmişi bozma koruması,
/// bkz. attendance_screen). Onaylanınca gün buraya yazılır → aynı günde tekrar
/// sorulmaz (dünün yoklamasını topluca girerken her dokunuşta diyalog çıkmasın).
/// Başka güne geçilince eşleşme bozulur, onay yeniden istenir.
class PastEditUnlockNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void unlock(String isoDate) => state = isoDate;
}

final NotifierProvider<PastEditUnlockNotifier, String?>
    pastEditUnlockedDateProvider =
    NotifierProvider<PastEditUnlockNotifier, String?>(
        PastEditUnlockNotifier.new);

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

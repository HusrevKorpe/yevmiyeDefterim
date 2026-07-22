/// Yoklama ViewModel'i (kural §7: MVVM; §4: yoklama anında ücret dondurma).
///
/// Ekran durum/sayı değiştirince buradaki metotları çağırır; ücret çözümü ve
/// snapshot burada yapılır, ekranda değil. State = son hata mesajı (yoksa null).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ids/ids.dart';
import '../../settings/application/settings_providers.dart';
import '../../settings/data/app_settings.dart';
import '../../workers/application/workers_providers.dart';
import '../../workers/data/worker.dart';
import '../data/attendance_record.dart';
import '../data/field.dart';
import 'attendance_providers.dart';
import 'wage.dart';

class AttendanceViewModel extends Notifier<String?> {
  @override
  String? build() => null;

  // --- ÖDEME KİLİDİ ŞİMDİLİK RAFTA (hakediş ile birlikte) ---
  // Ödenmiş (hakedişe girmiş) gün düzenlenemez — donmuş hakedişi bozmamak için
  // (kural §3, §6; plan §8 riski). UI'da tile kilitliydi; bu VM guard'ı savunma
  // derinliğiydi. Hakedişi geri açınca aşağıdaki sabiti ve setStatus/setHeadcount
  // içindeki guard'ları birlikte aç (mevcut kayıt okuma: [_existing]).
  // static const String _paidLockMessage = 'Bu gün ödendiği için düzenlenemez.';
  // --- /ÖDEME KİLİDİ ---

  /// Seçili günde bu işçinin mevcut yoklama kaydı (yoksa null). Durum/sayı
  /// değişiminde tarla seçimini korumak ve [setField]'de kaydı bulmak için
  /// okunur (ekran bu haritayı zaten canlı tutar).
  AttendanceRecord? _existing(String workerId) =>
      ref.read(attendanceByWorkerForDateProvider)[workerId];

  AppSettings get _settings =>
      ref.read(settingsStreamProvider).asData?.value ?? AppSettings.empty;

  /// Bireysel işçinin durumunu yazar; o günkü ücreti dondurur (kural §4).
  Future<void> setStatus(Worker worker, AttendanceStatus status) async {
    // --- ÖDEME KİLİDİ ŞİMDİLİK RAFTA (hakediş ile birlikte) ---
    // Hakedişi geri açınca bu guard'ı da aç:
    // if (_existing(worker.id)?.isPaid ?? false) {
    //   state = _paidLockMessage;
    //   return;
    // }
    final date = ref.read(selectedDateProvider);
    final settings = _settings;
    final wage = resolveWageKurus(
      gender: worker.gender,
      overrideKurus: worker.dailyWageOverrideKurus,
      maleWageKurus: settings.defaultWageMaleKurus,
      femaleWageKurus: settings.defaultWageFemaleKurus,
    );
    // Durum değişimi tarla seçimini bozmaz — mevcut kayıttan taşınır.
    final existing = _existing(worker.id);
    await _save(AttendanceRecord.individual(
      id: attendanceDocId(date, worker.id),
      date: date,
      workerId: worker.id,
      workerName: worker.name,
      workerType: worker.type,
      status: status,
      wageSnapshotKurus: wage,
      fieldId: existing?.fieldId,
      fieldName: existing?.fieldName,
    ));
  }

  /// Bireysel işçinin bugünkü kaydını siler → hiçbir durum seçili değil.
  /// Yoklama alınmayan (veya geri alınan) gün "Yok" sayılmaz, hiç kayıt tutulmaz
  /// ve hiçbir hesaba girmez. Segment düğmesinde seçili durumu boşaltır.
  Future<void> clearStatus(Worker worker) async {
    final date = ref.read(selectedDateProvider);
    try {
      await ref
          .read(attendanceRepositoryProvider)
          .delete(attendanceDocId(date, worker.id));
    } catch (_) {
      state = 'Kaydedilemedi. Tekrar deneyin.';
    }
  }

  /// Elebaşının kişi sayısını yazar; o günkü kişi ücretini dondurur.
  Future<void> setHeadcount(Worker worker, int headcount) async {
    // --- ÖDEME KİLİDİ ŞİMDİLİK RAFTA (hakediş ile birlikte) ---
    // Hakedişi geri açınca bu guard'ı da aç:
    // if (_existing(worker.id)?.isPaid ?? false) {
    //   state = _paidLockMessage;
    //   return;
    // }
    final date = ref.read(selectedDateProvider);
    final count = headcount < 0 ? 0 : headcount;
    // Sayı değişimi tarla seçimini bozmaz — mevcut kayıttan taşınır.
    final existing = _existing(worker.id);
    await _save(AttendanceRecord.crew(
      id: attendanceDocId(date, worker.id),
      date: date,
      workerId: worker.id,
      workerName: worker.name,
      headcount: count,
      crewRateSnapshotKurus: _settings.defaultCrewRateKurus,
      fieldId: existing?.fieldId,
      fieldName: existing?.fieldName,
    ));
  }

  /// O günün kaydına çalışılan tarlayı yazar; `field == null` seçimi kaldırır.
  /// Seçim İSTEĞE BAĞLIDIR ("kim nerede çalıştı" bilgisi); ad denormalize
  /// dondurulur (kural §5) — tarla sonradan silinse de geçmiş okunur kalır.
  ///
  /// Bireysel işçide çipler ancak Tam/Yarım seçiliyken görünür → kayıt yoksa
  /// sessiz no-op. Elebaşında kayıt yoksa önden dolu görünen mevcut (crewSize)
  /// tarlayla birlikte kesinleştirilir (+/- dokunuşuyla aynı davranış).
  Future<void> setField(Worker worker, Field? field) async {
    final existing = _existing(worker.id);
    if (existing == null) {
      if (worker.type.isCrew && worker.crewSize > 0) {
        final date = ref.read(selectedDateProvider);
        await _save(AttendanceRecord.crew(
          id: attendanceDocId(date, worker.id),
          date: date,
          workerId: worker.id,
          workerName: worker.name,
          headcount: worker.crewSize,
          crewRateSnapshotKurus: _settings.defaultCrewRateKurus,
          fieldId: field?.id,
          fieldName: field?.name,
        ));
      }
      return;
    }
    await _save(switch (existing) {
      IndividualAttendance() =>
        existing.copyWith(fieldId: field?.id, fieldName: field?.name),
      CrewAttendance() =>
        existing.copyWith(fieldId: field?.id, fieldName: field?.name),
    });
  }

  /// "Kaydet" dokunuşunda çağrılır. Yoklamada elebaşı sayacı, işçiye kayıtlı
  /// ekip mevcuduyla (crewSize) ÖNDEN DOLU görünür ama o değer henüz Firestore'a
  /// yazılmamıştır (kullanıcı yanlışlıkla iş olmayan güne kayıt düşürmesin diye).
  /// Bu metot, seçili günde henüz kaydı OLMAYAN her aktif elebaşının öntanımlı
  /// mevcudunu kalıcı yazar. Zaten kaydı olan (elle değiştirilmiş) elebaşı EZİLMEZ;
  /// kişi sayısı girilmemiş (crewSize == 0) elebaşı atlanır.
  Future<void> commitCrewDefaults() async {
    final records =
        ref.read(attendanceForSelectedDateProvider).asData?.value ?? const [];
    final recorded = {for (final r in records) r.workerId};
    for (final w in ref.read(activeWorkersProvider)) {
      if (!w.type.isCrew || w.crewSize <= 0 || recorded.contains(w.id)) {
        continue;
      }
      await setHeadcount(w, w.crewSize);
    }
  }

  /// "Kaydet" dokunuşunda günün işaret dokümanını yazar → Cloud Function
  /// DİĞER cihazlara "yoklama alındı" push bildirimi gönderir. Bilerek
  /// beklenmeden (unawaited) çağrılır: offline'da Firestore yazım Future'ı
  /// sunucu onayına dek tamamlanmaz; bildirim işareti UI'ı asla bekletmemeli.
  Future<void> markDaySaved() async {
    try {
      await ref
          .read(attendanceRepositoryProvider)
          .markDaySaved(ref.read(selectedDateProvider));
    } catch (_) {
      // Bildirim işareti yazılamazsa sessiz geç — yoklama verisi etkilenmez.
    }
  }

  Future<void> _save(AttendanceRecord record) async {
    try {
      await ref.read(attendanceRepositoryProvider).save(record);
    } catch (_) {
      state = 'Kaydedilemedi. Tekrar deneyin.';
    }
  }
}

final NotifierProvider<AttendanceViewModel, String?> attendanceViewModelProvider =
    NotifierProvider<AttendanceViewModel, String?>(AttendanceViewModel.new);

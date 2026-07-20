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
import 'attendance_providers.dart';
import 'wage.dart';

class AttendanceViewModel extends Notifier<String?> {
  @override
  String? build() => null;

  // --- ÖDEME KİLİDİ ŞİMDİLİK RAFTA (hakediş ile birlikte) ---
  // Ödenmiş (hakedişe girmiş) gün düzenlenemez — donmuş hakedişi bozmamak için
  // (kural §3, §6; plan §8 riski). UI'da tile kilitliydi; bu VM guard'ı savunma
  // derinliğiydi. Hakedişi geri açınca aşağıdaki sabiti + `_existing()` yardımcısını
  // ve setStatus/setHeadcount içindeki guard'ları birlikte aç.
  // static const String _paidLockMessage = 'Bu gün ödendiği için düzenlenemez.';
  //
  // /// Seçili günde bu işçinin mevcut yoklama kaydı (yoksa null).
  // AttendanceRecord? _existing(String workerId) {
  //   final records =
  //       ref.read(attendanceForSelectedDateProvider).asData?.value ?? const [];
  //   for (final r in records) {
  //     if (r.workerId == workerId) return r;
  //   }
  //   return null;
  // }
  // --- /ÖDEME KİLİDİ ---

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
    await _save(AttendanceRecord.individual(
      id: attendanceDocId(date, worker.id),
      date: date,
      workerId: worker.id,
      workerName: worker.name,
      workerType: worker.type,
      status: status,
      wageSnapshotKurus: wage,
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
    await _save(AttendanceRecord.crew(
      id: attendanceDocId(date, worker.id),
      date: date,
      workerId: worker.id,
      workerName: worker.name,
      headcount: count,
      crewRateSnapshotKurus: _settings.defaultCrewRateKurus,
    ));
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

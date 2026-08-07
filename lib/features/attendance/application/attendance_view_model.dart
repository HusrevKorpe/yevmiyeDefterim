/// Yoklama ViewModel'i (kural §7: MVVM; §4: yoklama anında ücret dondurma).
///
/// Ekran durum/sayı değiştirince buradaki metotları çağırır; ücret çözümü ve
/// snapshot burada yapılır, ekranda değil. State = son hata mesajı (yoksa null).
///
/// Yazmalar [awaitWriteAck] ile sarılır (avans VM'iyle aynı desen): offline'da
/// Firestore yazım Future'ı sunucu onayına dek tamamlanmaz; sarmalayıcı en fazla
/// birkaç saniye bekler → "Kaydet" onayı (SnackBar) askıda kalmaz, yazım yerel
/// kuyruğa girip arkaplanda senkronlanır.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date.dart';
import '../../../core/diagnostics/app_log.dart';
import '../../../core/firestore/write_ack.dart';
import '../../../core/ids/ids.dart';
import '../../settings/application/settings_providers.dart';
import '../../settings/data/app_settings.dart';
import '../../workers/application/workers_providers.dart';
import '../../workers/data/worker.dart';
import '../data/attendance_record.dart';
import '../data/job.dart';
import '../data/plot.dart';
import 'attendance_providers.dart';
import 'wage.dart';

class AttendanceViewModel extends Notifier<String?> {
  @override
  String? build() => null;

  /// Seçili günde bu işçinin mevcut yoklama kaydı (yoksa null). Durum/sayı
  /// değişiminde iş/tarla/ücret snapshot'ını korumak ve [setJob]/[setPlot]'ta
  /// kaydı bulmak için okunur (ekran bu haritayı zaten canlı tutar).
  ///
  /// Gün değişimi penceresinde harita bir kare ÖNCEKİ günün kaydını tutabilir
  /// (attendanceByWorkerForDateProvider "önceki değeri koru" der). O stale kaydı
  /// kullanmak (a) [setJob]/[setPlot]'ta yanlış güne yazar (existing.id eski gün)
  /// ve (b) durum/sayı değişiminde eski günün ücret/iş/tarla snapshot'ını yeni
  /// güne taşırdı. Tarih uyuşmuyorsa "kayıt yok" say → ilk kayıt gibi davran.
  AttendanceRecord? _existing(String workerId) {
    final r = ref.read(attendanceByWorkerForDateProvider)[workerId];
    if (r == null || r.date != ref.read(selectedDateProvider)) return null;
    return r;
  }

  AppSettings get _settings =>
      ref.read(settingsStreamProvider).asData?.value ?? AppSettings.empty;

  /// Elebaşının o günkü kişi başı ücretini (kuruş) çözer → yoklama anında
  /// dondurulur (kural §4). Artık kaynak işçinin kendi kişi-başı yevmiyesidir
  /// (dailyWageOverrideKurus); girilmemişse eski ayar varsayılanına düşer
  /// (defaultCrewRate rafta → pratikte 0).
  int _crewRate(Worker worker) =>
      worker.dailyWageOverrideKurus ?? _settings.defaultCrewRateKurus;

  /// Bireysel işçinin durumunu yazar; o günkü ücreti dondurur (kural §4).
  Future<void> setStatus(Worker worker, AttendanceStatus status) async {
    final date = ref.read(selectedDateProvider);
    final existing = _existing(worker.id);
    // Kayıt zaten VARSA dondurulmuş ücreti KORU: ücret yoklama ANINDA dondurulur
    // (kural §4); sonradan durumu (Tam↔Yarım) düzeltmek YENİ bir dondurma anı
    // değildir. İşçinin yevmiyesi bu arada değiştirilmiş olsa bile geçmiş günün
    // kazancı sabit kalmalı (aksi halde eski günü düzenlemek kazancı sessizce
    // güncel orana çekerdi). İlk kayıtta güncel ücret çözülüp dondurulur.
    //
    // Dondurulmuş ₺0 İSTİSNA (mesai ücretiyle aynı mantık): yevmiyesi HİÇ
    // girilmemişken alınan yoklama ₺0 dondurur — bu bir ücret değil, eksik
    // veridir. Korunsaydı "önce yoklama aldım, sonra yevmiyeyi girdim"
    // akışında gün sonsuza dek ₺0 kalırdı. 0 ise güncel ücret çözülür.
    final wage = existing is IndividualAttendance && existing.wageSnapshotKurus > 0
        ? existing.wageSnapshotKurus
        : resolveWageKurus(
            gender: worker.gender,
            overrideKurus: worker.dailyWageOverrideKurus,
            maleWageKurus: _settings.defaultWageMaleKurus,
            femaleWageKurus: _settings.defaultWageFemaleKurus,
          );
    // Mesai de durum değişiminde KORUNUR (tarla gibi) — ama "Yok" işaretlenirse
    // TEMİZLENİR: gelmeyen işçinin mesaisi olamaz. Aksi halde ekranda görünmeyen
    // (mesai şeridi yalnız Tam/Yarım'da açık) bir mesai ücreti kazançta kalır →
    // hayalet para.
    final keepOvertime =
        status != AttendanceStatus.absent && existing is IndividualAttendance;
    // Durum değişimi iş/tarla seçimini bozmaz — mevcut kayıttan taşınır.
    await _save(AttendanceRecord.individual(
      id: attendanceDocId(date, worker.id),
      date: date,
      workerId: worker.id,
      workerName: worker.name,
      workerType: worker.type,
      status: status,
      wageSnapshotKurus: wage,
      overtimeHours: keepOvertime ? existing.overtimeHours : 0,
      overtimeRateSnapshotKurus:
          keepOvertime ? existing.overtimeRateSnapshotKurus : 0,
      jobId: existing?.jobId,
      jobName: existing?.jobName,
      plotId: existing?.plotId,
      plotName: existing?.plotName,
    ));
  }

  /// O günün kaydına mesai (fazla çalışma) saatini yazar; `hours == 0` mesaiyi
  /// kaldırır. Saat ücreti (Yönetim'deki genel ücret ya da işçinin kendi
  /// istisnası — bkz. [resolveOvertimeRateKurus]) yoklama ANINDA dondurulur
  /// (kural §4, yevmiyeyle aynı mantık): sonradan ücreti değiştirmek geçmiş
  /// günün mesai tutarını oynatmaz.
  ///
  /// Mesai şeridi ekranda yalnız Tam/Yarım seçiliyken görünür → kayıt yoksa (ya
  /// da elebaşı kaydıysa) sessiz no-op; mesai tek başına gün yaratmaz.
  Future<void> setOvertimeHours(Worker worker, int hours) async {
    final existing = _existing(worker.id);
    if (existing is! IndividualAttendance) return;
    final h =
        hours < 0 ? 0 : (hours > kMaxOvertimeHours ? kMaxOvertimeHours : hours);
    // Mesai kaldırıldıysa dondurulmuş saat ücretini de sıfırla: yeniden mesai
    // girilirse o an YENİ bir dondurma anıdır (güncel ücret okunur).
    //
    // Ücret zaten donmuşsa (>0) korunur. 0 ise (mesai ilk kez giriliyor ya da o
    // sırada işçinin saat ücreti henüz girilmemişti) güncel ücret çözülür →
    // "önce mesai girdim, sonra saat ücretini yazdım" akışında sonraki dokunuş
    // doğru tutarı dondurur.
    final rate = h == 0
        ? 0
        : (existing.overtimeRateSnapshotKurus > 0
            ? existing.overtimeRateSnapshotKurus
            : resolveOvertimeRateKurus(
                workerHourlyKurus: worker.overtimeHourlyKurus,
                defaultHourlyKurus: _settings.overtimeHourlyKurus,
              ));
    await _save(existing.copyWith(
      overtimeHours: h,
      overtimeRateSnapshotKurus: rate,
    ));
  }

  /// Bireysel işçinin bugünkü kaydını siler → hiçbir durum seçili değil.
  /// Yoklama alınmayan (veya geri alınan) gün "Yok" sayılmaz, hiç kayıt tutulmaz
  /// ve hiçbir hesaba girmez. Segment düğmesinde seçili durumu boşaltır.
  Future<void> clearStatus(Worker worker) async {
    final date = ref.read(selectedDateProvider);
    try {
      await awaitWriteAck(ref
          .read(attendanceRepositoryProvider)
          .delete(attendanceDocId(date, worker.id)));
    } catch (e, s) {
      state = 'Kaydedilemedi. Tekrar deneyin.';
      await logHandledError(e, s,
          reason: 'yoklama-sil', info: {'workerId': worker.id, 'tarih': date});
    }
  }

  /// Elebaşının kişi sayısını yazar; o günkü kişi ücretini dondurur.
  ///
  /// Sayı 0'a indirilince kayıt SİLİNMEZ, 0-kişilik kayıt kalıcı yazılır — bu
  /// "bu ekip bugün gelmedi" işaretidir. Silseydik elebaşı yeniden ÖNDEN DOLU
  /// (crewSize) görünür ve "Kaydet" [commitCrewDefaults] ile öntanımlı mevcudu
  /// sessizce geri yazardı (hayalet gider). 0-kişilik kayıt kazanca (0 × ücret),
  /// aylık tabloya ve işçi-detayına GİRMEZ (headcount>0 koruması) → görünmez ama
  /// öntanımlının geri yazılmasını engeller.
  Future<void> setHeadcount(Worker worker, int headcount) async {
    final date = ref.read(selectedDateProvider);
    final count = headcount < 0 ? 0 : headcount;
    final existing = _existing(worker.id);
    // Kayıt zaten VARSA dondurulmuş kişi ücretini KORU (kural §4): kişi sayısını
    // düzeltmek YENİ bir dondurma anı değildir. İşçinin kişi-başı yevmiyesi bu
    // arada değiştirilmiş olsa bile geçmiş günün oranı sabit kalmalı. İlk kayıtta
    // güncel oran dondurulur (commitCrewDefaults'un önden-dolu yazımı dahil).
    //
    // Dondurulmuş ₺0 İSTİSNA: elebaşı kişi-başı yevmiyesi İSTEĞE BAĞLI (işçi
    // kartında boş bırakılabilir) → ücretsiz açılan elebaşının günleri ₺0
    // dondurur. Ücret sonradan girilince o 0 korunsaydı sayacı oynatmak bile
    // günü ₺0'da bırakırdı ("fiyat ekledim, görünmüyor"). 0 = fiyatlanmamış.
    final rate = existing is CrewAttendance && existing.crewRateSnapshotKurus > 0
        ? existing.crewRateSnapshotKurus
        : _crewRate(worker);
    // Sayı değişimi iş/tarla seçimini bozmaz — mevcut kayıttan taşınır.
    await _save(AttendanceRecord.crew(
      id: attendanceDocId(date, worker.id),
      date: date,
      workerId: worker.id,
      workerName: worker.name,
      headcount: count,
      crewRateSnapshotKurus: rate,
      jobId: existing?.jobId,
      jobName: existing?.jobName,
      plotId: existing?.plotId,
      plotName: existing?.plotName,
    ));
  }

  /// O günün kaydına YAPILAN İŞİ yazar; `job == null` seçimi kaldırır.
  /// Tarla seçimine dokunmaz (ikisi bağımsızdır).
  Future<void> setJob(Worker worker, Job? job) => _setTag(
        worker,
        (r) => switch (r) {
          IndividualAttendance() =>
            r.copyWith(jobId: job?.id, jobName: job?.name),
          CrewAttendance() => r.copyWith(jobId: job?.id, jobName: job?.name),
        },
        jobId: job?.id,
        jobName: job?.name,
      );

  /// O günün kaydına çalışılan TARLAYI yazar; `plot == null` seçimi kaldırır.
  /// Yapılan iş seçimine dokunmaz (ikisi bağımsızdır).
  Future<void> setPlot(Worker worker, Plot? plot) => _setTag(
        worker,
        (r) => switch (r) {
          IndividualAttendance() =>
            r.copyWith(plotId: plot?.id, plotName: plot?.name),
          CrewAttendance() => r.copyWith(plotId: plot?.id, plotName: plot?.name),
        },
        plotId: plot?.id,
        plotName: plot?.name,
      );

  /// [setJob]/[setPlot] ortak gövdesi. Seçim İSTEĞE BAĞLIDIR; ad denormalize
  /// dondurulur (kural §5) — iş/tarla sonradan silinse de geçmiş okunur kalır.
  ///
  /// Bireysel işçide çipler ancak Tam/Yarım seçiliyken görünür → kayıt yoksa
  /// sessiz no-op. Elebaşında kayıt yoksa önden dolu görünen mevcut (crewSize)
  /// seçimle birlikte kesinleştirilir (+/- dokunuşuyla aynı davranış).
  Future<void> _setTag(
    Worker worker,
    AttendanceRecord Function(AttendanceRecord) apply, {
    String? jobId,
    String? jobName,
    String? plotId,
    String? plotName,
  }) async {
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
          crewRateSnapshotKurus: _crewRate(worker),
          jobId: jobId,
          jobName: jobName,
          plotId: plotId,
          plotName: plotName,
        ));
      }
      return;
    }
    await _save(apply(existing));
  }

  /// "Kaydet" dokunuşunda çağrılır. Yoklamada elebaşı sayacı, işçiye kayıtlı
  /// ekip mevcuduyla (crewSize) ÖNDEN DOLU görünür ama o değer henüz Firestore'a
  /// yazılmamıştır (kullanıcı yanlışlıkla iş olmayan güne kayıt düşürmesin diye).
  /// Bu metot, seçili günde henüz kaydı OLMAYAN her aktif elebaşının öntanımlı
  /// mevcudunu kalıcı yazar. Zaten kaydı olan (elle değiştirilmiş) elebaşı EZİLMEZ;
  /// kişi sayısı girilmemiş (crewSize == 0) elebaşı atlanır.
  Future<void> commitCrewDefaults() async {
    // ÖNTANIMLI YAZMA YALNIZ BUGÜN. Geçmiş bir güne öntanımlı elebaşı mevcudu
    // (crewSize) YAZMA — o gün o ekiplerin gerçekten gelip gelmediğini bilmiyoruz.
    // Geçmiş günde "Kaydet" (geçmiş-gün onayından geçtikten sonra) çalışmamış tüm
    // elebaşıları crewSize × yevmiye ile kayda geçirir → HAYALET GİDER (aylık
    // tabloya, rapora ve net bakiyeye girer). Geçmiş gündeki elle düzeltmeler
    // (+/- dokunuşu) zaten anında kaydedilir; öntanımlı toplu-yazma yalnız bugünün
    // "tek dokunuşla ekipleri onayla" akışı içindir.
    if (ref.read(selectedDateProvider) != todayIso()) return;
    // Günün kayıtları HENÜZ YÜKLENMEDİYSE hiçbir öntanımlı yazma. `asData`,
    // AsyncLoading'de (gün değişiminde yeniden abonelik / ilk yükleme; önceki
    // değer tutulsa bile) null döner. Eski `?? const []` bunu "kayıt yok" sanıp
    // TÜM elebaşları öntanımlı mevcutla EZERDİ → elle girilen kişi sayısı sessizce
    // kaybolurdu. Yüklenince Kaydet tekrar çalışır (bkz. attendanceByWorkerForDateProvider).
    final data = ref.read(attendanceForSelectedDateProvider).asData;
    if (data == null) return;
    final records = data.value;
    final recorded = {for (final r in records) r.workerId};
    // Kaydı olmayan (önden dolu) elebaşı öntanımlıları PARALEL yazılır (sıralı
    // await yerine): N elebaşı tek turda gider — çevrimiçi N ard-arda gidiş-dönüş
    // beklenmez, offline'da da awaitWriteAck sınırıyla toplu birkaç saniyede
    // döner (askıda kalmaz). Yazılacak biri yoksa anında döner → onay gecikmez.
    final pending = [
      for (final w in ref.read(activeWorkersProvider))
        if (w.type.isCrew && w.crewSize > 0 && !recorded.contains(w.id)) w,
    ];
    await Future.wait([for (final w in pending) setHeadcount(w, w.crewSize)]);
  }

  /// "Kaydet" dokunuşunda günün işaret dokümanını yazar → Cloud Function
  /// DİĞER cihazlara "yoklama alındı" push bildirimi gönderir. Bilerek
  /// beklenmeden (unawaited) çağrılır: offline'da Firestore yazım Future'ı
  /// sunucu onayına dek tamamlanmaz; bildirim işareti UI'ı asla bekletmemeli.
  Future<void> markDaySaved() async {
    try {
      await awaitWriteAck(ref
          .read(attendanceRepositoryProvider)
          .markDaySaved(ref.read(selectedDateProvider)));
    } catch (e, s) {
      // Bildirim işareti yazılamazsa yoklama verisi etkilenmez; yalnız diğer
      // cihazlara push gitmez → teşhis için sessizce Crashlytics'e düşer.
      await logHandledError(e, s, reason: 'yoklama-push-isareti');
    }
  }

  Future<void> _save(AttendanceRecord record) async {
    try {
      await awaitWriteAck(ref.read(attendanceRepositoryProvider).save(record));
    } catch (e, s) {
      state = 'Kaydedilemedi. Tekrar deneyin.';
      await logHandledError(e, s,
          reason: 'yoklama-kaydet',
          info: {'workerId': record.workerId, 'tarih': record.date});
    }
  }
}

final NotifierProvider<AttendanceViewModel, String?> attendanceViewModelProvider =
    NotifierProvider<AttendanceViewModel, String?>(AttendanceViewModel.new);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/core/date/app_date.dart';
import 'package:yevmiye_defterim/core/ids/ids.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_view_model.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/attendance/data/job.dart';
import 'package:yevmiye_defterim/features/attendance/data/plot.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_providers.dart';
import 'package:yevmiye_defterim/features/settings/data/app_settings.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../../support/fake_attendance_repository.dart';
import '../../support/fake_settings_repository.dart';
import '../../support/fake_worker_repository.dart';

/// ViewModel + depo entegrasyonu: ücret dondurma (kural §4) ve deterministik
/// ID ile çift kayıt olmaması (kural §3, §11).
void main() {
  const settings = AppSettings(
    defaultWageMaleKurus: 200000,
    defaultWageFemaleKurus: 180000,
    defaultCrewRateKurus: 150000,
  );

  const male = Worker(
    id: 'w1',
    name: 'Ahmet',
    type: WorkerType.gundelik,
    gender: Gender.male,
  );

  late FakeAttendanceRepository attendance;
  late FakeSettingsRepository settingsRepo;
  late ProviderContainer container;

  Future<void> boot(AppSettings s) async {
    attendance = FakeAttendanceRepository();
    settingsRepo = FakeSettingsRepository(s);
    container = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWithValue(settingsRepo),
      attendanceRepositoryProvider.overrideWithValue(attendance),
    ]);
    // Ayar akışını canlı tut ve ilk değeri yükle (ViewModel senkron okur).
    container.listen(settingsStreamProvider, (_, _) {});
    await container.read(settingsStreamProvider.future);
  }

  Future<void> waitUntil(bool Function() cond) async {
    for (var i = 0; i < 200; i++) {
      if (cond()) return;
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    fail('Koşul zaman aşımına uğradı');
  }

  AttendanceViewModel vm() =>
      container.read(attendanceViewModelProvider.notifier);

  tearDown(() => container.dispose());

  test('tam gün → snapshot erkek yevmiye, kazanç tam, isim denormalize', () async {
    await boot(settings);
    await vm().setStatus(male, AttendanceStatus.full);

    expect(attendance.count, 1);
    final r = attendance.all.single as IndividualAttendance;
    expect(r.wageSnapshotKurus, 200000);
    expect(r.earningKurus, 200000);
    expect(r.workerName, 'Ahmet');
    expect(r.date, r.id.split('_').first); // id = {date}_{workerId}
  });

  test('aynı işçi-gün iki kez işaretlenince tek kayıt (deterministik ID)',
      () async {
    await boot(settings);
    await vm().setStatus(male, AttendanceStatus.full);
    await vm().setStatus(male, AttendanceStatus.half);

    expect(attendance.count, 1); // çift kayıt YOK
    final r = attendance.all.single as IndividualAttendance;
    expect(r.status, AttendanceStatus.half); // son yazan kazanır
    expect(r.earningKurus, 100000);
  });

  test('clearStatus: kaydı siler → gün hiç sayılmaz (otomatik Yok yok)',
      () async {
    await boot(settings);
    await vm().setStatus(male, AttendanceStatus.full);
    expect(attendance.count, 1);

    await vm().clearStatus(male);

    expect(attendance.count, 0); // kayıt silindi → gün boş, hesaba girmez
    expect(container.read(attendanceViewModelProvider), isNull); // hata yok
  });

  test('clearStatus: hiç kaydı olmayan işçide sorunsuz (no-op)', () async {
    await boot(settings);
    await vm().clearStatus(male);
    expect(attendance.count, 0);
    expect(container.read(attendanceViewModelProvider), isNull);
  });

  test('kadın işçi → kadın yevmiyesi snapshot alınır', () async {
    await boot(settings);
    const female = Worker(
      id: 'w2',
      name: 'Zehra',
      type: WorkerType.sabit,
      gender: Gender.female,
    );
    await vm().setStatus(female, AttendanceStatus.full);
    final r = attendance.all.single as IndividualAttendance;
    expect(r.wageSnapshotKurus, 180000);
  });

  test('override, cinsiyet ücretini ezerek snapshot alınır', () async {
    await boot(settings);
    const overridden = Worker(
      id: 'w3',
      name: 'Veli',
      type: WorkerType.sabit,
      gender: Gender.male,
      dailyWageOverrideKurus: 250000,
    );
    await vm().setStatus(overridden, AttendanceStatus.full);
    final r = attendance.all.single as IndividualAttendance;
    expect(r.wageSnapshotKurus, 250000);
  });

  test('elebaşı kişi sayısı → ayar kişi ücreti snapshot + kazanç (override yok)',
      () async {
    await boot(settings);
    const boss = Worker(
      id: 'e1',
      name: 'Usta',
      type: WorkerType.elebasi,
      gender: Gender.male,
    );
    await vm().setHeadcount(boss, 4);
    final r = attendance.all.single as CrewAttendance;
    expect(r.crewRateSnapshotKurus, 150000);
    expect(r.headcount, 4);
    expect(r.earningKurus, 600000);
  });

  test('elebaşı kişi başı yevmiyesi (override) kişi sayısıyla çarpılır', () async {
    // Ayar kişi ücreti rafta (0) olsa da işçinin kendi kişi-başı yevmiyesi kullanılır.
    await boot(const AppSettings(
      defaultWageMaleKurus: 200000,
      defaultWageFemaleKurus: 180000,
      defaultCrewRateKurus: 0,
    ));
    const boss = Worker(
      id: 'e1',
      name: 'Hüsrev',
      type: WorkerType.elebasi,
      gender: Gender.male,
      defaultHeadcount: 20,
      dailyWageOverrideKurus: 100000, // ₺1.000 kişi başı
    );
    await vm().setHeadcount(boss, 20);
    final r = attendance.all.single as CrewAttendance;
    expect(r.crewRateSnapshotKurus, 100000); // işçinin yevmiyesi donduruldu
    expect(r.headcount, 20);
    expect(r.earningKurus, 2000000); // 20 × ₺1.000 = ₺20.000
  });

  // "Kaydet" → önden dolu (henüz kaydı olmayan) elebaşı öntanımlı mevcutları
  // (crewSize) o güne yazılır; elle girilmiş kayıt ezilmez; kişi sayısı
  // girilmemiş elebaşı atlanır (İşçiler'de girilen ekip sayısı yoklamaya gelsin).
  // Öntanımlı yazma YALNIZ BUGÜN olur → seçili gün bugün alınır (bkz. bug #1).
  test('commitCrewDefaults: kaydı olmayan elebaşı crewSize ile yazılır', () async {
    final workers = FakeWorkerRepository();
    attendance = FakeAttendanceRepository();
    settingsRepo = FakeSettingsRepository(settings);
    container = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWithValue(settingsRepo),
      attendanceRepositoryProvider.overrideWithValue(attendance),
      workerRepositoryProvider.overrideWithValue(workers),
    ]);
    container.listen(settingsStreamProvider, (_, _) {});
    await container.read(settingsStreamProvider.future);

    // A: 10 kişilik ekip, kaydı yok → 10 yazılmalı.
    const bossA = Worker(
      id: 'eA',
      name: 'A Ustası',
      type: WorkerType.elebasi,
      gender: Gender.male,
      defaultHeadcount: 10,
    );
    // B: 5 kişilik ekip ama bugün elle 2 girilmiş → ezilmemeli.
    const bossB = Worker(
      id: 'eB',
      name: 'B Ustası',
      type: WorkerType.elebasi,
      gender: Gender.male,
      defaultHeadcount: 5,
    );
    // C: kişi sayısı girilmemiş (crewSize 0) → atlanmalı.
    const bossC = Worker(
      id: 'eC',
      name: 'C Ustası',
      type: WorkerType.elebasi,
      gender: Gender.male,
    );
    await workers.add(bossA);
    await workers.add(bossB);
    await workers.add(bossC);
    await workers.add(male); // bireysel işçi → elebaşı akışına girmemeli

    container.read(selectedDateProvider.notifier).set(todayIso());
    await vm().setHeadcount(bossB, 2); // B için elle kayıt

    // Sağlayıcıları canlı tut + ilk emisyonu bekle (ViewModel senkron okur).
    container.listen(workersStreamProvider, (_, _) {});
    await container.read(workersStreamProvider.future);
    container.listen(attendanceForSelectedDateProvider, (_, _) {});
    await container.read(attendanceForSelectedDateProvider.future);

    await vm().commitCrewDefaults();

    final crew = {
      for (final r in attendance.all.whereType<CrewAttendance>())
        r.workerId: r
    };
    expect(crew['eA']?.headcount, 10); // önden dolu → yazıldı
    expect(crew['eA']?.crewRateSnapshotKurus, 150000); // ücret donduruldu
    expect(crew['eB']?.headcount, 2); // elle girilen ezilmedi
    expect(crew.containsKey('eC'), isFalse); // crewSize 0 → atlandı
    expect(crew.length, 2);
  });

  // REGRESYON: gün yoklaması HENÜZ YÜKLENMEDEN (AsyncLoading) Kaydet'e basılırsa
  // commitCrewDefaults hiçbir öntanımlı yazmamalı — aksi halde tüm elebaşları
  // "kayıtsız" sanıp elle girilmiş mevcudu varsayılanla EZERDİ (sessiz veri kaybı).
  test('commitCrewDefaults: gün akışı yüklenmeden elle girilen mevcudu EZMEZ',
      () async {
    final workers = FakeWorkerRepository();
    attendance = FakeAttendanceRepository();
    settingsRepo = FakeSettingsRepository(settings);
    container = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWithValue(settingsRepo),
      attendanceRepositoryProvider.overrideWithValue(attendance),
      workerRepositoryProvider.overrideWithValue(workers),
    ]);
    container.listen(settingsStreamProvider, (_, _) {});
    await container.read(settingsStreamProvider.future);

    const boss = Worker(
      id: 'eA',
      name: 'A Ustası',
      type: WorkerType.elebasi,
      gender: Gender.male,
      defaultHeadcount: 10, // öntanımlı 10
    );
    await workers.add(boss);
    // Öntanımlı yazma yalnız bugün olduğundan (bug #1) asData guard'ını izole
    // test etmek için seçili gün BUGÜN alınır.
    final today = todayIso();
    container.read(selectedDateProvider.notifier).set(today);

    // Bugün için DEPODA elle 30 kişi girilmiş bir kayıt var (önceki oturum /
    // başka cihaz). Bu kaybolmamalı.
    await attendance.save(AttendanceRecord.crew(
      id: attendanceDocId(today, boss.id),
      date: today,
      workerId: boss.id,
      workerName: boss.name,
      headcount: 30,
      crewRateSnapshotKurus: 150000,
    ));

    // İşçileri yükle AMA gün yoklamasına bilerek abone olma → AsyncLoading kalır.
    container.listen(workersStreamProvider, (_, _) {});
    await container.read(workersStreamProvider.future);
    expect(container.read(attendanceForSelectedDateProvider).asData, isNull,
        reason: 'ön koşul: gün akışı henüz yüklenmedi (asData null)');

    await vm().commitCrewDefaults();

    final r = attendance.all.whereType<CrewAttendance>().single;
    expect(r.headcount, 30,
        reason: 'yükleme sırasında öntanımlı (10) yazılıp 30 EZİLMEMELİ');
    expect(attendance.count, 1, reason: 'yükleme bitmeden hiç öntanımlı yazılmaz');
  });

  // REGRESYON (bug #1): GEÇMİŞ günde "Kaydet" öntanımlı elebaşı mevcudu YAZMAZ.
  // Aksi halde 3 hafta önceki bir güne (geçmiş-gün onayından sonra) çalışmamış
  // tüm ekipler crewSize × yevmiye ile kayda geçer → HAYALET GİDER. Geçmiş
  // gündeki elle düzeltmeler zaten anında kaydedilir; toplu öntanımlı yalnız
  // bugüne yazılır.
  test('commitCrewDefaults: GEÇMİŞ günde öntanımlı YAZMAZ (hayalet gider yok)',
      () async {
    final workers = FakeWorkerRepository();
    attendance = FakeAttendanceRepository();
    settingsRepo = FakeSettingsRepository(settings);
    container = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWithValue(settingsRepo),
      attendanceRepositoryProvider.overrideWithValue(attendance),
      workerRepositoryProvider.overrideWithValue(workers),
    ]);
    container.listen(settingsStreamProvider, (_, _) {});
    await container.read(settingsStreamProvider.future);

    const boss = Worker(
      id: 'eA',
      name: 'A Ustası',
      type: WorkerType.elebasi,
      gender: Gender.male,
      defaultHeadcount: 10,
    );
    await workers.add(boss);

    // Geçmiş bir gün seç (bugün DEĞİL).
    container.read(selectedDateProvider.notifier).set('2020-01-15');
    container.listen(workersStreamProvider, (_, _) {});
    await container.read(workersStreamProvider.future);
    container.listen(attendanceForSelectedDateProvider, (_, _) {});
    await container.read(attendanceForSelectedDateProvider.future);

    await vm().commitCrewDefaults();

    expect(attendance.count, 0,
        reason: 'geçmiş güne öntanımlı elebaşı mevcudu yazılmamalı');
  });

  // "Kaydet" → günün işaret dokümanı yazılır (attendanceDays/{date}) →
  // Cloud Function diğer cihazlara "yoklama alındı" push bildirimi gönderir.
  test('markDaySaved: seçili günün işaret dokümanı yazılır', () async {
    await boot(settings);
    container.read(selectedDateProvider.notifier).set('2026-07-22');

    await vm().markDaySaved();

    expect(attendance.markedDays, ['2026-07-22']);
    expect(attendance.count, 0); // yoklama verisine dokunulmaz
  });

  test('ücret zammı geçmiş snapshot\'ı değiştirmez; yeni gün yeni ücret alır',
      () async {
    await boot(settings);
    // 1. gün: 200000 ile dondur.
    container.read(selectedDateProvider.notifier).set('2026-07-17');
    await vm().setStatus(male, AttendanceStatus.full);

    // Ücret zammı.
    await settingsRepo.save(const AppSettings(
      defaultWageMaleKurus: 300000,
      defaultWageFemaleKurus: 180000,
      defaultCrewRateKurus: 150000,
    ));
    await waitUntil(() =>
        container.read(settingsStreamProvider).asData?.value.defaultWageMaleKurus ==
        300000);

    // 2. gün: yeni ücretle dondur.
    container.read(selectedDateProvider.notifier).set('2026-07-18');
    await vm().setStatus(male, AttendanceStatus.full);

    expect(attendance.count, 2);
    final byDate = {
      for (final r in attendance.all.cast<IndividualAttendance>())
        r.date: r.wageSnapshotKurus
    };
    expect(byDate['2026-07-17'], 200000); // eski gün değişmedi
    expect(byDate['2026-07-18'], 300000); // yeni gün yeni ücret
  });

  // --- Faz 4: ödenmiş gün düzenleme kilidi (kural §3, §6; plan §8) ---

  /// [attendanceForSelectedDateProvider]'ı canlı tutar ve ilk emisyonu bekler —
  /// ViewModel guard'ı bu sağlayıcıyı senkron okur.
  Future<void> loadSelectedDate() async {
    container.listen(attendanceForSelectedDateProvider, (_, _) {});
    await container.read(attendanceForSelectedDateProvider.future);
  }

  // ÖDEME KİLİDİ ŞİMDİLİK RAFTA (hakediş ile birlikte): daha önce ödenmiş
  // (paidPayrollId taşıyan) gün artık düzenlenebilir. Hakediş geri açılınca bu
  // iki test tekrar "düzenlenemez → hata mesajı" beklentisine döndürülmeli.
  test('kilit rafta: ödenmiş bireysel gün artık düzenlenebilir → durum güncellenir',
      () async {
    await boot(settings);
    container.read(selectedDateProvider.notifier).set('2026-07-10');
    // Daha önce ödenmiş (hakedişe girmiş) yarım gün kaydı seed'le.
    await attendance.save(AttendanceRecord.individual(
      id: attendanceDocId('2026-07-10', male.id),
      date: '2026-07-10',
      workerId: male.id,
      workerName: male.name,
      workerType: male.type,
      status: AttendanceStatus.half,
      wageSnapshotKurus: 200000,
      paidPayrollId: 'p1',
    ));
    await loadSelectedDate();

    await vm().setStatus(male, AttendanceStatus.full);

    expect(attendance.count, 1);
    final r = attendance.all.single as IndividualAttendance;
    expect(r.status, AttendanceStatus.full); // kilit yok → durum güncellendi
    expect(container.read(attendanceViewModelProvider), isNull); // hata yok
  });

  test('kilit rafta: ödenmiş elebaşı günü artık düzenlenebilir → kişi sayısı güncellenir',
      () async {
    await boot(settings);
    const boss = Worker(
      id: 'e1',
      name: 'Usta',
      type: WorkerType.elebasi,
      gender: Gender.male,
    );
    container.read(selectedDateProvider.notifier).set('2026-07-10');
    await attendance.save(AttendanceRecord.crew(
      id: attendanceDocId('2026-07-10', boss.id),
      date: '2026-07-10',
      workerId: boss.id,
      workerName: boss.name,
      headcount: 3,
      crewRateSnapshotKurus: 150000,
      paidPayrollId: 'p1',
    ));
    await loadSelectedDate();

    await vm().setHeadcount(boss, 8);

    final r = attendance.all.single as CrewAttendance;
    expect(r.headcount, 8); // kilit yok → kişi sayısı güncellendi
    expect(container.read(attendanceViewModelProvider), isNull);
  });

  test('ödenmemiş gün, sağlayıcı yüklüyken normalde düzenlenir (guard engellemez)',
      () async {
    await boot(settings);
    container.read(selectedDateProvider.notifier).set('2026-07-11');
    await loadSelectedDate();

    await vm().setStatus(male, AttendanceStatus.full);
    await waitUntil(() => attendance.count == 1);

    final r = attendance.all.single as IndividualAttendance;
    expect(r.isPaid, isFalse);
    expect(r.status, AttendanceStatus.full);
  });

  // REGRESYON (kural §4): ücret yoklama ANINDA dondurulur. Var olan bir günü
  // SONRADAN düzenlemek (durum/kişi düzeltmek) YENİ bir dondurma anı DEĞİLDİR →
  // araya giren yevmiye zammı geçmiş kazancı sessizce DEĞİŞTİRMEMELİ.
  test('düzenleme: zamdan sonra eski bireysel günü düzeltmek snapshot\'ı KORUR',
      () async {
    await boot(settings);
    // Eski gün: Tam, 200000 dondur.
    container.read(selectedDateProvider.notifier).set('2026-07-17');
    await loadSelectedDate();
    await vm().setStatus(male, AttendanceStatus.full);
    await waitUntil(() =>
        container.read(attendanceByWorkerForDateProvider)[male.id]
            is IndividualAttendance);

    // Yevmiyeye zam (200000 → 300000).
    await settingsRepo.save(const AppSettings(
      defaultWageMaleKurus: 300000,
      defaultWageFemaleKurus: 180000,
      defaultCrewRateKurus: 150000,
    ));
    await waitUntil(() =>
        container.read(settingsStreamProvider).asData?.value
            .defaultWageMaleKurus ==
        300000);

    // AYNI eski günde SADECE durumu düzelt (Tam → Yarım).
    await vm().setStatus(male, AttendanceStatus.half);

    final r = attendance.all.single as IndividualAttendance;
    expect(r.status, AttendanceStatus.half);
    expect(r.wageSnapshotKurus, 200000,
        reason: 'düzenleme dondurulmuş ücreti korumalı (300000 değil)');
    expect(r.earningKurus, 100000, reason: '200000 yarım = 100000 (150000 değil)');
  });

  test('düzenleme: zamdan sonra eski elebaşı gününü düzeltmek oranı KORUR',
      () async {
    await boot(settings);
    const boss = Worker(
      id: 'e9',
      name: 'Usta',
      type: WorkerType.elebasi,
      gender: Gender.male,
      dailyWageOverrideKurus: 100000, // kişi başı ₺1.000
    );
    container.read(selectedDateProvider.notifier).set('2026-07-17');
    await loadSelectedDate();
    await vm().setHeadcount(boss, 10); // 10 × 100000 dondurulur
    await waitUntil(() =>
        container.read(attendanceByWorkerForDateProvider)[boss.id]
            is CrewAttendance);

    // Elebaşının kişi-başı yevmiyesine zam (100000 → 120000).
    const bossRaised = Worker(
      id: 'e9',
      name: 'Usta',
      type: WorkerType.elebasi,
      gender: Gender.male,
      dailyWageOverrideKurus: 120000,
    );

    // AYNI eski günde SADECE kişi sayısını düzelt (10 → 11).
    await vm().setHeadcount(bossRaised, 11);

    final r = attendance.all.single as CrewAttendance;
    expect(r.headcount, 11);
    expect(r.crewRateSnapshotKurus, 100000,
        reason: 'düzenleme dondurulmuş kişi ücretini korumalı (120000 değil)');
    expect(r.earningKurus, 11 * 100000);
  });

  // Dondurulmuş ₺0 bir ÜCRET değil, EKSİK VERİdir (saha hatası 2026-08-03:
  // elebaşı kişi-başı yevmiyesiz açıldı, günler ₺0 donduruldu, ücret sonradan
  // girilince "görünmüyor" kaldı). Korunsaydı sayacı oynatmak bile günü ₺0'da
  // bırakırdı → 0 ise sonraki dokunuşta güncel ücret çözülür.
  test('elebaşı: dondurulmuş ₺0 oran KORUNMAZ, sonradan girilen ücret yazılır',
      () async {
    await boot(AppSettings.empty);
    const bossNoWage = Worker(
      id: 'e9',
      name: 'Usta',
      type: WorkerType.elebasi,
      gender: Gender.male,
    );
    container.read(selectedDateProvider.notifier).set('2026-07-17');
    await loadSelectedDate();
    await vm().setHeadcount(bossNoWage, 10); // ücretsiz → ₺0 donar
    expect((attendance.all.single as CrewAttendance).crewRateSnapshotKurus, 0);
    await waitUntil(() =>
        container.read(attendanceByWorkerForDateProvider)[bossNoWage.id]
            is CrewAttendance);

    // Kullanıcı işçi kartından kişi başı yevmiyeyi girdi.
    const bossPriced = Worker(
      id: 'e9',
      name: 'Usta',
      type: WorkerType.elebasi,
      gender: Gender.male,
      dailyWageOverrideKurus: 100000,
    );
    await vm().setHeadcount(bossPriced, 11);

    final r = attendance.all.single as CrewAttendance;
    expect(r.crewRateSnapshotKurus, 100000, reason: '₺0 gerçek bir dondurma değil');
    expect(r.earningKurus, 11 * 100000);
  });

  test('bireysel: dondurulmuş ₺0 yevmiye KORUNMAZ, güncel ücret çözülür',
      () async {
    await boot(AppSettings.empty);
    container.read(selectedDateProvider.notifier).set('2026-07-17');
    await loadSelectedDate();
    await vm().setStatus(male, AttendanceStatus.full); // yevmiyesiz → ₺0 donar
    expect((attendance.all.single as IndividualAttendance).wageSnapshotKurus, 0);
    await waitUntil(() =>
        container.read(attendanceByWorkerForDateProvider)[male.id]
            is IndividualAttendance);

    const malePriced = Worker(
      id: 'w1',
      name: 'Ahmet',
      type: WorkerType.gundelik,
      gender: Gender.male,
      dailyWageOverrideKurus: 200000,
    );
    await vm().setStatus(malePriced, AttendanceStatus.full);

    final r = attendance.all.single as IndividualAttendance;
    expect(r.wageSnapshotKurus, 200000);
    expect(r.earningKurus, 200000);
  });

  // --- Tarla seçimi (setField) — "kim nerede çalıştı" (isteğe bağlı) ---

  group('yapılan iş seçimi (setJob)', () {
    const tarla = Job(id: 't1', name: 'Aşağı Tarla');

    test('bireysel: kayda iş yazılır; durum değişince korunur', () async {
      await boot(settings);
      container.read(selectedDateProvider.notifier).set('2026-07-20');
      await loadSelectedDate();

      await vm().setStatus(male, AttendanceStatus.full);
      await waitUntil(() => container
          .read(attendanceByWorkerForDateProvider)
          .containsKey(male.id));
      await vm().setJob(male, tarla);

      var r = attendance.all.single as IndividualAttendance;
      expect(r.jobId, 't1');
      expect(r.jobName, 'Aşağı Tarla'); // ad denormalize donduruldu
      expect(r.status, AttendanceStatus.full); // durum bozulmadı

      // Durum Tam → Yarım: iş seçimi mevcut kayıttan taşınır.
      await waitUntil(() =>
          container.read(attendanceByWorkerForDateProvider)[male.id]?.jobId ==
          't1');
      await vm().setStatus(male, AttendanceStatus.half);
      r = attendance.all.single as IndividualAttendance;
      expect(r.status, AttendanceStatus.half);
      expect(r.jobId, 't1');
      expect(r.jobName, 'Aşağı Tarla');
      expect(attendance.count, 1); // çift kayıt yok (deterministik ID)
    });

    test('null ile seçim kaldırılır', () async {
      await boot(settings);
      container.read(selectedDateProvider.notifier).set('2026-07-20');
      await loadSelectedDate();

      await vm().setStatus(male, AttendanceStatus.full);
      await waitUntil(() => container
          .read(attendanceByWorkerForDateProvider)
          .containsKey(male.id));
      await vm().setJob(male, tarla);
      await waitUntil(() =>
          container.read(attendanceByWorkerForDateProvider)[male.id]?.jobId ==
          't1');

      await vm().setJob(male, null);

      final r = attendance.all.single as IndividualAttendance;
      expect(r.jobId, isNull);
      expect(r.jobName, isNull);
      expect(r.status, AttendanceStatus.full); // durum bozulmadı
    });

    test('bireysel: kaydı olmayan işçide no-op (çipler zaten gizli)', () async {
      await boot(settings);
      await loadSelectedDate();
      await vm().setJob(male, tarla);
      expect(attendance.count, 0);
      expect(container.read(attendanceViewModelProvider), isNull);
    });

    test('elebaşı: kaydı yokken iş seçmek crewSize ile kesinleştirir',
        () async {
      await boot(settings);
      const boss = Worker(
        id: 'e1',
        name: 'Usta',
        type: WorkerType.elebasi,
        gender: Gender.male,
        defaultHeadcount: 7,
      );
      container.read(selectedDateProvider.notifier).set('2026-07-20');
      await loadSelectedDate();

      await vm().setJob(boss, tarla);

      final r = attendance.all.single as CrewAttendance;
      expect(r.headcount, 7); // önden dolu mevcut kalıcılaştı
      expect(r.crewRateSnapshotKurus, 150000); // ücret donduruldu
      expect(r.jobId, 't1');
      expect(r.jobName, 'Aşağı Tarla');
    });

    test('elebaşı: crewSize girilmemişse (0) kaydı yokken no-op', () async {
      await boot(settings);
      const boss = Worker(
        id: 'e1',
        name: 'Usta',
        type: WorkerType.elebasi,
        gender: Gender.male,
      );
      await loadSelectedDate();
      await vm().setJob(boss, tarla);
      expect(attendance.count, 0);
    });

    test('elebaşı: kişi sayısı değişince iş korunur', () async {
      await boot(settings);
      const boss = Worker(
        id: 'e1',
        name: 'Usta',
        type: WorkerType.elebasi,
        gender: Gender.male,
      );
      container.read(selectedDateProvider.notifier).set('2026-07-20');
      await loadSelectedDate();

      await vm().setHeadcount(boss, 4);
      await waitUntil(() => container
          .read(attendanceByWorkerForDateProvider)
          .containsKey(boss.id));
      await vm().setJob(boss, tarla);
      await waitUntil(() =>
          container.read(attendanceByWorkerForDateProvider)[boss.id]?.jobId ==
          't1');

      await vm().setHeadcount(boss, 6);

      final r = attendance.all.single as CrewAttendance;
      expect(r.headcount, 6);
      expect(r.jobId, 't1'); // iş taşındı
      expect(r.jobName, 'Aşağı Tarla');
    });
  });

  // --- Tarla seçimi (setPlot) — yapılan iştan BAĞIMSIZ ikinci boyut ---
  //
  // 2026-08-07 ayrımı: yoklamada iki ayrı çip şeridi var. Bu grubun sözleşmesi
  // "biri diğerini ezmez"dir — aksi halde tarla seçmek o günün iş bilgisini
  // (ya da tersi) sessizce silerdi.

  group('tarla seçimi (setPlot)', () {
    const tarla = Plot(id: 't1', name: 'Aşağı Tarla');
    const capa = Job(id: 'i1', name: 'Çapa');

    test('bireysel: kayda tarla yazılır; durum değişince korunur', () async {
      await boot(settings);
      container.read(selectedDateProvider.notifier).set('2026-07-20');
      await loadSelectedDate();

      await vm().setStatus(male, AttendanceStatus.full);
      await waitUntil(() => container
          .read(attendanceByWorkerForDateProvider)
          .containsKey(male.id));
      await vm().setPlot(male, tarla);

      var r = attendance.all.single as IndividualAttendance;
      expect(r.plotId, 't1');
      expect(r.plotName, 'Aşağı Tarla'); // ad denormalize donduruldu
      expect(r.status, AttendanceStatus.full);

      await waitUntil(() =>
          container.read(attendanceByWorkerForDateProvider)[male.id]?.plotId ==
          't1');
      await vm().setStatus(male, AttendanceStatus.half);
      r = attendance.all.single as IndividualAttendance;
      expect(r.status, AttendanceStatus.half);
      expect(r.plotId, 't1');
      expect(attendance.count, 1); // çift kayıt yok
    });

    test('tarla ve iş bağımsız: biri seçilince diğeri EZİLMEZ', () async {
      await boot(settings);
      container.read(selectedDateProvider.notifier).set('2026-07-20');
      await loadSelectedDate();

      await vm().setStatus(male, AttendanceStatus.full);
      await waitUntil(() => container
          .read(attendanceByWorkerForDateProvider)
          .containsKey(male.id));

      await vm().setJob(male, capa);
      await waitUntil(() =>
          container.read(attendanceByWorkerForDateProvider)[male.id]?.jobId ==
          'i1');
      await vm().setPlot(male, tarla);

      var r = attendance.all.single as IndividualAttendance;
      expect(r.jobId, 'i1'); // iş yerinde durdu
      expect(r.jobName, 'Çapa');
      expect(r.plotId, 't1');
      expect(r.plotName, 'Aşağı Tarla');

      // Tarlayı kaldırmak işi silmez (ve tersi).
      await waitUntil(() =>
          container.read(attendanceByWorkerForDateProvider)[male.id]?.plotId ==
          't1');
      await vm().setPlot(male, null);
      r = attendance.all.single as IndividualAttendance;
      expect(r.plotId, isNull);
      expect(r.jobId, 'i1');

      await waitUntil(() =>
          container.read(attendanceByWorkerForDateProvider)[male.id]?.plotId ==
          null);
      await vm().setJob(male, null);
      r = attendance.all.single as IndividualAttendance;
      expect(r.jobId, isNull);
      expect(r.status, AttendanceStatus.full); // durum yine bozulmadı
    });

    test('elebaşı: kaydı yokken tarla seçmek crewSize ile kesinleştirir',
        () async {
      await boot(settings);
      const boss = Worker(
        id: 'e1',
        name: 'Usta',
        type: WorkerType.elebasi,
        gender: Gender.male,
        defaultHeadcount: 7,
      );
      container.read(selectedDateProvider.notifier).set('2026-07-20');
      await loadSelectedDate();

      await vm().setPlot(boss, tarla);

      final r = attendance.all.single as CrewAttendance;
      expect(r.headcount, 7); // önden dolu mevcut kalıcılaştı
      expect(r.crewRateSnapshotKurus, 150000); // ücret donduruldu
      expect(r.plotId, 't1');
      expect(r.jobId, isNull); // iş şeridine dokunulmadı
    });

    test('bireysel: kaydı olmayan işçide no-op (çipler zaten gizli)', () async {
      await boot(settings);
      await loadSelectedDate();
      await vm().setPlot(male, tarla);
      expect(attendance.count, 0);
      expect(container.read(attendanceViewModelProvider), isNull);
    });
  });

  // --- Mesai (setOvertimeHours) — saat girilir, saat ücreti dondurulur ---

  group('mesai (setOvertimeHours)', () {
    /// Mesai saat ücreti ₺100 olan işçi (kişi başı yevmiye ₺2.000).
    const withRate = Worker(
      id: 'w1',
      name: 'Ahmet',
      type: WorkerType.gundelik,
      gender: Gender.male,
      dailyWageOverrideKurus: 200000,
      overtimeHourlyKurus: 10000,
    );

    /// Seçili günde [withRate] için Tam gün kaydı açar ve sağlayıcıya yansımasını
    /// bekler (ViewModel mevcut kaydı senkron okur).
    Future<void> seedFullDay([Worker worker = withRate]) async {
      container.read(selectedDateProvider.notifier).set('2026-07-20');
      await loadSelectedDate();
      await vm().setStatus(worker, AttendanceStatus.full);
      await waitUntil(() => container
          .read(attendanceByWorkerForDateProvider)
          .containsKey(worker.id));
    }

    test('saat yazılır, saat ücreti dondurulur, kazanç yevmiye + mesai olur',
        () async {
      await boot(settings);
      await seedFullDay();

      await vm().setOvertimeHours(withRate, 2);

      final r = attendance.all.single as IndividualAttendance;
      expect(r.overtimeHours, 2);
      expect(r.overtimeRateSnapshotKurus, 10000); // donduruldu
      expect(r.earningKurus, 200000 + 20000);
      expect(attendance.count, 1); // çift kayıt yok
    });

    /// Mesai saat ücreti GİRİLMEMİŞ işçi — ücreti Yönetim'deki genel ayardan
    /// gelmelidir (tek yerden girilen ortak ücret).
    const noRate = Worker(
      id: 'w1',
      name: 'Ahmet',
      type: WorkerType.gundelik,
      gender: Gender.male,
      dailyWageOverrideKurus: 200000,
    );

    /// Genel mesai ücreti ₺100 olan ayar (Yönetim ekranından girilen değer).
    const withGlobalRate = AppSettings(
      defaultWageMaleKurus: 200000,
      defaultWageFemaleKurus: 180000,
      defaultCrewRateKurus: 150000,
      overtimeHourlyKurus: 10000,
    );

    test('işçide ücret yoksa Yönetim\'deki genel mesai ücreti donar', () async {
      await boot(withGlobalRate);
      await seedFullDay(noRate);

      await vm().setOvertimeHours(noRate, 2);

      final r = attendance.all.single as IndividualAttendance;
      expect(r.overtimeRateSnapshotKurus, 10000);
      expect(r.earningKurus, 200000 + 20000);
    });

    test('işçinin kendi mesai ücreti genel ücreti EZER', () async {
      // Genel ₺100 iken işçinin kendi ücreti ₺150 (istisna).
      await boot(withGlobalRate);
      const different = Worker(
        id: 'w1',
        name: 'Ahmet',
        type: WorkerType.gundelik,
        gender: Gender.male,
        dailyWageOverrideKurus: 200000,
        overtimeHourlyKurus: 15000,
      );
      await seedFullDay(different);

      await vm().setOvertimeHours(different, 2);

      final r = attendance.all.single as IndividualAttendance;
      expect(r.overtimeRateSnapshotKurus, 15000);
      expect(r.earningKurus, 200000 + 30000);
    });

    // Genel ücret sonradan değişse bile GEÇMİŞ gün oynamaz (kural §4) — ayar
    // yolundan gelen ücret de yoklama anında donar.
    test('genel ücret değişse de dondurulmuş mesai tutarı korunur', () async {
      await boot(withGlobalRate);
      await seedFullDay(noRate);
      await vm().setOvertimeHours(noRate, 2); // ₺100/saat dondu
      await waitUntil(() =>
          (container.read(attendanceByWorkerForDateProvider)[noRate.id]
                  as IndividualAttendance?)
              ?.overtimeRateSnapshotKurus ==
          10000);

      // Yönetim'den genel ücret ₺100 → ₺200 yapıldı, sonra aynı gün düzeltildi.
      await settingsRepo
          .save(withGlobalRate.copyWith(overtimeHourlyKurus: 20000));
      await waitUntil(() =>
          container.read(settingsStreamProvider).asData?.value
              .overtimeHourlyKurus ==
          20000);
      await vm().setOvertimeHours(noRate, 3);

      final r = attendance.all.single as IndividualAttendance;
      expect(r.overtimeHours, 3);
      expect(r.overtimeRateSnapshotKurus, 10000,
          reason: 'geçmiş gün eski (dondurulmuş) ücretle kalmalı');
      expect(r.earningKurus, 200000 + 30000);
    });

    test('kaydı olmayan işçide no-op (mesai tek başına gün yaratmaz)', () async {
      await boot(settings);
      container.read(selectedDateProvider.notifier).set('2026-07-20');
      await loadSelectedDate();

      await vm().setOvertimeHours(withRate, 3);

      expect(attendance.count, 0);
    });

    test('0 saat mesaiyi kaldırır ve dondurulmuş ücreti sıfırlar', () async {
      await boot(settings);
      await seedFullDay();
      await vm().setOvertimeHours(withRate, 2);
      await waitUntil(() =>
          (container.read(attendanceByWorkerForDateProvider)[withRate.id]
                  as IndividualAttendance?)
              ?.overtimeHours ==
          2);

      await vm().setOvertimeHours(withRate, 0);

      final r = attendance.all.single as IndividualAttendance;
      expect(r.overtimeHours, 0);
      expect(r.overtimeRateSnapshotKurus, 0);
      expect(r.earningKurus, 200000); // yalnız yevmiye
    });

    test('üst sınır: $kMaxOvertimeHours saatten fazlası kırpılır', () async {
      await boot(settings);
      await seedFullDay();

      await vm().setOvertimeHours(withRate, 99);

      final r = attendance.all.single as IndividualAttendance;
      expect(r.overtimeHours, kMaxOvertimeHours);
    });

    test('negatif saat 0 sayılır', () async {
      await boot(settings);
      await seedFullDay();

      await vm().setOvertimeHours(withRate, -3);

      final r = attendance.all.single as IndividualAttendance;
      expect(r.overtimeHours, 0);
    });

    // REGRESYON (kural §4): mesai saat ücreti de yoklama ANINDA donar; sonradan
    // işçinin saat ücretini değiştirmek geçmiş günün mesai tutarını oynatmamalı.
    test('zamdan sonra saat düzeltmek dondurulmuş saat ücretini KORUR',
        () async {
      await boot(settings);
      await seedFullDay();
      await vm().setOvertimeHours(withRate, 2); // ₺100/saat dondu
      await waitUntil(() =>
          (container.read(attendanceByWorkerForDateProvider)[withRate.id]
                  as IndividualAttendance?)
              ?.overtimeRateSnapshotKurus ==
          10000);

      // Saat ücretine zam (₺100 → ₺150) ve AYNI günde saati düzelt.
      const raised = Worker(
        id: 'w1',
        name: 'Ahmet',
        type: WorkerType.gundelik,
        gender: Gender.male,
        dailyWageOverrideKurus: 200000,
        overtimeHourlyKurus: 15000,
      );
      await vm().setOvertimeHours(raised, 3);

      final r = attendance.all.single as IndividualAttendance;
      expect(r.overtimeHours, 3);
      expect(r.overtimeRateSnapshotKurus, 10000,
          reason: 'düzenleme dondurulmuş saat ücretini korumalı (15000 değil)');
      expect(r.earningKurus, 200000 + 30000);
    });

    // Saat ücreti girilmemişken mesai girildiyse tutar 0'dır; ücret sonradan
    // girilince SONRAKİ dokunuş güncel ücreti dondurur (kilitlenip kalmaz).
    test('ücret sonradan girilirse sonraki dokunuş güncel ücreti dondurur',
        () async {
      // Genel ücret de girilmemiş (settings.overtimeHourlyKurus == 0).
      await boot(settings);
      await seedFullDay(noRate);
      await vm().setOvertimeHours(noRate, 2); // ücret yok → tutar 0
      var r = attendance.all.single as IndividualAttendance;
      expect(r.overtimeRateSnapshotKurus, 0);
      expect(r.earningKurus, 200000);

      await waitUntil(() =>
          (container.read(attendanceByWorkerForDateProvider)[noRate.id]
                  as IndividualAttendance?)
              ?.overtimeHours ==
          2);
      await vm().setOvertimeHours(withRate, 2); // artık ₺100/saat girili

      r = attendance.all.single as IndividualAttendance;
      expect(r.overtimeRateSnapshotKurus, 10000);
      expect(r.earningKurus, 200000 + 20000);
    });

    test('durum Tam → Yarım değişince mesai korunur', () async {
      await boot(settings);
      await seedFullDay();
      await vm().setOvertimeHours(withRate, 2);
      await waitUntil(() =>
          (container.read(attendanceByWorkerForDateProvider)[withRate.id]
                  as IndividualAttendance?)
              ?.overtimeHours ==
          2);

      await vm().setStatus(withRate, AttendanceStatus.half);

      final r = attendance.all.single as IndividualAttendance;
      expect(r.status, AttendanceStatus.half);
      expect(r.overtimeHours, 2);
      expect(r.overtimeRateSnapshotKurus, 10000);
      expect(r.earningKurus, 100000 + 20000);
    });

    // "Yok" işaretlenince mesai TEMİZLENİR: mesai şeridi ekranda kapanır, kalan
    // saat görünmeyen bir hayalet gider olurdu.
    test('durum "Yok" olunca mesai temizlenir', () async {
      await boot(settings);
      await seedFullDay();
      await vm().setOvertimeHours(withRate, 2);
      await waitUntil(() =>
          (container.read(attendanceByWorkerForDateProvider)[withRate.id]
                  as IndividualAttendance?)
              ?.overtimeHours ==
          2);

      await vm().setStatus(withRate, AttendanceStatus.absent);

      final r = attendance.all.single as IndividualAttendance;
      expect(r.status, AttendanceStatus.absent);
      expect(r.overtimeHours, 0);
      expect(r.overtimeRateSnapshotKurus, 0);
      expect(r.earningKurus, 0);
    });

    test('tarla seçimi mesaiyi bozmaz', () async {
      await boot(settings);
      await seedFullDay();
      await vm().setOvertimeHours(withRate, 2);
      await waitUntil(() =>
          (container.read(attendanceByWorkerForDateProvider)[withRate.id]
                  as IndividualAttendance?)
              ?.overtimeHours ==
          2);

      await vm().setJob(withRate, const Job(id: 't1', name: 'Aşağı Tarla'));

      final r = attendance.all.single as IndividualAttendance;
      expect(r.jobId, 't1');
      expect(r.overtimeHours, 2);
      expect(r.overtimeRateSnapshotKurus, 10000);
    });

    test('elebaşı kaydında mesai no-op (elebaşıda mesai yok)', () async {
      await boot(settings);
      const boss = Worker(
        id: 'e1',
        name: 'Usta',
        type: WorkerType.elebasi,
        gender: Gender.male,
        dailyWageOverrideKurus: 100000,
      );
      container.read(selectedDateProvider.notifier).set('2026-07-20');
      await loadSelectedDate();
      await vm().setHeadcount(boss, 4);
      await waitUntil(() => container
          .read(attendanceByWorkerForDateProvider)
          .containsKey(boss.id));

      await vm().setOvertimeHours(boss, 3);

      final r = attendance.all.single as CrewAttendance;
      expect(r.headcount, 4);
      expect(r.earningKurus, 4 * 100000); // mesai eklenmedi
    });
  });
}

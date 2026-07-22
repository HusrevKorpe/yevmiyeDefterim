import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/core/ids/ids.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_view_model.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/attendance/data/field.dart';
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

  test('elebaşı kişi sayısı → kişi ücreti snapshot + kazanç', () async {
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

  // "Kaydet" → önden dolu (henüz kaydı olmayan) elebaşı öntanımlı mevcutları
  // (crewSize) o güne yazılır; elle girilmiş kayıt ezilmez; kişi sayısı
  // girilmemiş elebaşı atlanır (İşçiler'de girilen ekip sayısı yoklamaya gelsin).
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

    container.read(selectedDateProvider.notifier).set('2026-07-15');
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

  // --- Tarla seçimi (setField) — "kim nerede çalıştı" (isteğe bağlı) ---

  group('tarla seçimi (setField)', () {
    const tarla = Field(id: 't1', name: 'Aşağı Tarla');

    test('bireysel: kayda tarla yazılır; durum değişince korunur', () async {
      await boot(settings);
      container.read(selectedDateProvider.notifier).set('2026-07-20');
      await loadSelectedDate();

      await vm().setStatus(male, AttendanceStatus.full);
      await waitUntil(() => container
          .read(attendanceByWorkerForDateProvider)
          .containsKey(male.id));
      await vm().setField(male, tarla);

      var r = attendance.all.single as IndividualAttendance;
      expect(r.fieldId, 't1');
      expect(r.fieldName, 'Aşağı Tarla'); // ad denormalize donduruldu
      expect(r.status, AttendanceStatus.full); // durum bozulmadı

      // Durum Tam → Yarım: tarla seçimi mevcut kayıttan taşınır.
      await waitUntil(() =>
          container.read(attendanceByWorkerForDateProvider)[male.id]?.fieldId ==
          't1');
      await vm().setStatus(male, AttendanceStatus.half);
      r = attendance.all.single as IndividualAttendance;
      expect(r.status, AttendanceStatus.half);
      expect(r.fieldId, 't1');
      expect(r.fieldName, 'Aşağı Tarla');
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
      await vm().setField(male, tarla);
      await waitUntil(() =>
          container.read(attendanceByWorkerForDateProvider)[male.id]?.fieldId ==
          't1');

      await vm().setField(male, null);

      final r = attendance.all.single as IndividualAttendance;
      expect(r.fieldId, isNull);
      expect(r.fieldName, isNull);
      expect(r.status, AttendanceStatus.full); // durum bozulmadı
    });

    test('bireysel: kaydı olmayan işçide no-op (çipler zaten gizli)', () async {
      await boot(settings);
      await loadSelectedDate();
      await vm().setField(male, tarla);
      expect(attendance.count, 0);
      expect(container.read(attendanceViewModelProvider), isNull);
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

      await vm().setField(boss, tarla);

      final r = attendance.all.single as CrewAttendance;
      expect(r.headcount, 7); // önden dolu mevcut kalıcılaştı
      expect(r.crewRateSnapshotKurus, 150000); // ücret donduruldu
      expect(r.fieldId, 't1');
      expect(r.fieldName, 'Aşağı Tarla');
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
      await vm().setField(boss, tarla);
      expect(attendance.count, 0);
    });

    test('elebaşı: kişi sayısı değişince tarla korunur', () async {
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
      await vm().setField(boss, tarla);
      await waitUntil(() =>
          container.read(attendanceByWorkerForDateProvider)[boss.id]?.fieldId ==
          't1');

      await vm().setHeadcount(boss, 6);

      final r = attendance.all.single as CrewAttendance;
      expect(r.headcount, 6);
      expect(r.fieldId, 't1'); // tarla taşındı
      expect(r.fieldName, 'Aşağı Tarla');
    });
  });
}

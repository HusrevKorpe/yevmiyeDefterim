import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/core/ids/ids.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_view_model.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_providers.dart';
import 'package:yevmiye_defterim/features/settings/data/app_settings.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../../support/fake_attendance_repository.dart';
import '../../support/fake_settings_repository.dart';

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
}

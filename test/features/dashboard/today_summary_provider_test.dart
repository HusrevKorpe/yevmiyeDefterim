import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/core/date/app_date.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/dashboard/application/dashboard_providers.dart';
import 'package:yevmiye_defterim/features/dashboard/application/day_summary.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../../support/fake_attendance_repository.dart';
import '../../support/fake_worker_repository.dart';

/// Ana Sayfa "Bugün Özeti": cinsiyet haritası CANLI olmalı.
///
/// Regresyon (28 Temmuz 2026): harita `watchAll().first` ile donduruluyordu →
/// uygulama açıkken eklenen işçi bugün çalışsa bile kadın/erkek sayacına
/// girmiyordu (9 kadın çalıştı, Ana Sayfa "Kadın 6" gösterdi).
void main() {
  Worker worker(String id, Gender gender) => Worker(
        id: id,
        name: 'İşçi $id',
        type: WorkerType.gundelik,
        gender: gender,
        dailyWageOverrideKurus: 100000,
      );

  AttendanceRecord present(Worker w) => AttendanceRecord.individual(
        id: '${todayIso()}_${w.id}',
        date: todayIso(),
        workerId: w.id,
        workerName: w.name,
        workerType: w.type,
        status: AttendanceStatus.full,
        wageSnapshotKurus: 100000,
      );

  /// [test] doğru olana kadar özet emisyonlarını bekler (akışlar mikrotask'lı).
  Future<DaySummary> waitFor(
    ProviderContainer container,
    bool Function(DaySummary) test,
  ) async {
    for (var i = 0; i < 200; i++) {
      final value = container.read(todaySummaryProvider).asData?.value;
      if (value != null && test(value)) return value;
      await Future<void>.delayed(Duration.zero);
    }
    fail('Özet beklenen duruma ulaşmadı: '
        '${container.read(todaySummaryProvider).asData?.value}');
  }

  ProviderContainer makeContainer(
    FakeWorkerRepository workers,
    FakeAttendanceRepository attendance,
  ) {
    final container = ProviderContainer(overrides: [
      workerRepositoryProvider.overrideWithValue(workers),
      attendanceRepositoryProvider.overrideWithValue(attendance),
    ]);
    addTearDown(container.dispose);
    // Dinleyici olmadan sağlayıcılar akışa abone olmaz.
    container.listen(todaySummaryProvider, (_, _) {}, fireImmediately: true);
    return container;
  }

  test('gün içinde EKLENEN işçi kadın/erkek sayısına girer', () async {
    final workers = FakeWorkerRepository();
    final attendance = FakeAttendanceRepository();
    final ayse = worker('w1', Gender.female);
    await workers.add(ayse);

    final container = makeContainer(workers, attendance);
    await attendance.save(present(ayse));
    await waitFor(container, (s) => s.femaleCount == 1);

    // Uygulama AÇIKKEN yeni işçi eklenir ve aynı gün çalışır.
    final fatma = worker('w2', Gender.female);
    await workers.add(fatma);
    await attendance.save(present(fatma));

    final summary = await waitFor(container, (s) => s.presentIndividuals == 2);
    // Eski (dondurulmuş harita) davranışında burası 1 kalıyordu.
    expect(summary.femaleCount, 2);
    expect(summary.maleCount, 0);
  });

  test('işçinin cinsiyeti düzeltilince özet güncellenir', () async {
    final workers = FakeWorkerRepository();
    final attendance = FakeAttendanceRepository();
    final yanlis = worker('w1', Gender.male);
    await workers.add(yanlis);

    final container = makeContainer(workers, attendance);
    await attendance.save(present(yanlis));
    await waitFor(container, (s) => s.maleCount == 1);

    await workers.update(yanlis.copyWith(gender: Gender.female));

    final summary = await waitFor(container, (s) => s.femaleCount == 1);
    expect(summary.maleCount, 0);
    expect(summary.presentIndividuals, 1);
  });

  test('işçi listesi gelmeden özet yayınlanmaz (yanlış "0 kadın" görünmesin)',
      () async {
    final workers = FakeWorkerRepository();
    final attendance = FakeAttendanceRepository();
    final container = ProviderContainer(overrides: [
      workerRepositoryProvider.overrideWithValue(workers),
      attendanceRepositoryProvider.overrideWithValue(attendance),
    ]);
    addTearDown(container.dispose);

    expect(container.read(todaySummaryProvider).asData?.value, isNull);
    expect(container.read(todaySummaryProvider).isLoading, isTrue);
  });
}

/// Çalışma özeti (takvimsiz toplam cetveli) saf hesabı.
///
/// Aylık cetvelden farkı: ay sınırı yok, her işçi TÜM zamanın toplamıyla tek
/// satır. Gün sayma kuralları aylık cetvelle aynı kalmalı (0 kişilik elebaşı
/// sayılmaz, "Yok" günü gün değildir), tutarlar snapshot toplamıdır.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/attendance/application/worker_totals.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

void main() {
  Worker worker(
    String id,
    String name,
    WorkerType type, {
    bool active = true,
  }) =>
      Worker(
        id: id,
        name: name,
        type: type,
        gender: Gender.male,
        active: active,
      );

  AttendanceRecord ind(
    String workerId,
    String name,
    String date,
    AttendanceStatus status,
    int wage, {
    WorkerType type = WorkerType.gundelik,
    int overtimeHours = 0,
    int overtimeRate = 0,
  }) =>
      AttendanceRecord.individual(
        id: '${date}_$workerId',
        date: date,
        workerId: workerId,
        workerName: name,
        workerType: type,
        status: status,
        wageSnapshotKurus: wage,
        overtimeHours: overtimeHours,
        overtimeRateSnapshotKurus: overtimeRate,
      );

  AttendanceRecord crew(
    String workerId,
    String name,
    String date,
    int headcount,
    int rate,
  ) =>
      AttendanceRecord.crew(
        id: '${date}_$workerId',
        date: date,
        workerId: workerId,
        workerName: name,
        headcount: headcount,
        crewRateSnapshotKurus: rate,
      );

  test('aylar birleşir: gün ve kazanç TÜM zaman boyunca toplanır', () {
    final table = buildWorkerTotals(
      workers: [worker('w1', 'Ahmet', WorkerType.gundelik)],
      records: [
        ind('w1', 'Ahmet', '2026-06-30', AttendanceStatus.full, 200000),
        ind('w1', 'Ahmet', '2026-07-01', AttendanceStatus.full, 200000),
        ind('w1', 'Ahmet', '2026-08-05', AttendanceStatus.half, 200000),
      ],
    );

    final row = table.rows.single;
    expect(row.fullDays, 2);
    expect(row.halfDays, 1);
    // Tam=1, yarım=0,5 → 2,5 adam-gün.
    expect(row.dayCount, 2.5);
    expect(row.grossKurus, 200000 + 200000 + 100000);
    expect(table.grossKurus, 500000);
    expect(table.dayCount, 2.5);
  });

  test('"Yok" günü gün saymaz, kazanca da girmez', () {
    final table = buildWorkerTotals(
      workers: [worker('w1', 'Ahmet', WorkerType.gundelik)],
      records: [
        ind('w1', 'Ahmet', '2026-07-01', AttendanceStatus.full, 200000),
        ind('w1', 'Ahmet', '2026-07-02', AttendanceStatus.absent, 200000),
      ],
    );

    final row = table.rows.single;
    expect(row.dayCount, 1);
    expect(row.grossKurus, 200000);
  });

  test('mesai kazanca girer, saat olarak ayrıca sayılır', () {
    final table = buildWorkerTotals(
      workers: [worker('w1', 'Ahmet', WorkerType.gundelik)],
      records: [
        ind('w1', 'Ahmet', '2026-07-01', AttendanceStatus.full, 200000,
            overtimeHours: 2, overtimeRate: 10000),
        // "Yok" günün mesaisi sayılmaz (kayıt tutarsız olsa bile).
        ind('w1', 'Ahmet', '2026-07-02', AttendanceStatus.absent, 200000,
            overtimeHours: 3, overtimeRate: 10000),
      ],
    );

    final row = table.rows.single;
    expect(row.overtimeHours, 2);
    expect(row.grossKurus, 200000 + 20000);
  });

  test('elebaşı: gün = kişi girilen gün, kişi-gün ayrı toplanır', () {
    final table = buildWorkerTotals(
      workers: [worker('c1', 'Hasan', WorkerType.elebasi)],
      records: [
        crew('c1', 'Hasan', '2026-07-01', 20, 100000),
        crew('c1', 'Hasan', '2026-07-02', 15, 100000),
        // 0 kişilik gün çalışılan gün değildir → hiç sayılmaz.
        crew('c1', 'Hasan', '2026-07-03', 0, 100000),
      ],
    );

    final row = table.rows.single;
    expect(row.isCrew, isTrue);
    expect(row.crewDays, 2);
    expect(row.crewHeadcountTotal, 35);
    expect(row.dayCount, 2);
    expect(row.grossKurus, 35 * 100000);
  });

  test('yalnız 0 kişilik kaydı olan elebaşı satır bile açmaz', () {
    final table = buildWorkerTotals(
      workers: [worker('c1', 'Hasan', WorkerType.elebasi)],
      records: [crew('c1', 'Hasan', '2026-07-03', 0, 100000)],
    );

    expect(table.isEmpty, isTrue);
  });

  test('kaydı olmayan işçi satır olmaz', () {
    final table = buildWorkerTotals(
      workers: [
        worker('w1', 'Ahmet', WorkerType.gundelik),
        worker('w2', 'Mehmet', WorkerType.gundelik),
      ],
      records: [
        ind('w1', 'Ahmet', '2026-07-01', AttendanceStatus.full, 200000),
      ],
    );

    expect(table.rows.map((r) => r.workerId), ['w1']);
  });

  test('silinmiş/pasif işçi geçmişiyle kalır, kalıntı işaretlenir', () {
    final table = buildWorkerTotals(
      workers: [
        worker('w1', 'Ahmet', WorkerType.gundelik),
        worker('w2', 'Mehmet', WorkerType.gundelik, active: false),
      ],
      records: [
        ind('w1', 'Ahmet', '2026-07-01', AttendanceStatus.full, 200000),
        ind('w2', 'Mehmet', '2026-07-01', AttendanceStatus.full, 180000),
        // Listede olmayan (kalıcı silinmiş) işçi: ad/tür kayıttan okunur.
        ind('wX', 'Zeynep', '2026-07-01', AttendanceStatus.full, 150000),
      ],
    );

    final byId = {for (final r in table.rows) r.workerId: r};
    expect(byId['w1']!.removed, isFalse);
    expect(byId['w2']!.removed, isTrue);
    expect(byId['wX']!.removed, isTrue);
    expect(byId['wX']!.workerName, 'Zeynep');
  });

  group('hesabı görüldü işareti', () {
    test('kapanış tarihi satıra taşınır, kapanışsız işçi işaretsiz kalır', () {
      final table = buildWorkerTotals(
        workers: [
          worker('w1', 'Ahmet', WorkerType.gundelik),
          worker('w2', 'Mehmet', WorkerType.gundelik),
        ],
        records: [
          ind('w1', 'Ahmet', '2026-07-01', AttendanceStatus.full, 200000),
          ind('w2', 'Mehmet', '2026-07-01', AttendanceStatus.full, 200000),
        ],
        settledThroughByWorker: const {'w1': '2026-07-22'},
      );

      final byId = {for (final r in table.rows) r.workerId: r};
      expect(byId['w1']!.settledThrough, '2026-07-22');
      expect(byId['w1']!.isSettled, isTrue);
      expect(byId['w2']!.settledThrough, isNull);
      expect(byId['w2']!.isSettled, isFalse);
    });

    test('işaret toplamları DEĞİŞTİRMEZ (kapanış sonrası günler de sayılır)',
        () {
      final table = buildWorkerTotals(
        workers: [worker('w1', 'Ahmet', WorkerType.gundelik)],
        records: [
          ind('w1', 'Ahmet', '2026-07-01', AttendanceStatus.full, 200000),
          // Kapanıştan SONRAKİ gün: renk sınırının dışında ama toplamda var.
          ind('w1', 'Ahmet', '2026-07-25', AttendanceStatus.full, 200000),
        ],
        settledThroughByWorker: const {'w1': '2026-07-22'},
      );

      final row = table.rows.single;
      expect(row.dayCount, 2);
      expect(row.grossKurus, 400000);
    });
  });

  test('sıralama aylık cetvelle aynı: önce tür, sonra ad', () {
    final table = buildWorkerTotals(
      workers: [
        worker('c1', 'Ali Elebaşı', WorkerType.elebasi),
        worker('w1', 'Zeki', WorkerType.gundelik),
        worker('s1', 'Bekir', WorkerType.sabit),
        worker('w2', 'Ahmet', WorkerType.gundelik),
      ],
      records: [
        crew('c1', 'Ali Elebaşı', '2026-07-01', 5, 100000),
        ind('w1', 'Zeki', '2026-07-01', AttendanceStatus.full, 200000),
        ind('s1', 'Bekir', '2026-07-01', AttendanceStatus.full, 200000,
            type: WorkerType.sabit),
        ind('w2', 'Ahmet', '2026-07-01', AttendanceStatus.full, 200000),
      ],
    );

    expect(
      table.rows.map((r) => r.workerName),
      ['Bekir', 'Ahmet', 'Zeki', 'Ali Elebaşı'],
    );
  });
}

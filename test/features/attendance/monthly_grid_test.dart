import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/attendance/application/monthly_grid.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

void main() {
  Worker worker(String id, String name, WorkerType type) => Worker(
        id: id,
        name: name,
        type: type,
        gender: Gender.male,
      );

  AttendanceRecord ind(
    String workerId,
    String name,
    String date,
    AttendanceStatus status,
    int wage, {
    WorkerType type = WorkerType.gundelik,
  }) =>
      AttendanceRecord.individual(
        id: '${date}_$workerId',
        date: date,
        workerId: workerId,
        workerName: name,
        workerType: type,
        status: status,
        wageSnapshotKurus: wage,
      );

  AttendanceRecord crew(
    String workerId,
    String name,
    String date,
    int headcount,
    int rate, {
    int? agreedPay,
  }) =>
      AttendanceRecord.crew(
        id: '${date}_$workerId',
        date: date,
        workerId: workerId,
        workerName: name,
        headcount: headcount,
        crewRateSnapshotKurus: rate,
        agreedPayKurus: agreedPay,
      );

  group('buildMonthlyGrid gün sütunları', () {
    test('31 günlük ay', () {
      final g = buildMonthlyGrid(
          monthIso: '2026-07', workers: const [], records: const []);
      expect(g.days.length, 31);
      expect(g.days.first, '2026-07-01');
      expect(g.days.last, '2026-07-31');
      expect(g.isEmpty, isTrue);
    });

    test('Şubat 28 gün, artık yıl 29 gün', () {
      expect(
        buildMonthlyGrid(
                monthIso: '2026-02', workers: const [], records: const [])
            .days
            .length,
        28,
      );
      expect(
        buildMonthlyGrid(
                monthIso: '2024-02', workers: const [], records: const [])
            .days
            .length,
        29,
      );
    });
  });

  test('bireysel: hücre eşleme + tam/yarım/yok toplamları + brüt', () {
    final g = buildMonthlyGrid(
      monthIso: '2026-07',
      workers: [worker('w1', 'Ahmet', WorkerType.gundelik)],
      records: [
        ind('w1', 'Ahmet', '2026-07-01', AttendanceStatus.full, 200000),
        ind('w1', 'Ahmet', '2026-07-02', AttendanceStatus.half, 200000),
        ind('w1', 'Ahmet', '2026-07-03', AttendanceStatus.absent, 200000),
      ],
    );

    expect(g.rows.length, 1);
    final r = g.rows.single;
    expect(r.fullDays, 1);
    expect(r.halfDays, 1);
    // yarım = 200000 ~/ 2 = 100000, yok = 0.
    expect(r.grossKurus, 300000);
    expect(r.individualDayEquivalent, 1.5);

    expect(r.cells['2026-07-01']!.status, AttendanceStatus.full);
    expect(r.cells['2026-07-02']!.status, AttendanceStatus.half);
    // "Yok" bir kayıttır → hücre var (boş değil), ama gün sayılmaz.
    expect(r.cells['2026-07-03']!.status, AttendanceStatus.absent);
    expect(r.cells['2026-07-04'], isNull);
  });

  test('elebaşı: kişi sayısı + kişi-gün + anlaşmalı toplam', () {
    final g = buildMonthlyGrid(
      monthIso: '2026-07',
      workers: [worker('c1', 'Reis', WorkerType.elebasi)],
      records: [
        crew('c1', 'Reis', '2026-07-05', 3, 100000), // 3 * 100000 = 300000
        crew('c1', 'Reis', '2026-07-06', 4, 100000,
            agreedPay: 350000), // anlaşmalı toplam ezer
      ],
    );

    final r = g.rows.single;
    expect(r.isCrew, isTrue);
    expect(r.crewDays, 2);
    expect(r.crewHeadcountTotal, 7);
    expect(r.grossKurus, 650000); // 300000 + 350000
    expect(r.cells['2026-07-05']!.crewHeadcount, 3);
    expect(r.cells['2026-07-05']!.isCrew, isTrue);
  });

  test('0-kişilik elebaşı kaydı çalışılan gün SAYILMAZ (worker_history ile tutarlı)',
      () {
    final g = buildMonthlyGrid(
      monthIso: '2026-07',
      workers: [worker('c1', 'Reis', WorkerType.elebasi)],
      records: [
        crew('c1', 'Reis', '2026-07-05', 3, 100000), // gerçek gün
        crew('c1', 'Reis', '2026-07-06', 0, 100000), // "gelmedi" işareti → sayılmaz
      ],
    );

    final r = g.rows.single;
    expect(r.crewDays, 1, reason: 'yalnız 0>kişili gün sayılır');
    expect(r.crewHeadcountTotal, 3);
    expect(r.grossKurus, 300000, reason: '0 kişi × ücret = 0 katkı');
    expect(r.cells['2026-07-05']!.crewHeadcount, 3);
    expect(r.cells['2026-07-06'], isNull,
        reason: '0-kişilik gün hücre bile oluşturmaz (görünmez)');
  });

  test('yalnızca 0-kişilik kaydı olan elebaşı satır AÇMAZ (boş satır yok)', () {
    final g = buildMonthlyGrid(
      monthIso: '2026-07',
      workers: [worker('c1', 'Reis', WorkerType.elebasi)],
      records: [
        crew('c1', 'Reis', '2026-07-06', 0, 100000),
      ],
    );
    expect(g.rows, isEmpty);
  });

  test('satır sırası: sabit → gündelik → elebaşı, sonra ada göre', () {
    final g = buildMonthlyGrid(
      monthIso: '2026-07',
      workers: [
        worker('w1', 'Ahmet', WorkerType.gundelik),
        worker('w2', 'Zeynep', WorkerType.sabit),
        worker('c1', 'Reis', WorkerType.elebasi),
      ],
      records: [
        ind('w1', 'Ahmet', '2026-07-01', AttendanceStatus.full, 200000),
        ind('w2', 'Zeynep', '2026-07-01', AttendanceStatus.full, 150000,
            type: WorkerType.sabit),
        crew('c1', 'Reis', '2026-07-01', 2, 100000),
      ],
    );

    expect(g.rows.map((r) => r.workerName).toList(),
        ['Zeynep', 'Ahmet', 'Reis']);
    expect(g.grossKurus, 200000 + 150000 + 200000);
  });

  test('ay dışı kayıtlar süzülür', () {
    final g = buildMonthlyGrid(
      monthIso: '2026-07',
      workers: [worker('w1', 'Ahmet', WorkerType.gundelik)],
      records: [
        ind('w1', 'Ahmet', '2026-06-30', AttendanceStatus.full, 200000),
        ind('w1', 'Ahmet', '2026-08-01', AttendanceStatus.full, 200000),
        ind('w1', 'Ahmet', '2026-07-10', AttendanceStatus.full, 200000),
      ],
    );

    final r = g.rows.single;
    expect(r.fullDays, 1);
    expect(r.grossKurus, 200000);
    expect(r.cells.keys.toList(), ['2026-07-10']);
  });

  test('kaydı olmayan işçi satır olmaz (boş satır gürültüsü yok)', () {
    final g = buildMonthlyGrid(
      monthIso: '2026-07',
      workers: [
        worker('w1', 'Ahmet', WorkerType.gundelik),
        worker('w2', 'Boş', WorkerType.gundelik), // hiç kaydı yok
      ],
      records: [
        ind('w1', 'Ahmet', '2026-07-01', AttendanceStatus.full, 200000),
      ],
    );
    expect(g.rows.map((r) => r.workerName).toList(), ['Ahmet']);
  });

  test('işçi listede yoksa kaydından türetilir (silinmiş/pasif işçi)', () {
    final g = buildMonthlyGrid(
      monthIso: '2026-07',
      workers: const [], // işçi listesi boş
      records: [
        ind('wX', 'Silinmiş İşçi', '2026-07-02', AttendanceStatus.full, 180000),
      ],
    );
    final r = g.rows.single;
    expect(r.workerName, 'Silinmiş İşçi');
    expect(r.type, WorkerType.gundelik);
    expect(r.grossKurus, 180000);
  });

  group('removed işareti (kalıntı satır temizliği)', () {
    test('aktif işçinin satırı kalıntı DEĞİLDİR', () {
      final g = buildMonthlyGrid(
        monthIso: '2026-07',
        workers: [worker('w1', 'Ahmet', WorkerType.gundelik)],
        records: [
          ind('w1', 'Ahmet', '2026-07-01', AttendanceStatus.full, 200000),
        ],
      );
      expect(g.rows.single.removed, isFalse);
    });

    test('listede olmayan (kalıcı silinmiş) işçinin satırı kalıntıdır', () {
      final g = buildMonthlyGrid(
        monthIso: '2026-07',
        workers: const [],
        records: [
          ind('wX', 'Hüsrev Deneme', '2026-07-02', AttendanceStatus.full, 1000),
        ],
      );
      expect(g.rows.single.removed, isTrue);
    });

    test('pasif (soft-delete) işçinin satırı da kalıntıdır', () {
      final g = buildMonthlyGrid(
        monthIso: '2026-07',
        workers: [
          worker('w1', 'Deneme', WorkerType.gundelik).copyWith(active: false),
        ],
        records: [
          ind('w1', 'Deneme', '2026-07-02', AttendanceStatus.full, 1000),
        ],
      );
      expect(g.rows.single.removed, isTrue);
    });
  });

  group('mesai — hücre üst simgesi ve ay toplamı', () {
    AttendanceRecord withOvertime(
      String date,
      AttendanceStatus status, {
      int hours = 0,
      int rate = 10000,
    }) =>
        AttendanceRecord.individual(
          id: '${date}_w1',
          date: date,
          workerId: 'w1',
          workerName: 'Ahmet',
          workerType: WorkerType.gundelik,
          status: status,
          wageSnapshotKurus: 200000,
          overtimeHours: hours,
          overtimeRateSnapshotKurus: rate,
        );

    test('hücre mesai saatini taşır; kazanç mesai dahil', () {
      final g = buildMonthlyGrid(
        monthIso: '2026-07',
        workers: [worker('w1', 'Ahmet', WorkerType.gundelik)],
        records: [withOvertime('2026-07-02', AttendanceStatus.full, hours: 2)],
      );
      final cell = g.rows.single.cells['2026-07-02']!;
      expect(cell.overtimeHours, 2);
      expect(cell.earningKurus, 220000);
      expect(g.rows.single.grossKurus, 220000);
    });

    test('mesaisiz gün 0 saat', () {
      final g = buildMonthlyGrid(
        monthIso: '2026-07',
        workers: [worker('w1', 'Ahmet', WorkerType.gundelik)],
        records: [ind('w1', 'Ahmet', '2026-07-02', AttendanceStatus.full, 200000)],
      );
      expect(g.rows.single.cells['2026-07-02']!.overtimeHours, 0);
    });

    test('"Yok" günündeki mesai hücrede de sayılmaz', () {
      final g = buildMonthlyGrid(
        monthIso: '2026-07',
        workers: [worker('w1', 'Ahmet', WorkerType.gundelik)],
        records: [
          withOvertime('2026-07-02', AttendanceStatus.absent, hours: 3),
        ],
      );
      final cell = g.rows.single.cells['2026-07-02']!;
      expect(cell.overtimeHours, 0);
      expect(cell.earningKurus, 0);
    });

    test('elebaşı hücresinde mesai yok', () {
      final g = buildMonthlyGrid(
        monthIso: '2026-07',
        workers: [worker('e1', 'Usta', WorkerType.elebasi)],
        records: [crew('e1', 'Usta', '2026-07-02', 4, 150000)],
      );
      expect(g.rows.single.cells['2026-07-02']!.overtimeHours, 0);
    });
  });

  test('güncel işçi adı yoklama kaydındaki addan önceliklidir', () {
    final g = buildMonthlyGrid(
      monthIso: '2026-07',
      workers: [worker('w1', 'Ahmet Yeni', WorkerType.gundelik)],
      records: [
        ind('w1', 'Ahmet Eski', '2026-07-01', AttendanceStatus.full, 200000),
      ],
    );
    expect(g.rows.single.workerName, 'Ahmet Yeni');
  });
}

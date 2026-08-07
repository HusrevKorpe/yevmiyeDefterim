import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/reports/application/work_cost.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

/// Tarla/iş bazlı maliyet saf builder testleri (kural §11): gruplama, yevmiye
/// sayımı (tam/yarım/kişi-gün), seçimsiz kalıntı satır, aralık süzme, sıralama.
///
/// Gövdedeki testler YAPILAN İŞ kırılımını sürer ([build] varsayılanı); aynı
/// hesap tarla için de çalışır, bu dosyanın sonundaki grup onu ve iki kırılımın
/// bağımsızlığını sınar.
void main() {
  const start = '2026-07-01';
  const end = '2026-07-31';

  AttendanceRecord ind(
    String worker,
    String date,
    AttendanceStatus status, {
    int wage = 200000,
    String? jobId,
    String? jobName,
    String? plotId,
    String? plotName,
  }) =>
      AttendanceRecord.individual(
        id: '${date}_$worker',
        date: date,
        workerId: worker,
        workerName: worker,
        workerType: WorkerType.gundelik,
        status: status,
        wageSnapshotKurus: wage,
        jobId: jobId,
        jobName: jobName,
        plotId: plotId,
        plotName: plotName,
      );

  AttendanceRecord crew(
    String worker,
    String date,
    int headcount, {
    int rate = 150000,
    String? jobId,
    String? jobName,
  }) =>
      AttendanceRecord.crew(
        id: '${date}_$worker',
        date: date,
        workerId: worker,
        workerName: worker,
        headcount: headcount,
        crewRateSnapshotKurus: rate,
        jobId: jobId,
        jobName: jobName,
      );

  List<WorkCost> build(
    List<AttendanceRecord> attendance, {
    CostGroupKind kind = CostGroupKind.job,
  }) =>
      buildWorkCosts(
        startIso: start,
        endIso: end,
        attendance: attendance,
        kind: kind,
      );

  test('boş girdi → boş liste', () {
    expect(build(const []), isEmpty);
  });

  test('tarlaya göre gruplama: yevmiye, gün, işçi ve brüt toplanır', () {
    final costs = build([
      ind('a', '2026-07-02', AttendanceStatus.full, jobId: 'f1', jobName: 'Dere'),
      ind('b', '2026-07-02', AttendanceStatus.half, jobId: 'f1', jobName: 'Dere'),
      ind('a', '2026-07-03', AttendanceStatus.full, jobId: 'f1', jobName: 'Dere'),
    ]);

    final dere = costs.single;
    expect(dere.groupId, 'f1');
    expect(dere.groupName, 'Dere');
    // 1 + 0,5 + 1 = 2,5 yevmiye
    expect(dere.workdays, 2.5);
    expect(dere.dayCount, 2);
    expect(dere.workerCount, 2);
    expect(dere.grossKurus, 200000 + 100000 + 200000);
  });

  test('elebaşı: yevmiye = kişi sayısı (kişi-gün), brüt snapshot okunur', () {
    final costs = build([
      crew('e', '2026-07-02', 4, jobId: 'f1', jobName: 'Dere'),
      crew('e', '2026-07-03', 3, jobId: 'f1', jobName: 'Dere'),
    ]);

    final dere = costs.single;
    expect(dere.workdays, 7);
    expect(dere.dayCount, 2);
    expect(dere.workerCount, 1);
    expect(dere.grossKurus, 7 * 150000);
    expect(dere.workers.single.isCrew, isTrue);
  });

  test('tarlası seçilmemiş kayıtlar ayrı satırda toplanır (para kaybolmaz)', () {
    final costs = build([
      ind('a', '2026-07-02', AttendanceStatus.full, jobId: 'f1', jobName: 'Dere'),
      ind('b', '2026-07-02', AttendanceStatus.full), // tarla seçilmemiş
    ]);

    expect(costs.length, 2);
    final bos = costs.firstWhere((f) => f.isUnassigned);
    expect(bos.groupId, isNull);
    expect(bos.groupName, kUnassignedJobLabel);
    expect(bos.grossKurus, 200000);
    expect(totalWorkGross(costs), 400000);
  });

  test('"seçilmemiş" satırı tutarı en büyük olsa bile EN SONA konur', () {
    final costs = build([
      ind('a', '2026-07-02', AttendanceStatus.full, wage: 900000), // tarlasız
      ind('b', '2026-07-02', AttendanceStatus.full,
          wage: 100000, jobId: 'f1', jobName: 'Dere'),
    ]);
    expect(costs.map((f) => f.groupName).toList(), ['Dere', kUnassignedJobLabel]);
  });

  test('sıralama: brüte göre azalan, eşitlikte ada göre', () {
    final costs = build([
      ind('a', '2026-07-02', AttendanceStatus.full,
          wage: 100000, jobId: 'f1', jobName: 'Bahçe'),
      ind('b', '2026-07-02', AttendanceStatus.full,
          wage: 500000, jobId: 'f2', jobName: 'Dere'),
      ind('c', '2026-07-02', AttendanceStatus.full,
          wage: 100000, jobId: 'f3', jobName: 'Ağıl'),
    ]);
    expect(costs.map((f) => f.groupName).toList(), ['Dere', 'Ağıl', 'Bahçe']);
  });

  test('çalışılmayan kayıt tarlaya maliyet yazmaz (yok / 0 kişi)', () {
    final costs = build([
      ind('a', '2026-07-02', AttendanceStatus.absent,
          jobId: 'f1', jobName: 'Dere'),
      crew('e', '2026-07-03', 0, jobId: 'f1', jobName: 'Dere'),
    ]);
    expect(costs, isEmpty, reason: 'kazanç 0 olan gün "çalışılan gün" değildir');
  });

  test('dönem dışı yoklama süzülür', () {
    final costs = build([
      ind('a', '2026-07-02', AttendanceStatus.full, jobId: 'f1', jobName: 'Dere'),
      ind('a', '2026-08-05', AttendanceStatus.full, jobId: 'f1', jobName: 'Dere'),
      ind('a', '2026-06-30', AttendanceStatus.full, jobId: 'f1', jobName: 'Dere'),
    ]);
    expect(costs.single.workdays, 1);
    expect(costs.single.grossKurus, 200000);
  });

  test('tarla adı değişse bile ID ile tek satır; en son kaydın adı gösterilir',
      () {
    final costs = build([
      ind('a', '2026-07-02', AttendanceStatus.full,
          jobId: 'f1', jobName: 'Eski Ad'),
      ind('a', '2026-07-10', AttendanceStatus.full,
          jobId: 'f1', jobName: 'Yeni Ad'),
    ]);
    expect(costs.single.groupName, 'Yeni Ad');
    expect(costs.single.workdays, 2);
  });

  test('adı boş/silinmiş kayıt satırı düşürmez (yedek ad)', () {
    final costs = build([
      ind('a', '2026-07-02', AttendanceStatus.full, jobId: 'f1'),
    ]);
    expect(costs.single.groupId, 'f1');
    expect(costs.single.groupName, 'İş');
  });

  test('işçi dökümü: brüte göre azalan, tarla bazında ayrı toplanır', () {
    final costs = build([
      ind('a', '2026-07-02', AttendanceStatus.full,
          jobId: 'f1', jobName: 'Dere'),
      ind('a', '2026-07-03', AttendanceStatus.full,
          jobId: 'f2', jobName: 'Bahçe'),
      ind('b', '2026-07-02', AttendanceStatus.half,
          jobId: 'f1', jobName: 'Dere'),
    ]);

    final dere = costs.firstWhere((f) => f.groupId == 'f1');
    expect(dere.workers.map((w) => w.workerId).toList(), ['a', 'b']);
    expect(dere.workers.first.grossKurus, 200000);
    expect(dere.workers.last.workdays, 0.5);

    // Aynı işçinin diğer tarladaki günü buraya sızmaz.
    final bahce = costs.firstWhere((f) => f.groupId == 'f2');
    expect(bahce.workers.single.grossKurus, 200000);
  });

  test('yevmiye biçimi: tam sayı "6", yarımlı "6,5"', () {
    expect(formatWorkdays(6), '6');
    expect(formatWorkdays(6.5), '6,5');
    expect(formatWorkdays(0.5), '0,5');
    expect(formatWorkdays(0), '0');
  });

  // --- İki kırılım: tarla ve yapılan iş (2026-08-07 ayrımı) ---
  //
  // Aynı yoklama listesi iki farklı boyuttan gruplanır. Toplamların EŞİT olması
  // sözleşmedir: rapor "çifte sayım yok" der, iki kırılım aynı parayı anlatır.

  group('CostGroupKind — tarla / iş kırılımları', () {
    final records = [
      // Aşağı Tarla'da çapa
      ind('a', '2026-07-02', AttendanceStatus.full,
          jobId: 'i1', jobName: 'Çapa', plotId: 't1', plotName: 'Aşağı Tarla'),
      // Aşağı Tarla'da sulama
      ind('b', '2026-07-02', AttendanceStatus.full,
          jobId: 'i2',
          jobName: 'Sulama',
          plotId: 't1',
          plotName: 'Aşağı Tarla'),
      // Yukarı Bağ'da çapa
      ind('c', '2026-07-03', AttendanceStatus.full,
          jobId: 'i1', jobName: 'Çapa', plotId: 't2', plotName: 'Yukarı Bağ'),
    ];

    test('tarla kırılımı tarlaya, iş kırılımı işe göre gruplar', () {
      final plots = build(records, kind: CostGroupKind.plot);
      expect(plots.map((c) => c.groupName).toList(),
          ['Aşağı Tarla', 'Yukarı Bağ']);
      expect(plots.first.grossKurus, 400000); // iki işçi aynı tarlada
      expect(plots.first.workerCount, 2);

      final jobs = build(records, kind: CostGroupKind.job);
      expect(jobs.map((c) => c.groupName).toList(), ['Çapa', 'Sulama']);
      expect(jobs.first.grossKurus, 400000); // çapa iki tarlada
      expect(jobs.first.workerCount, 2);
    });

    test('iki kırılımın toplamı eşittir (çifte sayım değil)', () {
      expect(
        totalWorkGross(build(records, kind: CostGroupKind.plot)),
        totalWorkGross(build(records, kind: CostGroupKind.job)),
      );
    });

    test('yalnız biri seçilmişse diğeri tek "seçilmemiş" satırına düşer', () {
      // 2026-08-07 öncesi tüm geçmişin hâli: iş dolu, tarla boş.
      final onlyJob = [
        ind('a', '2026-07-02', AttendanceStatus.full,
            jobId: 'i1', jobName: 'Çapa'),
      ];

      final plots = build(onlyJob, kind: CostGroupKind.plot);
      expect(plots.single.isUnassigned, isTrue);
      expect(plots.single.groupName, kUnassignedPlotLabel);
      expect(hasAssignedCosts(plots), isFalse); // rapor bölümü gösterilmez

      final jobs = build(onlyJob, kind: CostGroupKind.job);
      expect(jobs.single.groupName, 'Çapa');
      expect(hasAssignedCosts(jobs), isTrue);
    });

    test('yedek ad kırılıma göredir (silinmiş öğe, adı da boş)', () {
      final orphan = [
        ind('a', '2026-07-02', AttendanceStatus.full, jobId: 'i1', plotId: 't1'),
      ];
      expect(build(orphan, kind: CostGroupKind.plot).single.groupName, 'Tarla');
      expect(build(orphan, kind: CostGroupKind.job).single.groupName, 'İş');
    });
  });
}

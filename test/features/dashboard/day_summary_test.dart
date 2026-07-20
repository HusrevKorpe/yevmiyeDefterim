import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/dashboard/application/day_summary.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

void main() {
  AttendanceRecord ind(String id, AttendanceStatus status, int wage) =>
      AttendanceRecord.individual(
        id: id,
        date: '2026-07-18',
        workerId: id,
        workerName: id,
        workerType: WorkerType.gundelik,
        status: status,
        wageSnapshotKurus: wage,
      );

  AttendanceRecord crew(String id, int headcount, int rate) =>
      AttendanceRecord.crew(
        id: id,
        date: '2026-07-18',
        workerId: id,
        workerName: id,
        headcount: headcount,
        crewRateSnapshotKurus: rate,
      );

  test('boş liste → sıfır özet', () {
    expect(summarizeDay(const []), const DaySummary());
  });

  test('karışık gün — sayılar ve toplam doğru', () {
    final s = summarizeDay([
      ind('a', AttendanceStatus.full, 200000), // 200000
      ind('b', AttendanceStatus.full, 180000), // 180000
      ind('c', AttendanceStatus.half, 200000), // 100000
      ind('d', AttendanceStatus.absent, 200000), // 0
      crew('e', 5, 150000), // 750000
    ]);
    expect(s.fullCount, 2);
    expect(s.halfCount, 1);
    expect(s.absentCount, 1);
    expect(s.crewHeadcount, 5);
    expect(s.crewCount, 1);
    expect(s.totalKurus, 200000 + 180000 + 100000 + 0 + 750000);
    expect(s.markedIndividuals, 4);
    expect(s.presentIndividuals, 3);
  });

  test('0 kişili elebaşı crewCount saymaz ama kayıt sayılır', () {
    final s = summarizeDay([crew('e', 0, 150000)]);
    expect(s.crewCount, 0);
    expect(s.crewHeadcount, 0);
    expect(s.totalKurus, 0);
  });

  test('sadece yarım günler', () {
    final s = summarizeDay([
      ind('a', AttendanceStatus.half, 200000),
      ind('b', AttendanceStatus.half, 200001),
    ]);
    expect(s.halfCount, 2);
    expect(s.presentIndividuals, 2);
    expect(s.totalKurus, 100000 + 100000); // 200001~/2 = 100000
  });

  test('birden fazla elebaşı toplanır', () {
    final s = summarizeDay([
      crew('e1', 3, 150000),
      crew('e2', 2, 160000),
    ]);
    expect(s.crewCount, 2);
    expect(s.crewHeadcount, 5);
    expect(s.totalKurus, 3 * 150000 + 2 * 160000);
  });

  test('cinsiyet — yalnız gelenler (tam/yarım) kadın/erkek sayılır', () {
    final s = summarizeDay(
      [
        ind('kadin_tam', AttendanceStatus.full, 200000),
        ind('kadin_yarim', AttendanceStatus.half, 200000),
        ind('erkek_tam', AttendanceStatus.full, 200000),
        ind('erkek_yok', AttendanceStatus.absent, 200000), // gelmedi → sayılmaz
      ],
      genderById: const {
        'kadin_tam': Gender.female,
        'kadin_yarim': Gender.female,
        'erkek_tam': Gender.male,
        'erkek_yok': Gender.male,
      },
    );
    expect(s.femaleCount, 2);
    expect(s.maleCount, 1);
    expect(s.presentIndividuals, 3);
  });

  test('cinsiyet haritası boş → kadın/erkek 0, diğer sayılar bozulmaz', () {
    final s = summarizeDay([
      ind('a', AttendanceStatus.full, 200000),
      ind('b', AttendanceStatus.half, 200000),
    ]);
    expect(s.femaleCount, 0);
    expect(s.maleCount, 0);
    expect(s.presentIndividuals, 2);
  });

  test('cinsiyeti bilinmeyen işçi hiçbir yana sayılmaz', () {
    final s = summarizeDay(
      [ind('bilinmeyen', AttendanceStatus.full, 200000)],
      genderById: const {},
    );
    expect(s.femaleCount, 0);
    expect(s.maleCount, 0);
    expect(s.fullCount, 1);
  });
}

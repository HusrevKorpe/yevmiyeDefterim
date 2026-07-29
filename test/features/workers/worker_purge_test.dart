import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/workers/application/worker_purge.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../../support/fake_advance_repository.dart';
import '../../support/fake_attendance_repository.dart';
import '../../support/fake_worker_repository.dart';

/// Kalıntı (deneme) işçi verisinin temizlenmesi: aylık tablo satırları yoklama
/// kayıtlarından türediği için satırın kaybolması ancak kayıtların silinmesiyle
/// olur. Temizlik SADECE hedef işçiyi etkilemeli.
void main() {
  AttendanceRecord ind(String workerId, String name, String date) =>
      AttendanceRecord.individual(
        id: '${date}_$workerId',
        date: date,
        workerId: workerId,
        workerName: name,
        workerType: WorkerType.gundelik,
        status: AttendanceStatus.full,
        wageSnapshotKurus: 200000,
      );

  Advance adv(String id, String workerId, String name) => Advance(
        id: id,
        workerId: workerId,
        workerName: name,
        amountKurus: 50000,
        date: '2026-07-10',
      );

  late FakeAttendanceRepository attendance;
  late FakeAdvanceRepository advances;
  late FakeWorkerRepository workers;

  setUp(() async {
    attendance = FakeAttendanceRepository();
    advances = FakeAdvanceRepository([
      adv('a1', 'wTest', 'Hüsrev Deneme'),
      adv('a2', 'wTest', 'Hüsrev Deneme'),
      adv('a3', 'w1', 'Ahmet'),
    ]);
    workers = FakeWorkerRepository();
    // Deneme işçisi FARKLI aylara yayılmış kayıtlar bırakmış olsun.
    await attendance.save(ind('wTest', 'Hüsrev Deneme', '2026-06-30'));
    await attendance.save(ind('wTest', 'Hüsrev Deneme', '2026-07-02'));
    await attendance.save(ind('wTest', 'Hüsrev Deneme', '2026-07-03'));
    await attendance.save(ind('w1', 'Ahmet', '2026-07-02'));
    await workers.add(const Worker(
      id: 'wTest',
      name: 'Hüsrev Deneme',
      type: WorkerType.gundelik,
      gender: Gender.male,
      active: false, // pasife alınmış (soft-delete)
    ));
    await workers.add(const Worker(
      id: 'w1',
      name: 'Ahmet',
      type: WorkerType.gundelik,
      gender: Gender.male,
    ));
  });

  Future<WorkerPurgeResult> purge(String workerId) => purgeWorkerRecords(
        attendance: attendance,
        advances: advances,
        workers: workers,
        workerId: workerId,
      );

  test('işçinin tüm yoklama kayıtları TÜM aylardan silinir', () async {
    final result = await purge('wTest');

    expect(result.attendanceCount, 3);
    expect(attendance.all.map((r) => r.workerId).toSet(), {'w1'});
  });

  test('işçinin avansları da silinir, başkasınınki durur', () async {
    final result = await purge('wTest');

    expect(result.advanceCount, 2);
    expect(advances.all.map((a) => a.id).toList(), ['a3']);
  });

  test('pasif işçi dokümanı da kaldırılır (boş satır kalmaz)', () async {
    await purge('wTest');

    final list = await workers.watchAll().first;
    expect(list.map((w) => w.id).toList(), ['w1']);
  });

  test('kaydı olmayan işçide sayaçlar 0, özet uyarır', () async {
    final result = await purge('yok');

    expect(result.isEmpty, isTrue);
    expect(result.summary, 'Silinecek kayıt bulunamadı');
    expect(attendance.count, 4);
    expect(advances.count, 3);
  });

  test('özet yalnız dolu türleri sayar', () async {
    expect(
      const WorkerPurgeResult(attendanceCount: 3, advanceCount: 2).summary,
      '3 yoklama, 2 avans kaydı silindi',
    );
    expect(
      const WorkerPurgeResult(attendanceCount: 3, advanceCount: 0).summary,
      '3 yoklama kaydı silindi',
    );
  });
}

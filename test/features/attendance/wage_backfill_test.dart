/// Ücreti girilmeden (₺0) kaydedilmiş günleri sonradan fiyatlama testleri.
///
/// Saha hatası (2026-08-03): elebaşı kişi-başı yevmiyesiz açıldı, günler ₺0
/// donduruldu; ücret sonradan girilince "görünmüyor" kaldı.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/attendance/application/wage_backfill.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../../support/fake_attendance_repository.dart';

AttendanceRecord _crew({
  required String date,
  int headcount = 5,
  int rate = 0,
  int? agreedPay,
  String workerId = 'eA',
}) =>
    AttendanceRecord.crew(
      id: '${date}_$workerId',
      date: date,
      workerId: workerId,
      workerName: 'Elebaşı A',
      headcount: headcount,
      crewRateSnapshotKurus: rate,
      agreedPayKurus: agreedPay,
    );

AttendanceRecord _individual({
  required String date,
  AttendanceStatus status = AttendanceStatus.full,
  int wage = 0,
  String workerId = 'w1',
}) =>
    AttendanceRecord.individual(
      id: '${date}_$workerId',
      date: date,
      workerId: workerId,
      workerName: 'Ali',
      workerType: WorkerType.gundelik,
      status: status,
      wageSnapshotKurus: wage,
    );

void main() {
  group('repriceUnpricedDays', () {
    test('elebaşının ₺0 günleri yeni kişi-başı ücretle fiyatlanır', () {
      final out = repriceUnpricedDays([
        _crew(date: '2026-07-01'),
        _crew(date: '2026-07-02', headcount: 3),
      ], 100000);

      expect(out, hasLength(2));
      expect(
        out.map((r) => (r as CrewAttendance).crewRateSnapshotKurus),
        everyElement(100000),
      );
      // Kazanç artık kişi × ücret.
      expect(out.first.earningKurus, 5 * 100000);
    });

    test('ücreti dondurulmuş gün DEĞİŞMEZ (kural §4)', () {
      final out = repriceUnpricedDays([
        _crew(date: '2026-07-01', rate: 80000),
        _individual(date: '2026-07-01', wage: 150000),
      ], 100000);

      expect(out, isEmpty);
    });

    test('kazanca girmeyen günler atlanır (0 kişi, "Yok")', () {
      final out = repriceUnpricedDays([
        _crew(date: '2026-07-01', headcount: 0),
        _individual(date: '2026-07-01', status: AttendanceStatus.absent),
      ], 100000);

      expect(out, isEmpty);
    });

    test('toplu anlaşma tutarlı elebaşı günü atlanır', () {
      final out = repriceUnpricedDays([
        _crew(date: '2026-07-01', agreedPay: 500000),
      ], 100000);

      expect(out, isEmpty);
    });

    test('bireysel yarım gün de fiyatlanır (yarım yevmiye)', () {
      final out = repriceUnpricedDays([
        _individual(date: '2026-07-01', status: AttendanceStatus.half),
      ], 200000);

      expect(out, hasLength(1));
      expect(out.single.earningKurus, 100000);
    });

    test('ücret 0/negatifse hiçbir şey yapılmaz', () {
      final records = [_crew(date: '2026-07-01')];
      expect(repriceUnpricedDays(records, 0), isEmpty);
      expect(repriceUnpricedDays(records, -1), isEmpty);
    });

    test('tarla/kişi sayısı gibi diğer alanlar korunur', () {
      final r = AttendanceRecord.crew(
        id: '2026-07-01_eA',
        date: '2026-07-01',
        workerId: 'eA',
        workerName: 'Elebaşı A',
        headcount: 7,
        crewRateSnapshotKurus: 0,
        fieldId: 'f1',
        fieldName: 'Üst Tarla',
      );

      final out = repriceUnpricedDays([r], 90000).single as CrewAttendance;
      expect(out.id, r.id);
      expect(out.headcount, 7);
      expect(out.fieldId, 'f1');
      expect(out.fieldName, 'Üst Tarla');
    });
  });

  group('findUnpricedDays / applyRepricedDays', () {
    test('yalnız o işçinin ₺0 günlerini bulur ve yazar', () async {
      final repo = FakeAttendanceRepository();
      await repo.save(_crew(date: '2026-07-01'));
      await repo.save(_crew(date: '2026-07-02'));
      await repo.save(_crew(date: '2026-07-03', rate: 70000));
      // Başka elebaşının ₺0 günü — dokunulmamalı.
      await repo.save(_crew(date: '2026-07-01', workerId: 'eB'));

      final pending = await findUnpricedDays(
        attendance: repo,
        workerId: 'eA',
        rateKurus: 100000,
      );
      expect(pending, hasLength(2));

      final written =
          await applyRepricedDays(attendance: repo, records: pending);
      expect(written, 2);

      final byId = {for (final r in repo.all) r.id: r as CrewAttendance};
      expect(byId['2026-07-01_eA']!.crewRateSnapshotKurus, 100000);
      expect(byId['2026-07-02_eA']!.crewRateSnapshotKurus, 100000);
      expect(byId['2026-07-03_eA']!.crewRateSnapshotKurus, 70000); // korundu
      expect(byId['2026-07-01_eB']!.crewRateSnapshotKurus, 0); // başka işçi
    });

    test('fiyatlanacak gün yoksa yazma yapılmaz', () async {
      final repo = FakeAttendanceRepository();
      await repo.save(_crew(date: '2026-07-01', rate: 70000));

      final pending = await findUnpricedDays(
        attendance: repo,
        workerId: 'eA',
        rateKurus: 100000,
      );
      expect(pending, isEmpty);
      expect(await applyRepricedDays(attendance: repo, records: pending), 0);
    });
  });
}

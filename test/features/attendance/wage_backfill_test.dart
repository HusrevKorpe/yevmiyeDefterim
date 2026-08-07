/// Yevmiye değişince geçmiş günlerin yeniden fiyatlanması.
///
/// Kural (müşteri talebi 2026-08-07): zam "o günden sonrasına" değil, HESABI
/// GÖRÜLMEMİŞ tüm günlere işler. Son "Hesap görüldü" tarihi ve öncesi kapanmış
/// sayılır → dokunulmaz. İstisna: kapanış öncesinde ücretsiz (₺0) kalmış günler
/// eksik veridir, onlar yine fiyatlanır (saha hatası 2026-08-03).
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
  group('repriceDays — kapanış yokken', () {
    test('₺0 günler yeni kişi-başı ücretle fiyatlanır', () {
      final out = repriceDays([
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

    test('ücreti dondurulmuş günler de zamlanır (hesap görülmemiş)', () {
      final out = repriceDays([
        _crew(date: '2026-07-01', rate: 80000),
        _individual(date: '2026-07-01', wage: 80000),
      ], 100000);

      expect(out, hasLength(2));
      expect((out.first as CrewAttendance).crewRateSnapshotKurus, 100000);
      expect((out.last as IndividualAttendance).wageSnapshotKurus, 100000);
    });

    test('yevmiye düşürülürse de geçmişe işler', () {
      final out = repriceDays([_individual(date: '2026-07-01', wage: 150000)],
          100000);

      expect((out.single as IndividualAttendance).wageSnapshotKurus, 100000);
    });

    test('zaten aynı ücretle dondurulmuş gün listeye girmez', () {
      final out = repriceDays([
        _crew(date: '2026-07-01', rate: 100000),
        _individual(date: '2026-07-01', wage: 100000),
      ], 100000);

      expect(out, isEmpty);
    });

    test('kazanca girmeyen günler atlanır (0 kişi, "Yok")', () {
      final out = repriceDays([
        _crew(date: '2026-07-01', headcount: 0),
        _individual(date: '2026-07-01', status: AttendanceStatus.absent),
      ], 100000);

      expect(out, isEmpty);
    });

    test('toplu anlaşma tutarlı elebaşı günü atlanır', () {
      final out = repriceDays([
        _crew(date: '2026-07-01', agreedPay: 500000),
      ], 100000);

      expect(out, isEmpty);
    });

    test('bireysel yarım gün de fiyatlanır (yarım yevmiye)', () {
      final out = repriceDays([
        _individual(date: '2026-07-01', status: AttendanceStatus.half),
      ], 200000);

      expect(out, hasLength(1));
      expect(out.single.earningKurus, 100000);
    });

    test('ücret 0/negatifse hiçbir şey yapılmaz', () {
      final records = [_crew(date: '2026-07-01')];
      expect(repriceDays(records, 0), isEmpty);
      expect(repriceDays(records, -1), isEmpty);
    });

    test('tarla/kişi sayısı gibi diğer alanlar korunur', () {
      final r = AttendanceRecord.crew(
        id: '2026-07-01_eA',
        date: '2026-07-01',
        workerId: 'eA',
        workerName: 'Elebaşı A',
        headcount: 7,
        crewRateSnapshotKurus: 0,
        jobId: 'f1',
        jobName: 'Üst Tarla',
      );

      final out = repriceDays([r], 90000).single as CrewAttendance;
      expect(out.id, r.id);
      expect(out.headcount, 7);
      expect(out.jobId, 'f1');
      expect(out.jobName, 'Üst Tarla');
    });

    test('mesai saat ücretine dokunulmaz (yevmiyeden ayrı)', () {
      final r = AttendanceRecord.individual(
        id: '2026-07-01_w1',
        date: '2026-07-01',
        workerId: 'w1',
        workerName: 'Ali',
        workerType: WorkerType.gundelik,
        status: AttendanceStatus.full,
        wageSnapshotKurus: 80000,
        overtimeHours: 2,
        overtimeRateSnapshotKurus: 10000,
      );

      final out = repriceDays([r], 100000).single as IndividualAttendance;
      expect(out.wageSnapshotKurus, 100000);
      expect(out.overtimeRateSnapshotKurus, 10000);
      expect(out.overtimeHours, 2);
      expect(out.earningKurus, 100000 + 2 * 10000);
    });
  });

  group('repriceDays — "Hesap görüldü" sınırı', () {
    test('yalnız kapanıştan SONRAKİ günler zamlanır', () {
      final out = repriceDays(
        [
          _individual(date: '2026-08-01', wage: 100000), // kapanış öncesi
          _individual(date: '2026-08-02', wage: 100000), // kapanış GÜNÜ
          _individual(date: '2026-08-03', wage: 100000),
          _individual(date: '2026-08-17', wage: 100000),
        ],
        120000,
        settledThrough: '2026-08-02',
      );

      expect(out.map((r) => r.date), ['2026-08-03', '2026-08-17']);
      expect(
        out.map((r) => (r as IndividualAttendance).wageSnapshotKurus),
        everyElement(120000),
      );
    });

    test('kapanış öncesinde ücretsiz (₺0) kalmış gün yine fiyatlanır', () {
      final out = repriceDays(
        [
          _crew(date: '2026-08-01'), // ₺0 → eksik veri, fiyatlanır
          _crew(date: '2026-08-02', rate: 90000), // kapanış günü, fiyatlı
          _crew(date: '2026-08-05', rate: 90000), // kapanış sonrası → zam
        ],
        120000,
        settledThrough: '2026-08-02',
      );

      expect(out.map((r) => r.date), ['2026-08-01', '2026-08-05']);
    });

    test('kapanıştan sonra hiç gün yoksa boş döner', () {
      final out = repriceDays(
        [_individual(date: '2026-08-01', wage: 100000)],
        120000,
        settledThrough: '2026-08-02',
      );

      expect(out, isEmpty);
    });
  });

  group('findRepriceableDays / applyRepricedDays', () {
    test('yalnız o işçinin kapanış sonrası günlerini bulur ve yazar', () async {
      final repo = FakeAttendanceRepository();
      await repo.save(_crew(date: '2026-08-01', rate: 90000)); // kapanış öncesi
      await repo.save(_crew(date: '2026-08-03', rate: 90000));
      await repo.save(_crew(date: '2026-08-04')); // ₺0, kapanış sonrası
      // Başka elebaşının günü — dokunulmamalı.
      await repo.save(_crew(date: '2026-08-03', workerId: 'eB', rate: 90000));

      final pending = await findRepriceableDays(
        attendance: repo,
        workerId: 'eA',
        rateKurus: 100000,
        settledThrough: '2026-08-02',
      );
      expect(pending, hasLength(2));

      final written =
          await applyRepricedDays(attendance: repo, records: pending);
      expect(written, 2);

      final byId = {for (final r in repo.all) r.id: r as CrewAttendance};
      expect(byId['2026-08-03_eA']!.crewRateSnapshotKurus, 100000);
      expect(byId['2026-08-04_eA']!.crewRateSnapshotKurus, 100000);
      expect(byId['2026-08-01_eA']!.crewRateSnapshotKurus, 90000); // korundu
      expect(byId['2026-08-03_eB']!.crewRateSnapshotKurus, 90000); // başka işçi
    });

    test('fiyatlanacak gün yoksa yazma yapılmaz', () async {
      final repo = FakeAttendanceRepository();
      await repo.save(_crew(date: '2026-07-01', rate: 100000));

      final pending = await findRepriceableDays(
        attendance: repo,
        workerId: 'eA',
        rateKurus: 100000,
      );
      expect(pending, isEmpty);
      expect(await applyRepricedDays(attendance: repo, records: pending), 0);
    });
  });
}

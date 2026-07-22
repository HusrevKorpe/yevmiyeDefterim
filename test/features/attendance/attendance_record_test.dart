import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

void main() {
  AttendanceRecord ind(AttendanceStatus status, int wage) =>
      AttendanceRecord.individual(
        id: '2026-07-18_w1',
        date: '2026-07-18',
        workerId: 'w1',
        workerName: 'Ahmet',
        workerType: WorkerType.gundelik,
        status: status,
        wageSnapshotKurus: wage,
      );

  AttendanceRecord crew(int headcount, int rate, {int? agreed}) =>
      AttendanceRecord.crew(
        id: '2026-07-18_e1',
        date: '2026-07-18',
        workerId: 'e1',
        workerName: 'Usta',
        headcount: headcount,
        crewRateSnapshotKurus: rate,
        agreedPayKurus: agreed,
      );

  group('earningKurus — bireysel (snapshot okunur, kural §4)', () {
    test('tam gün = snapshot ücret', () {
      expect(ind(AttendanceStatus.full, 200000).earningKurus, 200000);
    });
    test('yarım gün = ücret ~/ 2', () {
      expect(ind(AttendanceStatus.half, 200000).earningKurus, 100000);
    });
    test('yarım gün tek kuruş aşağı yuvarlanır (150001 → 75000)', () {
      expect(ind(AttendanceStatus.half, 150001).earningKurus, 75000);
    });
    test('yok = 0', () {
      expect(ind(AttendanceStatus.absent, 200000).earningKurus, 0);
    });
    test('ücret 0 ise tam gün bile 0', () {
      expect(ind(AttendanceStatus.full, 0).earningKurus, 0);
    });
  });

  group('earningKurus — elebaşı', () {
    test('kişi × kişiücret', () {
      expect(crew(5, 150000).earningKurus, 750000);
    });
    test('0 kişi = 0', () {
      expect(crew(0, 150000).earningKurus, 0);
    });
    test('anlaşmalı ödeme (agreedPay) kişi hesabını ezer', () {
      expect(crew(5, 150000, agreed: 800000).earningKurus, 800000);
    });
    test('agreedPay 0 ise 0 (kişi hesabı yok sayılır)', () {
      expect(crew(5, 150000, agreed: 0).earningKurus, 0);
    });
  });

  group('fromDoc / toMap — round-trip ve tür ayrımı', () {
    test('bireysel round-trip', () {
      final r = ind(AttendanceStatus.half, 190000);
      expect(AttendanceRecord.fromDoc(r.id, r.toMap()), r);
    });

    test('elebaşı round-trip (agreedPay null)', () {
      final r = crew(4, 160000);
      expect(AttendanceRecord.fromDoc(r.id, r.toMap()), r);
    });

    test('elebaşı round-trip (agreedPay dolu)', () {
      final r = crew(4, 160000, agreed: 700000);
      expect(AttendanceRecord.fromDoc(r.id, r.toMap()), r);
    });

    test('workerType=elebasi → CrewAttendance üretir', () {
      final r = AttendanceRecord.fromDoc('x', {
        'date': '2026-07-18',
        'workerId': 'e1',
        'workerName': 'Usta',
        'workerType': 'elebasi',
        'headcount': 3,
        'crewRateSnapshotKurus': 150000,
      });
      expect(r, isA<CrewAttendance>());
      expect(r.earningKurus, 450000);
    });

    test('workerType=gundelik → IndividualAttendance üretir', () {
      final r = AttendanceRecord.fromDoc('x', {
        'date': '2026-07-18',
        'workerId': 'w1',
        'workerName': 'Ahmet',
        'workerType': 'gundelik',
        'status': 'full',
        'wageSnapshotKurus': 200000,
      });
      expect(r, isA<IndividualAttendance>());
      expect(r.earningKurus, 200000);
    });

    test('eksik/bozuk alanlar güvenli varsayılana düşer (bireysel)', () {
      final r = AttendanceRecord.fromDoc('x', {'workerType': 'sabit'});
      expect(r, isA<IndividualAttendance>());
      expect(r.earningKurus, 0); // status yok → absent, wage yok → 0
    });

    test('double sayılar int kuruşa iner', () {
      final r = AttendanceRecord.fromDoc('x', {
        'workerType': 'elebasi',
        'headcount': 3.0,
        'crewRateSnapshotKurus': 150000.0,
      });
      expect(r.earningKurus, 450000);
    });
  });

  group('fieldId/fieldName — çalışılan tarla (denormalize, kural §5)', () {
    test('varsayılan boş (tarla seçilmemiş)', () {
      final r = ind(AttendanceStatus.full, 200000);
      expect(r.fieldId, isNull);
      expect(r.fieldName, isNull);
    });

    test('bireysel round-trip (tarla dolu)', () {
      final r = AttendanceRecord.individual(
        id: '2026-07-18_w1',
        date: '2026-07-18',
        workerId: 'w1',
        workerName: 'Ahmet',
        workerType: WorkerType.gundelik,
        status: AttendanceStatus.full,
        wageSnapshotKurus: 200000,
        fieldId: 't1',
        fieldName: 'Aşağı Tarla',
      );
      expect(AttendanceRecord.fromDoc(r.id, r.toMap()), r);
    });

    test('elebaşı round-trip (tarla dolu)', () {
      final r = AttendanceRecord.crew(
        id: '2026-07-18_e1',
        date: '2026-07-18',
        workerId: 'e1',
        workerName: 'Usta',
        headcount: 4,
        crewRateSnapshotKurus: 160000,
        fieldId: 't2',
        fieldName: 'Yukarı Bağ',
      );
      expect(AttendanceRecord.fromDoc(r.id, r.toMap()), r);
    });

    test('toMap tarla null iken de alanı YAZAR (merge:true altında temizler)',
        () {
      final m = ind(AttendanceStatus.full, 200000).toMap();
      expect(m.containsKey('fieldId'), isTrue);
      expect(m['fieldId'], isNull);
      expect(m.containsKey('fieldName'), isTrue);
      expect(m['fieldName'], isNull);
    });

    test('tarla alanı olmayan eski doküman sorunsuz okunur (null)', () {
      final r = AttendanceRecord.fromDoc('x', {
        'workerType': 'gundelik',
        'status': 'full',
        'wageSnapshotKurus': 200000,
      });
      expect(r.fieldId, isNull);
      expect(r.fieldName, isNull);
    });
  });

  group('paidPayrollId / isPaid (çifte ödeme engeli — kural §6)', () {
    test('varsayılan ödenmemiş', () {
      expect(ind(AttendanceStatus.full, 200000).isPaid, isFalse);
      expect(crew(3, 150000).isPaid, isFalse);
    });

    test('fromDoc paidPayrollId okur → isPaid true (bireysel)', () {
      final r = AttendanceRecord.fromDoc('x', {
        'workerType': 'gundelik',
        'status': 'full',
        'wageSnapshotKurus': 200000,
        'paidPayrollId': 'p1',
      });
      expect(r.isPaid, isTrue);
      expect(r.paidPayrollId, 'p1');
    });

    test('fromDoc paidPayrollId okur → isPaid true (elebaşı)', () {
      final r = AttendanceRecord.fromDoc('x', {
        'workerType': 'elebasi',
        'headcount': 3,
        'crewRateSnapshotKurus': 150000,
        'paidPayrollId': 'p1',
      });
      expect(r.isPaid, isTrue);
    });

    test('toMap paidPayrollId YAZMAZ (yalnız Öde batch yazar — kural §3)', () {
      final r = AttendanceRecord.individual(
        id: '2026-07-18_w1',
        date: '2026-07-18',
        workerId: 'w1',
        workerName: 'Ahmet',
        workerType: WorkerType.gundelik,
        status: AttendanceStatus.full,
        wageSnapshotKurus: 200000,
        paidPayrollId: 'p1',
      );
      expect(r.toMap().containsKey('paidPayrollId'), isFalse);
    });
  });
}

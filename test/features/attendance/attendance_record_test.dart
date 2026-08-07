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

  group('jobId/jobName — yapılan iş (denormalize, kural §5)', () {
    test('varsayılan boş (iş seçilmemiş)', () {
      final r = ind(AttendanceStatus.full, 200000);
      expect(r.jobId, isNull);
      expect(r.jobName, isNull);
    });

    test('bireysel round-trip (iş dolu)', () {
      final r = AttendanceRecord.individual(
        id: '2026-07-18_w1',
        date: '2026-07-18',
        workerId: 'w1',
        workerName: 'Ahmet',
        workerType: WorkerType.gundelik,
        status: AttendanceStatus.full,
        wageSnapshotKurus: 200000,
        jobId: 't1',
        jobName: 'Aşağı Tarla',
      );
      expect(AttendanceRecord.fromDoc(r.id, r.toMap()), r);
    });

    test('elebaşı round-trip (iş dolu)', () {
      final r = AttendanceRecord.crew(
        id: '2026-07-18_e1',
        date: '2026-07-18',
        workerId: 'e1',
        workerName: 'Usta',
        headcount: 4,
        crewRateSnapshotKurus: 160000,
        jobId: 't2',
        jobName: 'Yukarı Bağ',
      );
      expect(AttendanceRecord.fromDoc(r.id, r.toMap()), r);
    });

    test('toMap iş null iken de alanı YAZAR (merge:true altında temizler)', () {
      final m = ind(AttendanceStatus.full, 200000).toMap();
      expect(m.containsKey('fieldId'), isTrue);
      expect(m['fieldId'], isNull);
      expect(m.containsKey('fieldName'), isTrue);
      expect(m['fieldName'], isNull);
    });

    test('iş alanı olmayan eski doküman sorunsuz okunur (null)', () {
      final r = AttendanceRecord.fromDoc('x', {
        'workerType': 'gundelik',
        'status': 'full',
        'wageSnapshotKurus': 200000,
      });
      expect(r.jobId, isNull);
      expect(r.jobName, isNull);
    });

    // GÖÇ SÖZLEŞMESİ (2026-08-07 tarla/iş ayrımı). Diskteki `fieldId`/
    // `fieldName` alanları TARİHSEL adlardır ve YAPILAN İŞ anlamına gelir:
    // ayrımdan önce tek liste vardı, adı "Tarla"ydı, içine hep iş yazılıyordu.
    // Liste yerinde bırakılıp anlamı düzeltildiği için tek bir doküman bile göç
    // etmedi. Bu eşleme bozulursa yıllarca girilmiş "çapa/sulama" kayıtları
    // sessizce tarla kırılımına düşer → aşağıdaki testler onu yakalar.
    test('eski doküman: fieldId/fieldName → YAPILAN İŞ olarak okunur', () {
      final r = AttendanceRecord.fromDoc('x', {
        'workerType': 'gundelik',
        'status': 'full',
        'wageSnapshotKurus': 200000,
        'fieldId': 'f1',
        'fieldName': 'Çapa',
      });
      expect(r.jobId, 'f1');
      expect(r.jobName, 'Çapa');
      // Ayrımdan önceki kayıtlarda tarla YOKTUR (beklenen).
      expect(r.plotId, isNull);
      expect(r.plotName, isNull);
    });

    test('toMap: iş diske `fieldId`, tarla `plotId` olarak yazılır', () {
      final m = AttendanceRecord.individual(
        id: '2026-08-07_w1',
        date: '2026-08-07',
        workerId: 'w1',
        workerName: 'Ahmet',
        workerType: WorkerType.gundelik,
        status: AttendanceStatus.full,
        wageSnapshotKurus: 200000,
        jobId: 'i1',
        jobName: 'Çapa',
        plotId: 't1',
        plotName: 'Aşağı Tarla',
      ).toMap();
      expect(m['fieldId'], 'i1');
      expect(m['fieldName'], 'Çapa');
      expect(m['plotId'], 't1');
      expect(m['plotName'], 'Aşağı Tarla');
    });
  });

  group('plotId/plotName — çalışılan tarla (denormalize, kural §5)', () {
    test('varsayılan boş (tarla seçilmemiş)', () {
      final r = ind(AttendanceStatus.full, 200000);
      expect(r.plotId, isNull);
      expect(r.plotName, isNull);
    });

    test('bireysel round-trip: tarla ve iş birlikte, birbirini bozmadan', () {
      final r = AttendanceRecord.individual(
        id: '2026-08-07_w1',
        date: '2026-08-07',
        workerId: 'w1',
        workerName: 'Ahmet',
        workerType: WorkerType.gundelik,
        status: AttendanceStatus.full,
        wageSnapshotKurus: 200000,
        jobId: 'i1',
        jobName: 'Çapa',
        plotId: 't1',
        plotName: 'Aşağı Tarla',
      );
      expect(AttendanceRecord.fromDoc(r.id, r.toMap()), r);
    });

    test('elebaşı round-trip: tarla ve iş birlikte', () {
      final r = AttendanceRecord.crew(
        id: '2026-08-07_e1',
        date: '2026-08-07',
        workerId: 'e1',
        workerName: 'Usta',
        headcount: 4,
        crewRateSnapshotKurus: 160000,
        jobId: 'i2',
        jobName: 'Sulama',
        plotId: 't2',
        plotName: 'Yukarı Bağ',
      );
      expect(AttendanceRecord.fromDoc(r.id, r.toMap()), r);
    });

    test('toMap tarla null iken de alanı YAZAR (merge:true altında temizler)',
        () {
      final m = ind(AttendanceStatus.full, 200000).toMap();
      expect(m.containsKey('plotId'), isTrue);
      expect(m['plotId'], isNull);
      expect(m.containsKey('plotName'), isTrue);
      expect(m['plotName'], isNull);
    });
  });

  group('mesai (overtime) — saat × dondurulmuş saat ücreti', () {
    AttendanceRecord withOvertime(
      AttendanceStatus status, {
      int wage = 200000,
      int hours = 0,
      int rate = 0,
    }) =>
        AttendanceRecord.individual(
          id: '2026-07-18_w1',
          date: '2026-07-18',
          workerId: 'w1',
          workerName: 'Ahmet',
          workerType: WorkerType.gundelik,
          status: status,
          wageSnapshotKurus: wage,
          overtimeHours: hours,
          overtimeRateSnapshotKurus: rate,
        );

    test('varsayılan mesai yok (0 saat, 0 tutar)', () {
      final r = ind(AttendanceStatus.full, 200000);
      expect(r.overtimeKurus, 0);
      expect(r.overtimeHoursCounted, 0);
      expect(r.earningKurus, 200000);
    });

    test('tam gün + 2 saat mesai = yevmiye + saat × ücret', () {
      final r = withOvertime(AttendanceStatus.full, hours: 2, rate: 10000);
      expect(r.overtimeKurus, 20000);
      expect(r.earningKurus, 220000);
    });

    test('yarım gün + mesai: yarım yevmiye üstüne mesai eklenir', () {
      final r = withOvertime(AttendanceStatus.half, hours: 3, rate: 10000);
      expect(r.earningKurus, 100000 + 30000);
    });

    test('"Yok" günde mesai sayılmaz (gelmeyen işçinin mesaisi olamaz)', () {
      final r = withOvertime(AttendanceStatus.absent, hours: 3, rate: 10000);
      expect(r.overtimeKurus, 0);
      expect(r.overtimeHoursCounted, 0);
      expect(r.earningKurus, 0);
    });

    test('saat ücreti girilmemişse (0) mesai tutarı 0 kalır', () {
      final r = withOvertime(AttendanceStatus.full, hours: 4);
      expect(r.overtimeKurus, 0);
      expect(r.earningKurus, 200000);
      // Saat bilgisi yine durur (kullanıcı ücreti sonradan girebilir).
      expect(r.overtimeHoursCounted, 4);
    });

    test('elebaşıda mesai yoktur → her zaman 0', () {
      expect(crew(5, 150000).overtimeKurus, 0);
      expect(crew(5, 150000).overtimeHoursCounted, 0);
    });

    test('round-trip (mesai dolu)', () {
      final r = withOvertime(AttendanceStatus.full, hours: 2, rate: 10000);
      expect(AttendanceRecord.fromDoc(r.id, r.toMap()), r);
    });

    test('toMap mesai 0 iken de alanları YAZAR (merge:true altında temizler)',
        () {
      final m = ind(AttendanceStatus.full, 200000).toMap();
      expect(m['overtimeHours'], 0);
      expect(m['overtimeRateSnapshotKurus'], 0);
    });

    test('mesai alanı olmayan eski doküman sorunsuz okunur (0 saat)', () {
      final r = AttendanceRecord.fromDoc('x', {
        'workerType': 'gundelik',
        'status': 'full',
        'wageSnapshotKurus': 200000,
      });
      expect(r.overtimeKurus, 0);
      expect(r.earningKurus, 200000);
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

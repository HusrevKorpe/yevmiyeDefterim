import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/reports/application/field_cost.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

/// Tarla bazlı maliyet saf builder testleri (kural §11): gruplama, yevmiye
/// sayımı (tam/yarım/kişi-gün), tarlasız kalıntı satır, aralık süzme, sıralama.
void main() {
  const start = '2026-07-01';
  const end = '2026-07-31';

  AttendanceRecord ind(
    String worker,
    String date,
    AttendanceStatus status, {
    int wage = 200000,
    String? fieldId,
    String? fieldName,
  }) =>
      AttendanceRecord.individual(
        id: '${date}_$worker',
        date: date,
        workerId: worker,
        workerName: worker,
        workerType: WorkerType.gundelik,
        status: status,
        wageSnapshotKurus: wage,
        fieldId: fieldId,
        fieldName: fieldName,
      );

  AttendanceRecord crew(
    String worker,
    String date,
    int headcount, {
    int rate = 150000,
    String? fieldId,
    String? fieldName,
  }) =>
      AttendanceRecord.crew(
        id: '${date}_$worker',
        date: date,
        workerId: worker,
        workerName: worker,
        headcount: headcount,
        crewRateSnapshotKurus: rate,
        fieldId: fieldId,
        fieldName: fieldName,
      );

  List<FieldCost> build(List<AttendanceRecord> attendance) => buildFieldCosts(
        startIso: start,
        endIso: end,
        attendance: attendance,
      );

  test('boş girdi → boş liste', () {
    expect(build(const []), isEmpty);
  });

  test('tarlaya göre gruplama: yevmiye, gün, işçi ve brüt toplanır', () {
    final costs = build([
      ind('a', '2026-07-02', AttendanceStatus.full, fieldId: 'f1', fieldName: 'Dere'),
      ind('b', '2026-07-02', AttendanceStatus.half, fieldId: 'f1', fieldName: 'Dere'),
      ind('a', '2026-07-03', AttendanceStatus.full, fieldId: 'f1', fieldName: 'Dere'),
    ]);

    final dere = costs.single;
    expect(dere.fieldId, 'f1');
    expect(dere.fieldName, 'Dere');
    // 1 + 0,5 + 1 = 2,5 yevmiye
    expect(dere.workdays, 2.5);
    expect(dere.dayCount, 2);
    expect(dere.workerCount, 2);
    expect(dere.grossKurus, 200000 + 100000 + 200000);
  });

  test('elebaşı: yevmiye = kişi sayısı (kişi-gün), brüt snapshot okunur', () {
    final costs = build([
      crew('e', '2026-07-02', 4, fieldId: 'f1', fieldName: 'Dere'),
      crew('e', '2026-07-03', 3, fieldId: 'f1', fieldName: 'Dere'),
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
      ind('a', '2026-07-02', AttendanceStatus.full, fieldId: 'f1', fieldName: 'Dere'),
      ind('b', '2026-07-02', AttendanceStatus.full), // tarla seçilmemiş
    ]);

    expect(costs.length, 2);
    final bos = costs.firstWhere((f) => f.isUnassigned);
    expect(bos.fieldId, isNull);
    expect(bos.fieldName, kUnassignedFieldLabel);
    expect(bos.grossKurus, 200000);
    expect(totalFieldGross(costs), 400000);
  });

  test('"seçilmemiş" satırı tutarı en büyük olsa bile EN SONA konur', () {
    final costs = build([
      ind('a', '2026-07-02', AttendanceStatus.full, wage: 900000), // tarlasız
      ind('b', '2026-07-02', AttendanceStatus.full,
          wage: 100000, fieldId: 'f1', fieldName: 'Dere'),
    ]);
    expect(costs.map((f) => f.fieldName).toList(), ['Dere', kUnassignedFieldLabel]);
  });

  test('sıralama: brüte göre azalan, eşitlikte ada göre', () {
    final costs = build([
      ind('a', '2026-07-02', AttendanceStatus.full,
          wage: 100000, fieldId: 'f1', fieldName: 'Bahçe'),
      ind('b', '2026-07-02', AttendanceStatus.full,
          wage: 500000, fieldId: 'f2', fieldName: 'Dere'),
      ind('c', '2026-07-02', AttendanceStatus.full,
          wage: 100000, fieldId: 'f3', fieldName: 'Ağıl'),
    ]);
    expect(costs.map((f) => f.fieldName).toList(), ['Dere', 'Ağıl', 'Bahçe']);
  });

  test('çalışılmayan kayıt tarlaya maliyet yazmaz (yok / 0 kişi)', () {
    final costs = build([
      ind('a', '2026-07-02', AttendanceStatus.absent,
          fieldId: 'f1', fieldName: 'Dere'),
      crew('e', '2026-07-03', 0, fieldId: 'f1', fieldName: 'Dere'),
    ]);
    expect(costs, isEmpty, reason: 'kazanç 0 olan gün "çalışılan gün" değildir');
  });

  test('dönem dışı yoklama süzülür', () {
    final costs = build([
      ind('a', '2026-07-02', AttendanceStatus.full, fieldId: 'f1', fieldName: 'Dere'),
      ind('a', '2026-08-05', AttendanceStatus.full, fieldId: 'f1', fieldName: 'Dere'),
      ind('a', '2026-06-30', AttendanceStatus.full, fieldId: 'f1', fieldName: 'Dere'),
    ]);
    expect(costs.single.workdays, 1);
    expect(costs.single.grossKurus, 200000);
  });

  test('tarla adı değişse bile ID ile tek satır; en son kaydın adı gösterilir',
      () {
    final costs = build([
      ind('a', '2026-07-02', AttendanceStatus.full,
          fieldId: 'f1', fieldName: 'Eski Ad'),
      ind('a', '2026-07-10', AttendanceStatus.full,
          fieldId: 'f1', fieldName: 'Yeni Ad'),
    ]);
    expect(costs.single.fieldName, 'Yeni Ad');
    expect(costs.single.workdays, 2);
  });

  test('adı boş/silinmiş kayıt satırı düşürmez (yedek ad)', () {
    final costs = build([
      ind('a', '2026-07-02', AttendanceStatus.full, fieldId: 'f1'),
    ]);
    expect(costs.single.fieldId, 'f1');
    expect(costs.single.fieldName, 'Tarla');
  });

  test('işçi dökümü: brüte göre azalan, tarla bazında ayrı toplanır', () {
    final costs = build([
      ind('a', '2026-07-02', AttendanceStatus.full,
          fieldId: 'f1', fieldName: 'Dere'),
      ind('a', '2026-07-03', AttendanceStatus.full,
          fieldId: 'f2', fieldName: 'Bahçe'),
      ind('b', '2026-07-02', AttendanceStatus.half,
          fieldId: 'f1', fieldName: 'Dere'),
    ]);

    final dere = costs.firstWhere((f) => f.fieldId == 'f1');
    expect(dere.workers.map((w) => w.workerId).toList(), ['a', 'b']);
    expect(dere.workers.first.grossKurus, 200000);
    expect(dere.workers.last.workdays, 0.5);

    // Aynı işçinin diğer tarladaki günü buraya sızmaz.
    final bahce = costs.firstWhere((f) => f.fieldId == 'f2');
    expect(bahce.workers.single.grossKurus, 200000);
  });

  test('yevmiye biçimi: tam sayı "6", yarımlı "6,5"', () {
    expect(formatWorkdays(6), '6');
    expect(formatWorkdays(6.5), '6,5');
    expect(formatWorkdays(0.5), '0,5');
    expect(formatWorkdays(0), '0');
  });
}

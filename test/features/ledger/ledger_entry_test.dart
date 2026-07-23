import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/core/constants/categories.dart';
import 'package:yevmiye_defterim/features/ledger/data/ledger_entry.dart';

void main() {
  LedgerEntry make({String? note}) => LedgerEntry(
        id: 'l1',
        category: LedgerCategory.maas,
        amountKurus: 400000,
        date: '2026-07-16',
        source: LedgerSource.payroll,
        note: note,
        payrollId: 'p1',
        workerId: 'w1',
        workerName: 'Ahmet',
      );

  group('fromDoc / toMap', () {
    test('round-trip (gider)', () {
      final e = make(note: 'Yevmiye ödemesi');
      expect(LedgerEntry.fromDoc(e.id, e.toMap()), e);
    });

    test('eksik alanlar güvenli varsayılana düşer', () {
      final e = LedgerEntry.fromDoc('x', const {});
      expect(e.category, LedgerCategory.genel);
      expect(e.amountKurus, 0);
      expect(e.source, LedgerSource.manual);
    });

    test('elle kayıt round-trip', () {
      final e = LedgerEntry(
        id: 'm1',
        category: LedgerCategory.genel,
        amountKurus: 500000,
        date: '2026-07-18',
        source: LedgerSource.manual,
        note: 'Malzeme',
      );
      expect(LedgerEntry.fromDoc(e.id, e.toMap()), e);
    });

    test('tahsilat round-trip (tarihsel `type` alanında saklanır)', () {
      final e = LedgerEntry(
        id: 't1',
        category: LedgerCategory.mazot,
        amountKurus: 5000000,
        date: '2026-07-22',
        source: LedgerSource.manual,
        kind: LedgerKind.tahsilat,
      );
      final map = e.toMap();
      expect(map['type'], LedgerKind.tahsilat);
      expect(LedgerEntry.fromDoc(e.id, map), e);
    });

    test('gider kaydında `type` null yazılır (eski biçimle aynı)', () {
      final e = make();
      expect(e.toMap()['type'], isNull);
      expect(e.kind, LedgerKind.gider);
    });

    test('bilinmeyen/eksik `type` → gider', () {
      expect(LedgerEntry.fromDoc('x', const {}).isTahsilat, isFalse);
      expect(
        LedgerEntry.fromDoc('y', const {'type': 'baska'}).kind,
        LedgerKind.gider,
      );
    });
  });

  group('getter', () {
    test('isManual — kaynak manual → true', () {
      expect(make().copyWith(source: LedgerSource.manual).isManual, isTrue);
    });

    test('isManual — otomatik kaynak → false', () {
      expect(make().isManual, isFalse); // seed source = payroll
      expect(make().copyWith(source: LedgerSource.elebasi).isManual, isFalse);
    });
  });
}

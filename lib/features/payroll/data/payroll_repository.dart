/// Hakediş deposu — geçmiş + "Öde" (tek `WriteBatch`, kural §3, §6).
///
/// "Öde" atomiktir: (1) `payrolls` kaydı dondurulur, (2) net>0 ise `ledger`
/// gider kaydı yazılır, (3) kapanan avanslara `settledPayrollId` yazılır,
/// (4) sınırdaki avansın tutarı kalanına düşürülür (kalan devreder). Tümü
/// tek batch → yazma kaybı/çifte sayım olmaz.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/date/app_date.dart';
import '../../../core/firestore/refs.dart';
import '../../../core/firestore/write_stamp.dart';
import '../../ledger/data/ledger_entry.dart';
import 'payroll.dart';

abstract class PayrollRepository {
  /// Tüm hakediş kayıtları (geçmiş). Filtre/sıralama sağlayıcıda yapılır.
  Stream<List<Payroll>> watchAll();

  /// Hakedişi öder (tek batch — yukarıdaki adımlar).
  Future<void> pay({
    required Payroll payroll,
    LedgerEntry? ledgerEntry,
    required List<String> settledAdvanceIds,
    ({String id, int remainingKurus})? partialAdvance,
    required List<String> paidAttendanceIds,
  });
}

class FirestorePayrollRepository implements PayrollRepository {
  FirestorePayrollRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<Payroll>> watchAll() => payrollsCol(_db).snapshots().map((snap) =>
      snap.docs.map((d) => Payroll.fromDoc(d.id, d.data())).toList());

  @override
  Future<void> pay({
    required Payroll payroll,
    LedgerEntry? ledgerEntry,
    required List<String> settledAdvanceIds,
    ({String id, int remainingKurus})? partialAdvance,
    required List<String> paidAttendanceIds,
  }) {
    final batch = _db.batch();

    // (1) Hakediş kaydı dondurulur.
    batch.set(payrollsCol(_db).doc(payroll.id), {
      ...payroll.toMap(),
      'ts': Timestamp.fromDate(parseIsoDate(payroll.paidDate)),
      ...writeStamp(),
    });

    // (2) Net > 0 ise kasa gider kaydı (net tutar, kural §6).
    if (ledgerEntry != null) {
      batch.set(ledgerCol(_db).doc(ledgerEntry.id), {
        ...ledgerEntry.toMap(),
        'ts': Timestamp.fromDate(parseIsoDate(ledgerEntry.date)),
        ...writeStamp(),
      });
    }

    // (3) Kapanan avanslar → settledPayrollId (alan-bazlı merge, kural §3).
    for (final id in settledAdvanceIds) {
      batch.set(advancesCol(_db).doc(id), {
        'settledPayrollId': payroll.id,
        ...writeStamp(),
      }, SetOptions(merge: true));
    }

    // (4) Sınırdaki avans → kalan tutara düşürülür (kapanmaz, devreder).
    final partial = partialAdvance;
    if (partial != null) {
      batch.set(advancesCol(_db).doc(partial.id), {
        'amountKurus': partial.remainingKurus,
        ...writeStamp(),
      }, SetOptions(merge: true));
    }

    // (5) Ödenen yoklama günleri işaretlenir (bir daha brüte katılmaz — çifte
    // ödeme engeli, kural §6). Alan-bazlı merge → snapshot ezilmez (kural §3).
    for (final id in paidAttendanceIds) {
      batch.set(attendanceCol(_db).doc(id), {
        'paidPayrollId': payroll.id,
        ...writeStamp(),
      }, SetOptions(merge: true));
    }

    return batch.commit();
  }
}

import 'dart:async';

import 'package:yevmiye_defterim/features/ledger/data/ledger_entry.dart';
import 'package:yevmiye_defterim/features/payroll/data/payroll.dart';
import 'package:yevmiye_defterim/features/payroll/data/payroll_repository.dart';

/// Bellek-içi hakediş deposu (testler için) — `pay()` çağrısını yakalar.
class FakePayrollRepository implements PayrollRepository {
  final List<Payroll> payrolls = [];
  final StreamController<void> _tick = StreamController<void>.broadcast();

  /// Son `pay()` çağrısının argümanları (doğrulama için).
  PayCall? lastCall;
  int payCount = 0;

  @override
  Stream<List<Payroll>> watchAll() async* {
    yield List.of(payrolls);
    yield* _tick.stream.map((_) => List.of(payrolls));
  }

  @override
  Future<void> pay({
    required Payroll payroll,
    LedgerEntry? ledgerEntry,
    required List<String> settledAdvanceIds,
    ({String id, int remainingKurus})? partialAdvance,
    required List<String> paidAttendanceIds,
  }) async {
    payCount++;
    payrolls.add(payroll);
    lastCall = PayCall(
      payroll: payroll,
      ledgerEntry: ledgerEntry,
      settledAdvanceIds: settledAdvanceIds,
      partialAdvance: partialAdvance,
      paidAttendanceIds: paidAttendanceIds,
    );
    _tick.add(null);
  }
}

class PayCall {
  const PayCall({
    required this.payroll,
    required this.ledgerEntry,
    required this.settledAdvanceIds,
    required this.partialAdvance,
    required this.paidAttendanceIds,
  });

  final Payroll payroll;
  final LedgerEntry? ledgerEntry;
  final List<String> settledAdvanceIds;
  final ({String id, int remainingKurus})? partialAdvance;
  final List<String> paidAttendanceIds;
}

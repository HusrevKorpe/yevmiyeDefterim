/// Hakediş "Öde" ViewModel'i (kural §7: MVVM; §6: çifte sayım yok).
///
/// Ekran satırdaki hazır [PayrollLine] hesabını verir; bu ViewModel ödeme
/// modellerini (payroll + kasa gideri) kurar, avans mahsup planını ve ödenen
/// yoklama günlerini toplar, tek batch ile ödemeyi yaptırır (repository).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/categories.dart';
import '../../../core/date/app_date.dart';
import '../../../core/ids/ids.dart';
import '../../ledger/data/ledger_entry.dart';
import '../data/payroll.dart';
import 'payroll_calculator.dart';
import 'payroll_providers.dart';

class PayrollPayState {
  const PayrollPayState({this.savingWorkerId, this.error, this.paidWorkerId});

  /// Şu an ödemesi yapılan işçi ID'si (null => boşta).
  final String? savingWorkerId;
  final String? error;

  /// Son başarıyla ödenen işçi ID'si (snackbar için).
  final String? paidWorkerId;

  bool isSaving(String workerId) => savingWorkerId == workerId;
}

class PayrollViewModel extends Notifier<PayrollPayState> {
  @override
  PayrollPayState build() => const PayrollPayState();

  /// Bir hakediş satırını öder. Aynı anda tek ödeme (yarış/çifte tık engeli).
  Future<void> pay(PayrollLine line) async {
    if (state.savingWorkerId != null) return;
    if (line.grossKurus <= 0) return; // ödenecek bir şey yok

    final comp = line.computation;
    state = PayrollPayState(savingWorkerId: line.workerId);
    try {
      final period = ref.read(payrollPeriodProvider);
      final paidDate = todayIso();
      final payrollId = newId();

      // Bu işçinin dönemdeki henüz ödenmemiş yoklama günleri → işaretlenecek.
      final attendance =
          ref.read(attendanceInPeriodProvider).asData?.value ?? const [];
      final paidAttendanceIds = attendance
          .where((r) =>
              r.workerId == line.workerId &&
              !r.isPaid &&
              r.date.compareTo(period.start) >= 0 &&
              r.date.compareTo(period.end) <= 0)
          .map((r) => r.id)
          .toList();

      // Net > 0 ise kasa gider kaydı (net tutar; elebaşı/işçi kategorisi).
      LedgerEntry? ledger;
      String? ledgerId;
      if (comp.netPaidKurus > 0) {
        ledgerId = newId();
        ledger = LedgerEntry(
          id: ledgerId,
          type: LedgerType.expense,
          category: line.isCrew ? LedgerCategory.elebasi : LedgerCategory.maas,
          amountKurus: comp.netPaidKurus,
          date: paidDate,
          source: line.isCrew ? LedgerSource.elebasi : LedgerSource.payroll,
          payrollId: payrollId,
          workerId: line.workerId,
          workerName: line.workerName,
          note: line.isCrew ? 'Elebaşı ödemesi' : 'Yevmiye ödemesi',
        );
      }

      final payroll = Payroll(
        id: payrollId,
        workerId: line.workerId,
        workerName: line.workerName,
        workerType: line.workerType,
        periodStart: period.start,
        periodEnd: period.end,
        paidDate: paidDate,
        grossKurus: comp.grossKurus,
        advancesDeductedKurus: comp.advancesDeductedKurus,
        netPaidKurus: comp.netPaidKurus,
        carryoverKurus: comp.carryoverKurus,
        ledgerEntryId: ledgerId,
      );

      await ref.read(payrollRepositoryProvider).pay(
            payroll: payroll,
            ledgerEntry: ledger,
            settledAdvanceIds: comp.settledAdvanceIds,
            partialAdvance: comp.partialAdvance,
            paidAttendanceIds: paidAttendanceIds,
          );
      state = PayrollPayState(paidWorkerId: line.workerId);
    } catch (_) {
      state = const PayrollPayState(
        error: 'Ödeme yapılamadı. İnternet bağlantınızı kontrol edin.',
      );
    }
  }
}

final NotifierProvider<PayrollViewModel, PayrollPayState>
    payrollViewModelProvider =
    NotifierProvider<PayrollViewModel, PayrollPayState>(PayrollViewModel.new);

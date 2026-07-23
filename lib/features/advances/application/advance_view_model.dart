/// Avans ekle/düzenle/sil ViewModel'i (kural §7: MVVM).
///
/// Ekran form durumunu tutar; bu ViewModel yalnız yazma işlemini ve
/// yükleniyor/hata/bitti durumunu yönetir. Kapanmış avans düzenlenmez/silinmez.
/// Yazmalar [awaitWriteAck] ile sarılır: offline'da sunucu onayı gelmese de
/// UI süresiz kilitlenmez (yazma yerel kuyruğa girer, sonradan senkronlanır).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/write_ack.dart';
import '../data/advance.dart';
import 'advance_providers.dart';

class AdvanceEditState {
  const AdvanceEditState({this.saving = false, this.error, this.done = false});

  final bool saving;
  final String? error;
  final bool done;
}

class AdvanceEditViewModel extends Notifier<AdvanceEditState> {
  @override
  AdvanceEditState build() => const AdvanceEditState();

  /// Yeni avans ekler veya var olanı günceller.
  Future<void> submit({required Advance advance, required bool isNew}) async {
    if (state.saving) return;
    state = const AdvanceEditState(saving: true);
    try {
      final repo = ref.read(advanceRepositoryProvider);
      if (isNew) {
        await awaitWriteAck(repo.add(advance));
      } else {
        await awaitWriteAck(repo.update(advance));
      }
      state = const AdvanceEditState(done: true);
    } catch (_) {
      state = const AdvanceEditState(
        error: 'Kaydedilemedi. İnternet bağlantınızı kontrol edin.',
      );
    }
  }

  /// Kapanmamış avansı siler. Kapanmış (mahsup edilmiş) avans silinemez.
  Future<void> delete(Advance advance) async {
    if (state.saving) return;
    if (!advance.isOpen) {
      state = const AdvanceEditState(
        error: 'Mahsup edilmiş avans silinemez.',
      );
      return;
    }
    state = const AdvanceEditState(saving: true);
    try {
      await awaitWriteAck(ref.read(advanceRepositoryProvider).delete(advance.id));
      state = const AdvanceEditState(done: true);
    } catch (_) {
      state = const AdvanceEditState(
        error: 'Silinemedi. İnternet bağlantınızı kontrol edin.',
      );
    }
  }
}

final NotifierProvider<AdvanceEditViewModel, AdvanceEditState>
    advanceEditViewModelProvider =
    NotifierProvider<AdvanceEditViewModel, AdvanceEditState>(
  AdvanceEditViewModel.new,
);

/// "Hesap görüldü" — bir işçinin açık avanslarını topluca kapatır / geri açar.
///
/// Durum = meşgul mü (tek uçuşta çift tetiklemeyi engeller). Avans düzenleme
/// akışından ayrıdır: kapatma işçinin TÜM açık avanslarını tek batch'te kapatır,
/// "geri al" ise aynı avansları yeniden açar. Notifier uygulama kapsamlı olduğu
/// için düzenleme ekranı kapansa da "Geri Al" güvenle çalışır.
class AccountSettlementViewModel extends Notifier<bool> {
  @override
  bool build() => false;

  /// [ids] avanslarını [settledDate] ile kapatır. [carryover] verilirse
  /// (devreden alacağımız) aynı batch'te yeni açık avans yazılır. Başarılıysa true.
  Future<bool> settle(
    Iterable<String> ids,
    String settledDate, {
    Advance? carryover,
  }) async {
    if (state) return false;
    state = true;
    try {
      await awaitWriteAck(ref
          .read(advanceRepositoryProvider)
          .settleAdvances(ids, settledDate, carryover: carryover));
      return true;
    } catch (_) {
      return false;
    } finally {
      state = false;
    }
  }

  /// [ids] avanslarını yeniden açar (geri al); [deleteIds] (kapanışın devir
  /// kayıtları) aynı batch'te silinir. Başarılıysa true.
  Future<bool> reopen(
    Iterable<String> ids, {
    Iterable<String> deleteIds = const [],
  }) async {
    if (state) return false;
    state = true;
    try {
      await awaitWriteAck(ref
          .read(advanceRepositoryProvider)
          .reopenAdvances(ids, deleteIds: deleteIds));
      return true;
    } catch (_) {
      return false;
    } finally {
      state = false;
    }
  }
}

final NotifierProvider<AccountSettlementViewModel, bool>
    accountSettlementViewModelProvider =
    NotifierProvider<AccountSettlementViewModel, bool>(
  AccountSettlementViewModel.new,
);

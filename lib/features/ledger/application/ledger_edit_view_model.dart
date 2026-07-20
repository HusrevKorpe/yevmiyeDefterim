/// Kasa kaydı ekle/düzenle/sil ViewModel'i (kural §7: MVVM).
///
/// Ekran form durumunu tutar; bu ViewModel yalnız yazma işlemini ve
/// yükleniyor/hata/bitti durumunu yönetir. Yalnız elle (`source: manual`)
/// kayıtlar düzenlenir/silinir — otomatik hakediş kayıtları dondurulur (§6).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ledger_entry.dart';
import 'ledger_providers.dart';

class LedgerEditState {
  const LedgerEditState({this.saving = false, this.error, this.done = false});

  final bool saving;
  final String? error;
  final bool done;
}

class LedgerEditViewModel extends Notifier<LedgerEditState> {
  @override
  LedgerEditState build() => const LedgerEditState();

  /// Yeni kayıt ekler veya var olanı günceller. Otomatik kayıt güncellenemez.
  Future<void> submit({required LedgerEntry entry, required bool isNew}) async {
    if (state.saving) return;
    if (!entry.isManual) {
      state = const LedgerEditState(
        error: 'Otomatik kayıt (maaş/elebaşı) düzenlenemez.',
      );
      return;
    }
    state = const LedgerEditState(saving: true);
    try {
      final repo = ref.read(ledgerRepositoryProvider);
      if (isNew) {
        await repo.add(entry);
      } else {
        await repo.update(entry);
      }
      state = const LedgerEditState(done: true);
    } catch (_) {
      state = const LedgerEditState(
        error: 'Kaydedilemedi. İnternet bağlantınızı kontrol edin.',
      );
    }
  }

  /// Elle kaydı siler. Otomatik hakediş kaydı silinemez.
  Future<void> delete(LedgerEntry entry) async {
    if (state.saving) return;
    if (!entry.isManual) {
      state = const LedgerEditState(
        error: 'Otomatik kayıt (maaş/elebaşı) silinemez.',
      );
      return;
    }
    state = const LedgerEditState(saving: true);
    try {
      await ref.read(ledgerRepositoryProvider).delete(entry.id);
      state = const LedgerEditState(done: true);
    } catch (_) {
      state = const LedgerEditState(
        error: 'Silinemedi. İnternet bağlantınızı kontrol edin.',
      );
    }
  }
}

final NotifierProvider<LedgerEditViewModel, LedgerEditState>
    ledgerEditViewModelProvider =
    NotifierProvider<LedgerEditViewModel, LedgerEditState>(
  LedgerEditViewModel.new,
);

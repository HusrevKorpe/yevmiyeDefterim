/// Avans ekle/düzenle/sil ViewModel'i (kural §7: MVVM).
///
/// Ekran form durumunu tutar; bu ViewModel yalnız yazma işlemini ve
/// yükleniyor/hata/bitti durumunu yönetir. Kapanmış avans düzenlenmez/silinmez.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        await repo.add(advance);
      } else {
        await repo.update(advance);
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
      await ref.read(advanceRepositoryProvider).delete(advance.id);
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

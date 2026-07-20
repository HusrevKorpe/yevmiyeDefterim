/// İşçi ekle/düzenle ViewModel'i (kural §7: MVVM).
///
/// Ekran form durumunu tutar; bu ViewModel yalnız yazma işlemini ve
/// yükleniyor/hata/bitti durumunu yönetir.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/worker.dart';
import 'workers_providers.dart';

class WorkerEditState {
  const WorkerEditState({this.saving = false, this.error, this.done = false});

  final bool saving;
  final String? error;
  final bool done;
}

class WorkerEditViewModel extends Notifier<WorkerEditState> {
  @override
  WorkerEditState build() => const WorkerEditState();

  /// Yeni işçi ekler veya var olanı günceller.
  Future<void> submit({required Worker worker, required bool isNew}) async {
    if (state.saving) return;
    state = const WorkerEditState(saving: true);
    try {
      final repo = ref.read(workerRepositoryProvider);
      if (isNew) {
        await repo.add(worker);
      } else {
        await repo.update(worker);
      }
      state = const WorkerEditState(done: true);
    } catch (_) {
      state = const WorkerEditState(
        error: 'Kaydedilemedi. İnternet bağlantınızı kontrol edin.',
      );
    }
  }

  /// Pasif yap / geri al (kural §5 soft-delete).
  Future<void> setActive({required String id, required bool active}) async {
    if (state.saving) return;
    state = const WorkerEditState(saving: true);
    try {
      await ref.read(workerRepositoryProvider).setActive(id, active: active);
      state = const WorkerEditState(done: true);
    } catch (_) {
      state = const WorkerEditState(
        error: 'İşlem yapılamadı. İnternet bağlantınızı kontrol edin.',
      );
    }
  }
}

final NotifierProvider<WorkerEditViewModel, WorkerEditState>
    workerEditViewModelProvider =
    NotifierProvider<WorkerEditViewModel, WorkerEditState>(
  WorkerEditViewModel.new,
);

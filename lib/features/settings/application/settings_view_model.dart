/// Ayarlar ekranı ViewModel'i (kural §7: MVVM).
///
/// Ekran yalnız [SettingsFormState]'i okur ve [SettingsViewModel.save]'i çağırır;
/// Firestore çağrısı burada, ekranda değil.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_settings.dart';
import 'settings_providers.dart';

class SettingsFormState {
  const SettingsFormState({this.saving = false, this.error, this.saved = false});

  final bool saving;
  final String? error;
  final bool saved;
}

class SettingsViewModel extends Notifier<SettingsFormState> {
  @override
  SettingsFormState build() => const SettingsFormState();

  /// Ücretleri (tam sayı kuruş) kaydeder. Tutarlar ekranda ₺ parse edilir.
  Future<void> save({
    required int maleKurus,
    required int femaleKurus,
    required int crewRateKurus,
  }) async {
    if (state.saving) return;
    state = const SettingsFormState(saving: true);
    try {
      await ref.read(settingsRepositoryProvider).save(
            AppSettings(
              defaultWageMaleKurus: maleKurus,
              defaultWageFemaleKurus: femaleKurus,
              defaultCrewRateKurus: crewRateKurus,
            ),
          );
      state = const SettingsFormState(saved: true);
    } catch (_) {
      state = const SettingsFormState(
        error: 'Kaydedilemedi. İnternet bağlantınızı kontrol edin.',
      );
    }
  }
}

final NotifierProvider<SettingsViewModel, SettingsFormState>
    settingsViewModelProvider =
    NotifierProvider<SettingsViewModel, SettingsFormState>(
  SettingsViewModel.new,
);

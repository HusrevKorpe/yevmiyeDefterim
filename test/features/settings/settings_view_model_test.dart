import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_providers.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_view_model.dart';

import '../../support/fake_settings_repository.dart';

void main() {
  test('save → depoya doğru kuruş yazar, state.saved olur', () async {
    final repo = FakeSettingsRepository();
    final container = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await container.read(settingsViewModelProvider.notifier).save(
          maleKurus: 200000,
          femaleKurus: 180000,
          crewRateKurus: 150000,
        );

    expect(repo.current.defaultWageMaleKurus, 200000);
    expect(repo.current.defaultWageFemaleKurus, 180000);
    expect(repo.current.defaultCrewRateKurus, 150000);
    expect(container.read(settingsViewModelProvider).saved, true);
    expect(container.read(settingsViewModelProvider).error, isNull);
  });
}

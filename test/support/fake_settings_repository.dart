import 'dart:async';

import 'package:yevmiye_defterim/features/settings/data/app_settings.dart';
import 'package:yevmiye_defterim/features/settings/data/settings_repository.dart';

/// Bellek-içi ayar deposu (testler için). [save] akışa yeni değer yansıtır.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository([this._settings = AppSettings.empty]);

  AppSettings _settings;
  final StreamController<AppSettings> _controller =
      StreamController<AppSettings>.broadcast();

  @override
  Stream<AppSettings> watch() async* {
    yield _settings;
    yield* _controller.stream;
  }

  @override
  Future<void> save(AppSettings settings) async {
    _settings = settings;
    _controller.add(settings);
  }

  AppSettings get current => _settings;
}

/// Ayar Riverpod sağlayıcıları (kural §7).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/firestore_providers.dart';
import '../data/app_settings.dart';
import '../data/settings_repository.dart';

/// Ayar deposu. Testlerde `overrideWithValue(FakeSettingsRepository(...))`.
final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
  (ref) => FirestoreSettingsRepository(ref.watch(firestoreProvider)),
);

/// Ayar akışı — ekranlar ve ücret çözümü bunu izler.
final StreamProvider<AppSettings> settingsStreamProvider =
    StreamProvider<AppSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);

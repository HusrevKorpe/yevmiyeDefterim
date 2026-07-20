/// Ayar deposu — `settings/config` oku/yaz (kural §7: repository).
///
/// Soyut arayüz + Firestore implementasyonu (testlerde fake ile override).
/// Doküman yoksa akış [AppSettings.empty] üretir; ilk kayıtta oluşturulur.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/refs.dart';
import '../../../core/firestore/write_stamp.dart';
import 'app_settings.dart';

abstract class SettingsRepository {
  /// Ayar akışı. Doküman yoksa [AppSettings.empty] gelir.
  Stream<AppSettings> watch();

  /// Ayarları yazar (tek config dokümanı, `merge:true`).
  Future<void> save(AppSettings settings);
}

class FirestoreSettingsRepository implements SettingsRepository {
  FirestoreSettingsRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<AppSettings> watch() => settingsDocRef(_db).snapshots().map(
        (snap) =>
            snap.exists ? AppSettings.fromMap(snap.data()) : AppSettings.empty,
      );

  @override
  Future<void> save(AppSettings settings) => settingsDocRef(_db).set({
        ...settings.toMap(),
        ...writeStamp(),
      }, SetOptions(merge: true));
}

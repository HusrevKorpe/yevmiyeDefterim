import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase'i bağlı projeye göre başlat (flutterfire configure çıktısı).
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Crashlytics (Faz 4): 3 saha kullanıcısını uzaktan takip (plan §1).
  // Flutter framework hataları + yakalanmamış async (platform) hataları kaydedilir.
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Offline zorunlu (kural §3): kalıcı önbellek açık, sınırsız.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // TR tarih/para formatları için yerel veriyi yükle.
  await initializeDateFormatting('tr_TR', null);

  runApp(const ProviderScope(child: YevmiyeApp()));
}

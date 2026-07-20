/// Auth Riverpod sağlayıcıları (kural §7).
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_user.dart';
import '../data/auth_repository.dart';

/// Auth deposu. Testlerde `overrideWithValue(FakeAuthRepository(...))`.
final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(FirebaseAuth.instance),
);

/// Oturum durumu akışı — router auth kapısı ve ekranlar bunu izler.
final StreamProvider<AppUser?> authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

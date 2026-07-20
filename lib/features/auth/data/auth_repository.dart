/// Kimlik doğrulama deposu (kural §7: repository'yi ViewModel çağırır).
///
/// Soyut arayüz + Firebase implementasyonu. Testlerde sahte (fake) ile
/// override edilebilir olması için arayüz üzerinden çalışılır.
library;

import 'package:firebase_auth/firebase_auth.dart';

import 'app_user.dart';

abstract class AuthRepository {
  /// Oturum durumu akışı (giriş/çıkış oldukça yeni değer üretir).
  Stream<AppUser?> authStateChanges();

  /// O anki kullanıcı (senkron; token diskten geri yüklendiyse dolu gelir).
  AppUser? get currentUser;

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  AppUser? _map(User? u) =>
      u == null ? null : AppUser(uid: u.uid, email: u.email);

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(_map);

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

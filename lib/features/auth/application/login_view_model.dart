/// Giriş ekranı ViewModel'i (kural §7: MVVM).
///
/// Ekran yalnız [LoginState]'i okur ve [LoginViewModel.signIn]'i çağırır;
/// Firebase çağrısı burada yapılır, ekranda değil.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/app_log.dart';
import 'auth_providers.dart';

class LoginState {
  const LoginState({this.loading = false, this.error});

  final bool loading;
  final String? error;
}

class LoginViewModel extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (state.loading) return;
    state = const LoginState(loading: true);
    try {
      await ref.read(authRepositoryProvider).signIn(
            email: email.trim(),
            password: password,
          );
      state = const LoginState();
    } on FirebaseAuthException catch (e) {
      // Beklenen giriş hataları (şifre/e-posta/ağ) — kullanıcıya mesaj yeter,
      // Crashlytics'e taşınmaz (gürültü olur). Yalnız kod breadcrumb'a düşer.
      logBreadcrumb('giris-hata: ${e.code}');
      state = LoginState(error: _messageFor(e.code));
    } catch (e, s) {
      state = const LoginState(
        error: 'Giriş yapılamadı. İnternet bağlantınızı kontrol edin.',
      );
      await logHandledError(e, s, reason: 'giris-beklenmedik');
    }
  }

  String _messageFor(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      case 'too-many-requests':
        return 'Çok fazla deneme. Lütfen biraz sonra tekrar deneyin.';
      case 'network-request-failed':
        return 'İnternet bağlantısı yok. Bağlanıp tekrar deneyin.';
      default:
        return 'Giriş yapılamadı. Lütfen tekrar deneyin.';
    }
  }
}

final NotifierProvider<LoginViewModel, LoginState> loginViewModelProvider =
    NotifierProvider<LoginViewModel, LoginState>(LoginViewModel.new);

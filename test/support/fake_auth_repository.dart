import 'package:yevmiye_defterim/features/auth/data/app_user.dart';
import 'package:yevmiye_defterim/features/auth/data/auth_repository.dart';

/// Testlerde Firebase olmadan oturum durumunu taklit eder.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this._user);

  final AppUser? _user;

  @override
  Stream<AppUser?> authStateChanges() => Stream<AppUser?>.value(_user);

  @override
  AppUser? get currentUser => _user;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}
}

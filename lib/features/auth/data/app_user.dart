/// Oturum açmış kullanıcı — Firebase [User]'dan bağımsız, sade değişmez model.
library;

class AppUser {
  const AppUser({required this.uid, this.email});

  final String uid;
  final String? email;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser && other.uid == uid && other.email == email;

  @override
  int get hashCode => Object.hash(uid, email);
}

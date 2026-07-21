/// Rol/erişim — hangi hesap para/gider bilgisi GÖREMEZ (arayüzde gizleme).
///
/// Uygulama e-posta/şifre ile giriş yapar. Belirli e-posta(lar) ile giriş
/// yapılınca uygulama "para göremez" moduna geçer: Kasa, Avans, Rapor sekme ve
/// ekranları gizlenir; yevmiye/özel ücret tutarları hiçbir ekranda görünmez.
/// Yoklama açık kalır (kimin geldiği işaretlenir) ama tutarları gizlidir.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// PARA/GİDER GÖREMEYECEK HESAPLAR
///
/// Buraya kısıtlı kullanıcının Gmail adresini KÜÇÜK HARF ile yaz. Birden fazla
/// hesap kısıtlamak istersen virgülle ekle. Bu e-posta(lar) ile giriş yapan
/// kişi para/gider ile ilgili HİÇBİR şey göremez.
/// ─────────────────────────────────────────────────────────────────────────
const Set<String> kMoneyRestrictedEmails = <String>{
  'user@gmail.com', // Para/gider göremeyen kısıtlı hesap.
};

/// Verilen e-posta para/gider görmekten kısıtlı mı? (büyük/küçük harf duyarsız)
bool isMoneyRestricted(String? email) {
  if (email == null) return false;
  return kMoneyRestrictedEmails.contains(email.trim().toLowerCase());
}

/// Oturumdaki kullanıcı para/gider bilgisini görebilir mi?
///
/// `false` → Kasa/Avans/Rapor gizlenir, tüm tutarlar maskelenir. Tek gerçek
/// kaynak burasıdır; ekranlar ve router bunu izler. Akış henüz değeri
/// vermeden (ilk kare) senkron `currentUser`'a düşer → kısıtlı hesabın para
/// sekmeleri bir an bile parlamaz.
final Provider<bool> canSeeMoneyProvider = Provider<bool>((ref) {
  final streamed = ref.watch(authStateProvider).asData?.value?.email;
  final email = streamed ?? ref.watch(authRepositoryProvider).currentUser?.email;
  return !isMoneyRestricted(email);
});

/// Güncelleme bildirimleri — cihaz başına BİR KEZ gösterilen tek-seferlik notlar.
///
/// Uygulama güncellendiğinde kullanıcının bilmesi gereken bir değişiklik varsa
/// (ör. 2026-07-24: elebaşıya da yevmiye eklendi → boş yevmiyeleri doldur),
/// ilgili not yüklü olan her cihazda ilk açılışta bir kez gösterilir. "Görüldü"
/// bilgisi cihazda [SharedPreferences]'ta yerel tutulur (Firestore'a bağlı
/// DEĞİL) → çevrimdışıyken de çalışır, her cihaz kendi durumunu bilir.
///
/// Yeni bir güncelleme notu gerektiğinde anahtar sonekini artır
/// ('_v2', '_v3'…) → o not tüm cihazlarda yeniden bir kez çıkar.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_mode.dart';

/// "Boş yevmiyeleri doldur" hatırlatması görüldü mü? (cihaz-yerel)
const String kWageReminderSeenKey = 'wageReminderSeen_v1';

/// Yevmiye hatırlatmasının bu cihazda gösterilip gösterilmediğini tutar.
/// Prefs bağlı değilse (testler) hep `false` → güvenli varsayılan.
class WageReminderSeenController extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs?.getBool(kWageReminderSeenKey) ?? false;
  }

  /// Notu "görüldü" işaretler → bu cihazda bir daha çıkmaz.
  Future<void> markSeen() async {
    state = true;
    await ref.read(sharedPreferencesProvider)?.setBool(kWageReminderSeenKey, true);
  }
}

final NotifierProvider<WageReminderSeenController, bool> wageReminderSeenProvider =
    NotifierProvider<WageReminderSeenController, bool>(
  WageReminderSeenController.new,
);

/// Firestore koleksiyon adları ve sabit yollar (kural.md §7: string tekrar etme).
library;

/// Firestore koleksiyon adları.
class FsCollections {
  FsCollections._();

  static const String workspaces = 'workspaces';
  static const String workers = 'workers';
  static const String attendance = 'attendance';
  static const String advances = 'advances';
  static const String ledger = 'ledger';
  static const String payrolls = 'payrolls';
  static const String settings = 'settings';

  /// "Günün yoklaması kaydedildi" işaret dokümanları (doc ID = yyyy-MM-dd).
  /// Yoklamada "Kaydet"e basınca yazılır; Cloud Function bunu dinleyip diğer
  /// cihazlara push bildirimi gönderir (bkz. functions/index.js).
  static const String attendanceDays = 'attendanceDays';

  /// Cihaz push token kayıtları (doc ID = FCM token). Push bildirimi hangi
  /// cihazlara gideceğini buradan bulur; `uid` alanı kaydeden cihazı elemeye
  /// yarar (kendi kaydettiğin yoklama için sana bildirim gelmez).
  static const String fcmTokens = 'fcmTokens';

  /// Kullanıcı tanımlı tarlalar (doc ID = uuid, soft-delete `active`).
  /// Yoklamada Tam/Yarım (veya elebaşı mevcudu) girilince tarla seçimi bu
  /// listeden çıkar → "kim nerede çalıştı" kayıt altına alınır.
  static const String fields = 'fields';
}

/// Tek ortak workspace (kural §9 / plan §3): `workspaces/main/...`.
const String kWorkspaceId = 'main';

/// `settings/config` dokümanı.
const String kSettingsDocId = 'config';

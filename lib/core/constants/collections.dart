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
}

/// Tek ortak workspace (kural §9 / plan §3): `workspaces/main/...`.
const String kWorkspaceId = 'main';

/// `settings/config` dokümanı.
const String kSettingsDocId = 'config';

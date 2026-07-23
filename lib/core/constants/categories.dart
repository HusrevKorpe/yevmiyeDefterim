/// Kasa (ledger) kategori ve kayıt-kaynağı sabitleri (kural.md §6).
library;

/// Gider kategorileri (uygulama yalnız gider takip eder).
///
/// `maas`/`elebasi` yalnız otomatik hakediş kayıtlarına aittir — Kasa'da elle
/// seçilemez (çifte sayım izlenebilirliği, kural §6). Elle eklenebilen set
/// [manualExpense] ile sınırlıdır.
class LedgerCategory {
  LedgerCategory._();

  static const String mazot = 'mazot';
  static const String tamir = 'tamir';
  static const String bakkal = 'bakkal';
  static const String maas = 'maas';
  static const String elebasi = 'elebasi';
  static const String genel = 'genel';

  /// Elle eklenebilen GİDER kategorileri (maas/elebasi otomatik → hariç).
  static const List<String> manualExpense = [mazot, tamir, bakkal, genel];

  /// Kendi ekranı olan kategoriler (Kasa app bar kısayolları, kural §8).
  static const List<String> screened = [mazot, tamir, bakkal];

  /// Türkçe gösterim etiketleri.
  static const Map<String, String> _labels = {
    mazot: 'Mazot',
    tamir: 'Tamir',
    bakkal: 'Bakkal',
    maas: 'Maaş',
    elebasi: 'Elebaşı',
    genel: 'Genel',
  };

  /// Kategori kodunun Türkçe etiketi (bilinmeyen → kodun kendisi).
  static String label(String category) => _labels[category] ?? category;
}

/// Kayıt kaynağı — çifte sayımı izlemek için (kural §6).
class LedgerSource {
  LedgerSource._();

  static const String manual = 'manual';
  static const String payroll = 'payroll';
  static const String elebasi = 'elebasi';
}

/// Kayıt türü — gider mi, tahsilat mı.
///
/// Tahsilat: esnafa (mazotçu/tamirci/bakkal) ÖNDEN verilen para; sonradan
/// alım yapıldıkça bu paradan düşülür. Gider TOPLAMLARINA GİRMEZ — harcama,
/// alım (gider) kayıtlarıyla sayılır; tahsilat da toplansa aynı para iki kez
/// sayılırdı (kural §6). Kategori ekranında "verilen / harcanan / kalan"
/// bakiyesini besler. Firestore'da tarihsel `type` alanında saklanır
/// (`'income'` eski gelirdi ve okurken kalıcı elenir).
class LedgerKind {
  LedgerKind._();

  static const String gider = 'gider';
  static const String tahsilat = 'tahsilat';

  /// Tahsilat girilebilen kategoriler (kendi ekranı olanlar).
  static const List<String> tahsilatCategories = LedgerCategory.screened;
}

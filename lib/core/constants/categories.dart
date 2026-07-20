/// Kasa (ledger) kategori ve kayıt-kaynağı sabitleri (kural.md §6).
library;

/// Gelir/gider kategorileri.
///
/// `maas`/`elebasi` yalnız otomatik hakediş kayıtlarına aittir — Kasa'da elle
/// seçilemez (çifte sayım izlenebilirliği, kural §6). Elle eklenebilen setler
/// [manualExpense]/[manualIncome] ile sınırlıdır.
class LedgerCategory {
  LedgerCategory._();

  static const String mazot = 'mazot';
  static const String maas = 'maas';
  static const String elebasi = 'elebasi';
  static const String genel = 'genel';

  /// Elle eklenebilen GİDER kategorileri (maas/elebasi otomatik → hariç).
  static const List<String> manualExpense = [mazot, genel];

  /// Elle eklenebilen GELİR kategorileri.
  static const List<String> manualIncome = [genel];

  /// Türkçe gösterim etiketleri.
  static const Map<String, String> _labels = {
    mazot: 'Mazot',
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

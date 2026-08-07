/// Türkçe rota adları (kural.md §7).
library;

/// Uygulama rotaları.
class AppRoutes {
  AppRoutes._();

  static const String login = '/giris';
  static const String home = '/';
  static const String attendance = '/yoklama';
  static const String monthlyAttendance = '/yoklama/aylik';
  static const String workerTotals = '/yoklama/ozet';
  /// Tarla + Yapılan İş yönetimi (tek ekran, iki bölüm).
  static const String plotsAndJobs = '/yoklama/tarlalar';
  static const String workers = '/isciler';
  static const String ledger = '/kasa';
  static const String settings = '/ayarlar';
  static const String advances = '/avanslar';
  static const String report = '/rapor';
  /// Tarla / İş maliyeti dökümü (sayfa içinde iki kırılım arasında geçilir).
  static const String workCosts = '/rapor/tarla';
}

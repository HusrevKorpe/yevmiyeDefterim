/// Avans modeli (plan §3 `advances/{uuid}`, kural §6 çifte sayım yasak).
///
/// Avanslar TEK kaynak: `advances` koleksiyonu; ayrıca ledger'a yazılmaz.
/// Hakedişte mahsup edilince [settledPayrollId] dolar (kapanır). Para = tam sayı
/// kuruş (kural §1). İsim denormalize saklanır (kural §5). freezed/değişmez.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/date/app_date.dart';

part 'advance.freezed.dart';

@freezed
abstract class Advance with _$Advance {
  const Advance._();

  const factory Advance({
    required String id,
    required String workerId,

    /// Denormalize işçi adı (pasif/silinmiş işçide bile gösterim — kural §5).
    required String workerName,

    /// Avans tutarı (kuruş). Kısmi mahsupta kalan tutara düşürülür (devir).
    required int amountKurus,

    /// Avansın verildiği yerel iş günü (`'yyyy-MM-dd'`).
    required String date,

    /// Mahsup edildiği hakediş ID'si. Null => kapanmamış (bir sonraki döneme
    /// devreder). Doluysa kilitli/geçmiş (kural §6).
    String? settledPayrollId,

    /// İsteğe bağlı kısa açıklama (ör. neden/nasıl verildiği).
    String? note,
  }) = _Advance;

  /// Kapanmamış (henüz mahsup/hesap görülmemiş) avans mı?
  bool get isOpen => settledPayrollId == null;

  /// Elle "Hesap görüldü" ile kapatılan avanslarda [settledPayrollId] bu önekle
  /// başlar, ardından kapanış (hesap görüldü) tarihi gelir: `'hesap-goruldu:2026-07-22'`.
  /// Hakediş (rafta) gerçek UUID yazar → önek çakışmaz; ayrımı [isManuallySettled]
  /// yapar. Böylece yeni alan/şema (freezed regen) gerekmeden kapanış tarihi saklanır.
  static const String manualSettlementPrefix = 'hesap-goruldu:';

  /// Verilen [date] için "hesap görüldü" işaret değeri.
  static String manualSettlementId(String date) => '$manualSettlementPrefix$date';

  /// Bu avans elle "Hesap görüldü" ile mi kapatıldı (hakediş mahsubu değil)?
  bool get isManuallySettled =>
      settledPayrollId != null &&
      settledPayrollId!.startsWith(manualSettlementPrefix);

  /// "Hesap görüldü" kapanış tarihi (`'yyyy-MM-dd'`) — elle kapatılmadıysa ya da
  /// işaretteki tarih bozuksa null. Bozuk veri UI'da tarihsiz "Hesap görüldü"
  /// olarak gösterilir; tarih formatlama asla çökmez.
  String? get settledDate {
    if (!isManuallySettled) return null;
    final d = settledPayrollId!.substring(manualSettlementPrefix.length);
    return isValidIsoDate(d) ? d : null;
  }

  /// "Hesap görüldü"de girilen devreden alacak, bu önekle başlayan ID'li YENİ
  /// açık avans olarak yazılır: `'devir-<kapanış-tarihi>-<uuid>'`. Geri almada
  /// ilgili devir kaydı ID'den bulunup silinir (yeni alan/freezed regen
  /// gerekmez; kullanıcı notu/tarihi değiştirse de bağ kopmaz).
  static const String carryoverIdPrefix = 'devir-';

  /// Verilen kapanış tarihi için devir avansı ID'si üretir.
  static String carryoverId(String settledDate, String uuid) =>
      '$carryoverIdPrefix$settledDate-$uuid';

  /// Bu avans, [settledDate] tarihli "hesap görüldü"nün devir kaydı mı?
  bool isCarryoverOf(String settledDate) =>
      id.startsWith('$carryoverIdPrefix$settledDate-');

  /// Firestore dokümanından okur. Eksik/bozuk alanlar güvenli varsayılana düşer
  /// (offline'da kısmi doküman gelebilir — çökme yerine güvenli varsayılan).
  factory Advance.fromDoc(String id, Map<String, dynamic>? data) {
    final m = data ?? const {};
    return Advance(
      id: id,
      workerId: _asString(m['workerId']) ?? '',
      workerName: _asString(m['workerName'])?.trim() ?? '',
      amountKurus: _asInt(m['amountKurus']),
      date: _asString(m['date']) ?? '',
      settledPayrollId: _asString(m['settledPayrollId']),
      note: _asString(m['note'])?.trim(),
    );
  }

  /// Domain alanları (ts/zaman damgaları repository'de eklenir — kural §2).
  Map<String, dynamic> toMap() => {
        'workerId': workerId,
        'workerName': workerName,
        'amountKurus': amountKurus,
        'date': date,
        'settledPayrollId': settledPayrollId,
        'note': note,
      };
}

int _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return 0;
}

/// Bozuk tipte (`as String?` cast hatası yerine) null'a düşer — fromDoc'un
/// "güvenli varsayılan" vaadi tip bozulmasında da geçerli olsun.
String? _asString(Object? v) => v is String ? v : null;

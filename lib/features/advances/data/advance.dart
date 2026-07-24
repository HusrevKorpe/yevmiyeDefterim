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
  /// başlar, ardından kapanış tarihi gelir: `'hesap-goruldu:2026-07-22'`. İsteğe
  /// bağlı olay kimliği (uid) eklenirse: `'hesap-goruldu:2026-07-22:<uid>'` →
  /// aynı işçi aynı gün birden çok kez hesap görülse bile kapanışlar AYRI olaylar
  /// olarak gruplanır (bkz. [settlementKey]). Hakediş (rafta) gerçek UUID yazar →
  /// önek çakışmaz; ayrımı [isManuallySettled] yapar (freezed regen gerekmez).
  static const String manualSettlementPrefix = 'hesap-goruldu:';

  /// Verilen [date] için "hesap görüldü" işaret değeri. [uid] verilirse olay-
  /// benzersiz işaret üretir (aynı gün ikinci kapanış ayrı grup olur); uid'siz
  /// (eski) işaretler tarihe göre gruplanır — geriye dönük uyumlu.
  static String manualSettlementId(String date, [String? uid]) =>
      uid == null ? '$manualSettlementPrefix$date' : '$manualSettlementPrefix$date:$uid';

  /// Bu avans elle "Hesap görüldü" ile mi kapatıldı (hakediş mahsubu değil)?
  bool get isManuallySettled =>
      settledPayrollId != null &&
      settledPayrollId!.startsWith(manualSettlementPrefix);

  /// İşaretin önek sonrası kısmı (`<date>` ya da `<date>:<uid>`) — elle
  /// kapatılmadıysa null.
  String? get _settlementBody => isManuallySettled
      ? settledPayrollId!.substring(manualSettlementPrefix.length)
      : null;

  /// "Hesap görüldü" kapanış tarihi (`'yyyy-MM-dd'`) — elle kapatılmadıysa ya da
  /// işaretteki tarih bozuksa null. Bozuk veri UI'da tarihsiz "Hesap görüldü"
  /// olarak gösterilir; tarih formatlama asla çökmez. Uid'li işarette ilk ':'
  /// öncesi tarihtir.
  String? get settledDate {
    final body = _settlementBody;
    if (body == null) return null;
    final sep = body.indexOf(':');
    final d = sep < 0 ? body : body.substring(0, sep);
    return isValidIsoDate(d) ? d : null;
  }

  /// Kapanış OLAYININ kimliği: uid'li işarette uid, uid'siz (eski) işarette
  /// tarih. "Hesabı Görülenler" gruplaması ve devir kaydı bağlaması bunu kullanır
  /// → aynı gün ikinci kapanış ayrı olay olur; eski işaretler tarihe göre
  /// (eskisi gibi) birleşir. Elle kapatılmadıysa null.
  String? get settlementKey {
    final body = _settlementBody;
    if (body == null) return null;
    final sep = body.indexOf(':');
    return sep < 0 ? body : body.substring(sep + 1);
  }

  /// "Hesap görüldü"de girilen devreden alacak, bu önekle başlayan ID'li YENİ
  /// açık avans olarak yazılır: `'devir-<kapanışKimliği>-<uuid>'`. Geri almada
  /// ilgili devir kaydı ID'den bulunup silinir (yeni alan/freezed regen
  /// gerekmez; kullanıcı notu/tarihi değiştirse de bağ kopmaz).
  static const String carryoverIdPrefix = 'devir-';

  /// Verilen kapanış kimliği ([settlementKey]) için devir avansı ID'si üretir.
  /// Yeni kapanışta uid; eski/testte tarih geçilebilir (aynı string üretir).
  static String carryoverId(String settlementKey, String uuid) =>
      '$carryoverIdPrefix$settlementKey-$uuid';

  /// Bu avans, [settlementKey] kimlikli "hesap görüldü"nün devir kaydı mı?
  bool isCarryoverOf(String settlementKey) =>
      id.startsWith('$carryoverIdPrefix$settlementKey-');

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

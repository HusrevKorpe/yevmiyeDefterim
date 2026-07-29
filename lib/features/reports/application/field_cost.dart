/// Tarla bazlı maliyet dökümü — saf hesap (Firestore'suz → unit test, kural §11).
///
/// "Hangi tarlaya kaç yevmiye, kaç ₺ gitti." Kaynak YALNIZ yoklamadır: giderler
/// (mazot/tamir/bakkal) tarlaya bağlanmaz, bu yüzden buraya girmez — kasa ve
/// işçilik ayrı metriklerdir (çifte sayım yok, kural §6).
///
/// Yoklamadaki tarla seçimi İSTEĞE BAĞLI olduğundan, tarlası seçilmemiş kayıtlar
/// da ayrı bir satırda ("Tarla seçilmemiş") toplanır → dönem işçilik brütü tarla
/// satırlarının toplamına eşittir, para hiçbir yerde kaybolmaz.
///
/// Para geçmişi asla yeniden türetilmez; kayıttaki snapshot kazanç okunur
/// (kural §4). Gün sayımı tam sayı yarım-birim (`half`) üzerinden yapılır →
/// double toplama hatası yok; dışarıya [FieldCost.workdays] ile 0,5'li verilir.
library;

import '../../attendance/data/attendance_record.dart';

/// Tarlası seçilmemiş kayıtların toplandığı satırın adı.
const String kUnassignedFieldLabel = 'Tarla seçilmemiş';

/// Bir tarlada bir işçinin/elebaşının dönem katkısı.
class FieldWorkerCost {
  const FieldWorkerCost({
    required this.workerId,
    required this.workerName,
    required this.isCrew,
    required this.workdayHalves,
    required this.grossKurus,
  });

  final String workerId;
  final String workerName;

  /// Elebaşı kaydı mı? (yevmiye = kişi sayısı, bireysel tam/yarım değil)
  final bool isCrew;

  /// Yevmiye × 2 (tam gün = 2, yarım gün = 1, elebaşı = kişi × 2).
  final int workdayHalves;

  /// Bu tarlada tahakkuk eden brüt (kuruş).
  final int grossKurus;

  /// Adam-gün karşılığı (tam=1, yarım=0,5, elebaşı=kişi sayısı).
  double get workdays => workdayHalves / 2;
}

/// Bir tarlanın dönem maliyeti (işçilik).
class FieldCost {
  const FieldCost({
    required this.fieldId,
    required this.fieldName,
    required this.workdayHalves,
    required this.dayCount,
    required this.grossKurus,
    required this.workers,
  });

  /// `null` → tarlası seçilmemiş kayıtların toplandığı satır.
  final String? fieldId;

  /// Görünen ad. Denormalize saklanan addır (kural §5): tarla sonradan silinse
  /// bile geçmiş okunur kalır. Tarla adı değiştiyse dönemdeki EN SON kaydın adı.
  final String fieldName;

  /// Yevmiye × 2 (bkz. [FieldWorkerCost.workdayHalves]).
  final int workdayHalves;

  /// Bu tarlada çalışılan farklı gün sayısı.
  final int dayCount;

  /// Bu tarlada tahakkuk eden brüt (kuruş).
  final int grossKurus;

  /// İşçi bazında döküm, brüte göre azalan sıralı.
  final List<FieldWorkerCost> workers;

  /// Adam-gün karşılığı (tam=1, yarım=0,5, elebaşı=kişi sayısı).
  double get workdays => workdayHalves / 2;

  /// Bu tarlada gün girilen farklı işçi/elebaşı sayısı.
  int get workerCount => workers.length;

  /// Tarlası seçilmemiş ("kalıntı") satır mı?
  bool get isUnassigned => fieldId == null;
}

bool _inRange(String date, String start, String end) =>
    date.compareTo(start) >= 0 && date.compareTo(end) <= 0;

/// Kaydın yevmiye karşılığı (yarım-birim). Çalışılmayan kayıt 0 döner:
/// "Yok" (absent) ve 0 kişilik elebaşı günü çalışma değildir (aylık tablo ve
/// işçi kazanç dökümüyle tutarlı).
int _workdayHalves(AttendanceRecord r) => switch (r) {
      IndividualAttendance(:final status) => switch (status) {
          AttendanceStatus.full => 2,
          AttendanceStatus.half => 1,
          AttendanceStatus.absent => 0,
        },
      CrewAttendance(:final headcount) => headcount > 0 ? headcount * 2 : 0,
    };

/// [attendance]'tan tarla bazlı maliyet satırlarını türetir.
///
/// - Yalnız `[startIso, endIso]` aralığındaki, fiilen çalışılan kayıtlar sayılır.
/// - Gruplama tarla **ID**'sine göredir (ad değişse bile geçmiş tek satırda
///   toplanır); gösterilen ad dönemdeki en son kaydın adıdır.
/// - Sıralama: brüte göre azalan, eşitlikte ada göre. "Tarla seçilmemiş" satırı
///   bir tarla değil kalıntıdır → tutarı ne olursa olsun EN SONA konur.
List<FieldCost> buildFieldCosts({
  required String startIso,
  required String endIso,
  required List<AttendanceRecord> attendance,
}) {
  final accs = <String, _FieldAcc>{};

  for (final r in attendance) {
    if (!_inRange(r.date, startIso, endIso)) continue;
    final halves = _workdayHalves(r);
    // Çalışılmayan gün (yok / 0 kişi) tarlaya maliyet yazmaz — kazancı da 0.
    if (halves == 0) continue;

    final key = r.fieldId ?? '';
    accs.putIfAbsent(key, () => _FieldAcc(r.fieldId)).add(r, halves);
  }

  final rows = accs.values.map((a) => a.build()).toList()
    ..sort((a, b) {
      // Kalıntı satır her zaman en sonda.
      if (a.isUnassigned != b.isUnassigned) return a.isUnassigned ? 1 : -1;
      final byGross = b.grossKurus.compareTo(a.grossKurus);
      if (byGross != 0) return byGross;
      return a.fieldName.toLowerCase().compareTo(b.fieldName.toLowerCase());
    });

  return rows;
}

/// Tarla satırlarının toplam brütü (kuruş) — pay/oran hesabı için.
int totalFieldGross(List<FieldCost> costs) =>
    costs.fold(0, (sum, f) => sum + f.grossKurus);

/// Yevmiyeyi TR biçiminde yazar: tam sayıysa "6", yarım varsa "6,5".
String formatWorkdays(double workdays) {
  final whole = workdays.floor();
  final hasHalf = workdays - whole >= 0.5;
  return hasHalf ? '$whole,5' : '$whole';
}

/// Tarla bazında birikimli döküm (yalnız builder içi).
class _FieldAcc {
  _FieldAcc(this.fieldId);

  final String? fieldId;

  /// Gösterilecek ad + onu veren kaydın tarihi (en son kayıt kazanır).
  String? _name;
  String _nameDate = '';

  final Set<String> _days = <String>{};
  final Map<String, _FieldWorkerAcc> _workers = <String, _FieldWorkerAcc>{};

  int workdayHalves = 0;
  int grossKurus = 0;

  void add(AttendanceRecord r, int halves) {
    workdayHalves += halves;
    grossKurus += r.earningKurus;
    _days.add(r.date);

    if (fieldId != null && r.date.compareTo(_nameDate) >= 0) {
      final n = r.fieldName?.trim();
      if (n != null && n.isNotEmpty) {
        _name = n;
        _nameDate = r.date;
      }
    }

    _workers
        .putIfAbsent(
          r.workerId,
          () => _FieldWorkerAcc(r.workerId, r.workerName, r is CrewAttendance),
        )
        .add(r, halves);
  }

  FieldCost build() {
    final workers = _workers.values.map((w) => w.build()).toList()
      ..sort((a, b) {
        final byGross = b.grossKurus.compareTo(a.grossKurus);
        if (byGross != 0) return byGross;
        return a.workerName.toLowerCase().compareTo(b.workerName.toLowerCase());
      });

    return FieldCost(
      fieldId: fieldId,
      // Tarla silinmiş + adı da boş kaldıysa satır yine görünür kalsın.
      fieldName: fieldId == null ? kUnassignedFieldLabel : (_name ?? 'Tarla'),
      workdayHalves: workdayHalves,
      dayCount: _days.length,
      grossKurus: grossKurus,
      workers: workers,
    );
  }
}

/// Tarla × işçi birikimi (yalnız builder içi).
class _FieldWorkerAcc {
  _FieldWorkerAcc(this.workerId, this.workerName, this.isCrew);

  final String workerId;
  final String workerName;
  final bool isCrew;

  int workdayHalves = 0;
  int grossKurus = 0;

  void add(AttendanceRecord r, int halves) {
    workdayHalves += halves;
    grossKurus += r.earningKurus;
  }

  FieldWorkerCost build() => FieldWorkerCost(
        workerId: workerId,
        workerName: workerName,
        isCrew: isCrew,
        workdayHalves: workdayHalves,
        grossKurus: grossKurus,
      );
}

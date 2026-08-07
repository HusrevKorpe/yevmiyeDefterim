/// Tarla / yapılan iş bazlı maliyet dökümü — saf hesap (Firestore'suz → unit
/// test, kural §11).
///
/// "Hangi tarlaya" ya da "hangi işe kaç yevmiye, kaç ₺ gitti." AYNI hesap iki
/// kırılım için çalışır ([CostGroupKind]); yoklama kaydında tarla ve iş ayrı
/// ayrı, birbirinden bağımsız seçilir. Kaynak YALNIZ yoklamadır: giderler
/// (mazot/tamir/bakkal) tarlaya/işe bağlanmaz, bu yüzden buraya girmez — kasa ve
/// işçilik ayrı metriklerdir (çifte sayım yok, kural §6).
///
/// Seçim İSTEĞE BAĞLI olduğundan, seçilmemiş kayıtlar da ayrı bir satırda
/// ("Tarla seçilmemiş" / "İş seçilmemiş") toplanır → dönem işçilik brütü
/// satırların toplamına eşittir, para hiçbir yerde kaybolmaz. Her iki kırılımın
/// toplamı da aynıdır (aynı yoklama, farklı gruplama).
///
/// Para geçmişi asla yeniden türetilmez; kayıttaki snapshot kazanç okunur
/// (kural §4). Gün sayımı tam sayı yarım-birim (`half`) üzerinden yapılır →
/// double toplama hatası yok; dışarıya [WorkCost.workdays] ile 0,5'li verilir.
library;

import '../../attendance/data/attendance_record.dart';

/// Seçim yapılmamış kayıtların toplandığı kalıntı satırların adları. Enum
/// alanı yerine ayrıca sabit tutulur: enum getter'ı `const` ifadede
/// kullanılamaz (testlerin sabit örnek verisi bunlara ihtiyaç duyar).
const String kUnassignedPlotLabel = 'Tarla seçilmemiş';
const String kUnassignedJobLabel = 'İş seçilmemiş';

/// Maliyet kırılımının hangi boyuta göre yapıldığı.
///
/// 2026-08-07'ye kadar tek boyut vardı ("tarla") ama içine yapılan iş
/// yazılıyordu → o geçmiş [CostGroupKind.job] tarafında görünür; gerçek tarla
/// verisi o tarihten sonra birikir (bkz. `Plot`).
enum CostGroupKind {
  plot(
    title: 'Tarla',
    unassignedLabel: kUnassignedPlotLabel,
    fallbackName: 'Tarla',
  ),
  job(
    title: 'Yapılan İş',
    unassignedLabel: kUnassignedJobLabel,
    fallbackName: 'İş',
  );

  const CostGroupKind({
    required this.title,
    required this.unassignedLabel,
    required this.fallbackName,
  });

  /// Arayüzde görünen kırılım adı ("Tarla" / "Yapılan İş").
  final String title;

  /// Seçim yapılmamış kayıtların toplandığı kalıntı satırın adı.
  final String unassignedLabel;

  /// Öğe silinmiş VE denormalize adı da boş kalmışsa kullanılan yedek ad.
  final String fallbackName;

  /// Kaydın bu kırılımdaki grup kimliği (`null` → seçilmemiş).
  String? idOf(AttendanceRecord r) => switch (this) {
        CostGroupKind.plot => r.plotId,
        CostGroupKind.job => r.jobId,
      };

  /// Kayıtta denormalize saklanan grup adı (kural §5).
  String? nameOf(AttendanceRecord r) => switch (this) {
        CostGroupKind.plot => r.plotName,
        CostGroupKind.job => r.jobName,
      };
}

/// Bir grupta (tarla ya da iş) bir işçinin/elebaşının dönem katkısı.
class WorkerCostShare {
  const WorkerCostShare({
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

  /// Bu grupta tahakkuk eden brüt (kuruş).
  final int grossKurus;

  /// Adam-gün karşılığı (tam=1, yarım=0,5, elebaşı=kişi sayısı).
  double get workdays => workdayHalves / 2;
}

/// Bir tarlanın ya da bir işin dönem maliyeti (işçilik).
///
/// Hangi kırılımdan geldiği BİLEREK taşınmaz: satır kendi başına anlamlıdır
/// (ad + tutar + döküm), kırılımı zaten çağıran bilir ([buildWorkCosts]'a hangi
/// [CostGroupKind] verildiyse o).
class WorkCost {
  const WorkCost({
    required this.groupId,
    required this.groupName,
    required this.workdayHalves,
    required this.dayCount,
    required this.grossKurus,
    required this.workers,
  });

  /// `null` → seçim yapılmamış kayıtların toplandığı satır.
  final String? groupId;

  /// Görünen ad. Denormalize saklanan addır (kural §5): öğe sonradan silinse
  /// bile geçmiş okunur kalır. Ad değiştiyse dönemdeki EN SON kaydın adı.
  final String groupName;

  /// Yevmiye × 2 (bkz. [WorkerCostShare.workdayHalves]).
  final int workdayHalves;

  /// Bu grupta çalışılan farklı gün sayısı.
  final int dayCount;

  /// Bu grupta tahakkuk eden brüt (kuruş).
  final int grossKurus;

  /// İşçi bazında döküm, brüte göre azalan sıralı.
  final List<WorkerCostShare> workers;

  /// Adam-gün karşılığı (tam=1, yarım=0,5, elebaşı=kişi sayısı).
  double get workdays => workdayHalves / 2;

  /// Bu grupta gün girilen farklı işçi/elebaşı sayısı.
  int get workerCount => workers.length;

  /// Seçim yapılmamış ("kalıntı") satır mı?
  bool get isUnassigned => groupId == null;
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

/// [attendance]'tan [kind] boyutunda maliyet satırlarını türetir.
///
/// - Yalnız `[startIso, endIso]` aralığındaki, fiilen çalışılan kayıtlar sayılır.
/// - Gruplama **ID**'ye göredir (ad değişse bile geçmiş tek satırda toplanır);
///   gösterilen ad dönemdeki en son kaydın adıdır.
/// - Sıralama: brüte göre azalan, eşitlikte ada göre. "Seçilmemiş" satırı bir
///   grup değil kalıntıdır → tutarı ne olursa olsun EN SONA konur.
List<WorkCost> buildWorkCosts({
  required String startIso,
  required String endIso,
  required List<AttendanceRecord> attendance,
  required CostGroupKind kind,
}) {
  final accs = <String, _GroupAcc>{};

  for (final r in attendance) {
    if (!_inRange(r.date, startIso, endIso)) continue;
    final halves = _workdayHalves(r);
    // Çalışılmayan gün (yok / 0 kişi) gruba maliyet yazmaz — kazancı da 0.
    if (halves == 0) continue;

    final id = kind.idOf(r);
    accs.putIfAbsent(id ?? '', () => _GroupAcc(kind, id)).add(r, halves);
  }

  final rows = accs.values.map((a) => a.build()).toList()
    ..sort((a, b) {
      // Kalıntı satır her zaman en sonda.
      if (a.isUnassigned != b.isUnassigned) return a.isUnassigned ? 1 : -1;
      final byGross = b.grossKurus.compareTo(a.grossKurus);
      if (byGross != 0) return byGross;
      return a.groupName.toLowerCase().compareTo(b.groupName.toLowerCase());
    });

  return rows;
}

/// Satırların toplam brütü (kuruş) — pay/oran hesabı için.
int totalWorkGross(List<WorkCost> costs) =>
    costs.fold(0, (sum, c) => sum + c.grossKurus);

/// En az bir kayıtta seçim yapılmış mı? Özellik hiç kullanılmadıysa (tek satır
/// "seçilmemiş") rapor bölümü gösterilmez — gürültü olmaz.
bool hasAssignedCosts(List<WorkCost> costs) =>
    costs.any((c) => !c.isUnassigned);

/// Yevmiyeyi TR biçiminde yazar: tam sayıysa "6", yarım varsa "6,5".
String formatWorkdays(double workdays) {
  final whole = workdays.floor();
  final hasHalf = workdays - whole >= 0.5;
  return hasHalf ? '$whole,5' : '$whole';
}

/// Grup bazında birikimli döküm (yalnız builder içi).
class _GroupAcc {
  _GroupAcc(this.kind, this.groupId);

  final CostGroupKind kind;
  final String? groupId;

  /// Gösterilecek ad + onu veren kaydın tarihi (en son kayıt kazanır).
  String? _name;
  String _nameDate = '';

  final Set<String> _days = <String>{};
  final Map<String, _WorkerAcc> _workers = <String, _WorkerAcc>{};

  int workdayHalves = 0;
  int grossKurus = 0;

  void add(AttendanceRecord r, int halves) {
    workdayHalves += halves;
    grossKurus += r.earningKurus;
    _days.add(r.date);

    if (groupId != null && r.date.compareTo(_nameDate) >= 0) {
      final n = kind.nameOf(r)?.trim();
      if (n != null && n.isNotEmpty) {
        _name = n;
        _nameDate = r.date;
      }
    }

    _workers
        .putIfAbsent(
          r.workerId,
          () => _WorkerAcc(r.workerId, r.workerName, r is CrewAttendance),
        )
        .add(r, halves);
  }

  WorkCost build() {
    final workers = _workers.values.map((w) => w.build()).toList()
      ..sort((a, b) {
        final byGross = b.grossKurus.compareTo(a.grossKurus);
        if (byGross != 0) return byGross;
        return a.workerName.toLowerCase().compareTo(b.workerName.toLowerCase());
      });

    return WorkCost(
      groupId: groupId,
      // Öğe silinmiş + adı da boş kaldıysa satır yine görünür kalsın.
      groupName: groupId == null
          ? kind.unassignedLabel
          : (_name ?? kind.fallbackName),
      workdayHalves: workdayHalves,
      dayCount: _days.length,
      grossKurus: grossKurus,
      workers: workers,
    );
  }
}

/// Grup × işçi birikimi (yalnız builder içi).
class _WorkerAcc {
  _WorkerAcc(this.workerId, this.workerName, this.isCrew);

  final String workerId;
  final String workerName;
  final bool isCrew;

  int workdayHalves = 0;
  int grossKurus = 0;

  void add(AttendanceRecord r, int halves) {
    workdayHalves += halves;
    grossKurus += r.earningKurus;
  }

  WorkerCostShare build() => WorkerCostShare(
        workerId: workerId,
        workerName: workerName,
        isCrew: isCrew,
        workdayHalves: workdayHalves,
        grossKurus: grossKurus,
      );
}

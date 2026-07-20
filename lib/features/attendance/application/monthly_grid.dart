/// Aylık yoklama tablosu — saf hesap (işçi × gün matrisi).
///
/// Excel/kağıt "yoklama cetveli" mantığı: her satır bir işçi, her sütun ayın bir
/// günü, hücre o günkü durum (tam/yarım/yok) ya da elebaşı kişi sayısı. Yalnız o
/// ayda **en az bir kaydı olan** işçiler satır olur (boş satır gürültüsü yok).
/// Para geçmişi asla yeniden türetilmez; kayıttaki `earningKurus` snapshot okunur
/// (kural §4). Saf/deterministik → widget'sız test edilir.
library;

import '../../../core/date/app_date.dart';
import '../../workers/data/worker.dart';
import '../data/attendance_record.dart';

/// Bir işçinin bir gündeki tablo hücresi.
///
/// Bireysel işçide [status] dolu, elebaşıda [crewHeadcount] dolu; ikisi de null
/// ise o gün kayıt yok (boş hücre). "Yok" (absent) bir kayıttır → boş değildir.
class MonthlyGridCell {
  const MonthlyGridCell.individual(AttendanceStatus this.status, this.earningKurus)
      : crewHeadcount = null;

  const MonthlyGridCell.crew(int this.crewHeadcount, this.earningKurus)
      : status = null;

  /// Bireysel gün durumu (null → elebaşı hücresi).
  final AttendanceStatus? status;

  /// Elebaşı kişi sayısı (null → bireysel hücre).
  final int? crewHeadcount;

  /// O günkü kazanç (kuruş) — kayıttan okunan snapshot.
  final int earningKurus;

  bool get isCrew => crewHeadcount != null;
}

/// Tablonun bir satırı: bir işçi + günlük hücreleri + ay toplamları.
class MonthlyWorkerRow {
  const MonthlyWorkerRow({
    required this.workerId,
    required this.workerName,
    required this.type,
    required this.cells,
    required this.fullDays,
    required this.halfDays,
    required this.crewDays,
    required this.crewHeadcountTotal,
    required this.grossKurus,
  });

  final String workerId;
  final String workerName;
  final WorkerType type;

  /// Gün ISO (`'yyyy-MM-dd'`) → hücre. Yalnız kaydı olan günler bulunur;
  /// eksik günler UI'da boş çizilir.
  final Map<String, MonthlyGridCell> cells;

  final int fullDays;
  final int halfDays;
  final int crewDays;
  final int crewHeadcountTotal;

  /// Ay boyunca tahakkuk eden brüt (kuruş) — hücre snapshot'larının toplamı.
  final int grossKurus;

  bool get isCrew => type.isCrew;

  /// Bireysel adam-gün karşılığı (tam=1, yarım=0,5). Elebaşıda 0.
  double get individualDayEquivalent => fullDays + halfDays * 0.5;
}

/// Aylık tablo modeli: gün sütunları + işçi satırları.
class MonthlyAttendanceGrid {
  const MonthlyAttendanceGrid({
    required this.monthIso,
    required this.days,
    required this.rows,
  });

  /// `'yyyy-MM'`.
  final String monthIso;

  /// Ayın tüm günleri (`'yyyy-MM-dd'`), artan sırada — sütun başlıkları.
  final List<String> days;

  /// İşçi satırları (tür → ad sıralı). Kaydı olmayan işçi satır olmaz.
  final List<MonthlyWorkerRow> rows;

  bool get isEmpty => rows.isEmpty;

  /// Ayın toplam işçilik brütü (kuruş).
  int get grossKurus => rows.fold(0, (sum, r) => sum + r.grossKurus);
}

/// [records]'tan seçili ay için işçi×gün matrisi kurar.
///
/// - Yalnız [monthIso] ayına düşen kayıtlar sayılır (savunma amaçlı süzülür).
/// - Satır kümesi = o ayda en az bir kaydı olan işçiler. İsim/tür güncel [workers]
///   listesinden alınır; işçi listede yoksa (silinmiş/pasif) yoklama kaydından
///   türetilir — geçmiş veri kaybolmaz.
/// - Sıralama [compareWorkers] ile aynı: önce tür, sonra ad.
MonthlyAttendanceGrid buildMonthlyGrid({
  required String monthIso,
  required List<Worker> workers,
  required List<AttendanceRecord> records,
}) {
  final days = daysOfMonthIso(monthIso);
  final daySet = days.toSet();
  final workerById = {for (final w in workers) w.id: w};

  // İşçi bazında grupla (yalnız bu ayın kayıtları).
  final grouped = <String, List<AttendanceRecord>>{};
  for (final r in records) {
    if (!daySet.contains(r.date)) continue;
    (grouped[r.workerId] ??= <AttendanceRecord>[]).add(r);
  }

  final rows = <MonthlyWorkerRow>[];
  grouped.forEach((workerId, recs) {
    final w = workerById[workerId];
    final name = w?.name ?? recs.first.workerName;
    final type = w?.type ?? _typeOf(recs.first);

    final cells = <String, MonthlyGridCell>{};
    var fullDays = 0;
    var halfDays = 0;
    var crewDays = 0;
    var crewHeadcountTotal = 0;
    var gross = 0;

    for (final r in recs) {
      gross += r.earningKurus;
      switch (r) {
        case IndividualAttendance(:final status):
          cells[r.date] = MonthlyGridCell.individual(status, r.earningKurus);
          switch (status) {
            case AttendanceStatus.full:
              fullDays++;
            case AttendanceStatus.half:
              halfDays++;
            case AttendanceStatus.absent:
              break;
          }
        case CrewAttendance(:final headcount):
          cells[r.date] = MonthlyGridCell.crew(headcount, r.earningKurus);
          crewDays++;
          crewHeadcountTotal += headcount;
      }
    }

    rows.add(MonthlyWorkerRow(
      workerId: workerId,
      workerName: name,
      type: type,
      cells: cells,
      fullDays: fullDays,
      halfDays: halfDays,
      crewDays: crewDays,
      crewHeadcountTotal: crewHeadcountTotal,
      grossKurus: gross,
    ));
  });

  rows.sort((a, b) {
    final byType = a.type.index.compareTo(b.type.index);
    if (byType != 0) return byType;
    return a.workerName.toLowerCase().compareTo(b.workerName.toLowerCase());
  });

  return MonthlyAttendanceGrid(monthIso: monthIso, days: days, rows: rows);
}

WorkerType _typeOf(AttendanceRecord r) => switch (r) {
      IndividualAttendance(:final workerType) => workerType,
      CrewAttendance() => WorkerType.elebasi,
    };

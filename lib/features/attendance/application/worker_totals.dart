/// Çalışma özeti tablosu — saf hesap (işçi başına TÜM ZAMAN toplamları).
///
/// Aylık cetvelin (bkz. `monthly_grid.dart`) takvimsiz kardeşi: gün sütunu yok,
/// her işçi için tek satır → kaç gün çalıştı, ne kadar kazandı. Ay/hafta seçimi
/// YOKTUR; ilk günden bugüne her şey toplanır. Para geçmişi yeniden türetilmez,
/// kayıttaki `earningKurus` snapshot'ı okunur (kural §4). Saf/deterministik →
/// widget'sız test edilir.
library;

import '../../workers/data/worker.dart';
import '../data/attendance_record.dart';

/// Tablonun bir satırı: bir işçi + tüm zaman toplamları.
class WorkerTotalRow {
  const WorkerTotalRow({
    required this.workerId,
    required this.workerName,
    required this.type,
    required this.fullDays,
    required this.halfDays,
    required this.crewDays,
    required this.crewHeadcountTotal,
    required this.overtimeHours,
    required this.grossKurus,
    this.removed = false,
    this.settledThrough,
  });

  final String workerId;
  final String workerName;
  final WorkerType type;

  /// Bireysel: tam / yarım gün sayısı (elebaşıda 0).
  final int fullDays;
  final int halfDays;

  /// Elebaşı: kişi girilen gün sayısı ve toplam kişi-gün (bireyselde 0).
  final int crewDays;
  final int crewHeadcountTotal;

  /// Toplam mesai (fazla çalışma) saati — kazancın içinde, ayrıca gösterilir.
  final int overtimeHours;

  /// Tüm zamanki brüt kazanç (kuruş) — kayıt snapshot'larının toplamı.
  final int grossKurus;

  /// İşçi artık kullanımda değil (kalıcı silinmiş ya da pasif). Satır yine de
  /// çizilir — geçmiş kaybolmaz — ama listede işaretlenir (aylık cetvelle aynı).
  final bool removed;

  /// Bu işçinin son "Hesap görüldü" tarihi (`'yyyy-MM-dd'`); hiç kapanış yoksa
  /// null. Aylık cetvelle aynı kaynak (bkz. `settlement_cutoff.dart`) — burada
  /// gün gün değil, satır bütünü "hesabı görüldü" olarak işaretlenir.
  final String? settledThrough;

  bool get isCrew => type.isCrew;

  /// Hesabı görülmüş bir işçi mi (en az bir kapanış var).
  bool get isSettled => settledThrough != null;

  /// Tabloda "Gün" sütununda yazan sayı. Bireysel: tam=1, yarım=0,5 (adam-gün).
  /// Elebaşı: kişi girilen gün sayısı (kişi-gün ayrı alanda).
  double get dayCount => isCrew ? crewDays.toDouble() : fullDays + halfDays * 0.5;
}

/// Çalışma özeti modeli: işçi satırları + genel toplamlar.
class WorkerTotalsTable {
  const WorkerTotalsTable({required this.rows});

  /// İşçi satırları (tür → ad sıralı). Hiç kaydı olmayan işçi satır olmaz.
  final List<WorkerTotalRow> rows;

  bool get isEmpty => rows.isEmpty;

  /// Tüm işçilerin brüt toplamı (kuruş).
  int get grossKurus => rows.fold(0, (sum, r) => sum + r.grossKurus);

  /// Tüm satırların gün toplamı (bireysel adam-gün + elebaşı gün sayısı).
  double get dayCount => rows.fold(0.0, (sum, r) => sum + r.dayCount);
}

/// [records]'tan işçi başına tüm-zaman toplamlarını kurar.
///
/// - Satır kümesi = en az bir kaydı olan işçiler; isim/tür güncel [workers]
///   listesinden, işçi listede yoksa (kalıcı silinmiş) kayıttan okunur.
/// - 0 kişilik elebaşı kaydı çalışılan gün DEĞİLDİR → hiç sayılmaz (aylık
///   cetvel ve işçi geçmişiyle aynı kural).
/// - "Yok" (absent) günü kayıttır ama çalışılan gün değildir: gün sayısına
///   girmez, kazancı zaten 0'dır.
/// - Sıralama aylık cetvelle aynı: önce tür, sonra ad.
/// - [settledThroughByWorker] (işçi → son "Hesap görüldü" tarihi) verilirse
///   satır kapanış tarihini taşır; boş geçilirse işaretleme olmaz (avanslar
///   henüz yüklenmediyse tablo yine çizilir).
WorkerTotalsTable buildWorkerTotals({
  required List<Worker> workers,
  required List<AttendanceRecord> records,
  Map<String, String> settledThroughByWorker = const {},
}) {
  final workerById = {for (final w in workers) w.id: w};

  final grouped = <String, List<AttendanceRecord>>{};
  for (final r in records) {
    if (r is CrewAttendance && r.headcount <= 0) continue;
    (grouped[r.workerId] ??= <AttendanceRecord>[]).add(r);
  }

  final rows = <WorkerTotalRow>[];
  grouped.forEach((workerId, recs) {
    final w = workerById[workerId];
    final name = w?.name ?? recs.first.workerName;
    final type = w?.type ?? _typeOf(recs.first);

    var fullDays = 0;
    var halfDays = 0;
    var crewDays = 0;
    var crewHeadcountTotal = 0;
    var overtimeHours = 0;
    var gross = 0;

    for (final r in recs) {
      gross += r.earningKurus;
      overtimeHours += r.overtimeHoursCounted;
      switch (r) {
        case IndividualAttendance(:final status):
          switch (status) {
            case AttendanceStatus.full:
              fullDays++;
            case AttendanceStatus.half:
              halfDays++;
            case AttendanceStatus.absent:
              break;
          }
        case CrewAttendance(:final headcount):
          crewDays++;
          crewHeadcountTotal += headcount;
      }
    }

    rows.add(WorkerTotalRow(
      workerId: workerId,
      workerName: name,
      type: type,
      fullDays: fullDays,
      halfDays: halfDays,
      crewDays: crewDays,
      crewHeadcountTotal: crewHeadcountTotal,
      overtimeHours: overtimeHours,
      grossKurus: gross,
      removed: w == null || !w.active,
      settledThrough: settledThroughByWorker[workerId],
    ));
  });

  rows.sort((a, b) {
    final byType = a.type.index.compareTo(b.type.index);
    if (byType != 0) return byType;
    return a.workerName.toLowerCase().compareTo(b.workerName.toLowerCase());
  });

  return WorkerTotalsTable(rows: rows);
}

WorkerType _typeOf(AttendanceRecord r) => switch (r) {
      IndividualAttendance(:final workerType) => workerType,
      CrewAttendance() => WorkerType.elebasi,
    };

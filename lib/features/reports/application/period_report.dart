/// Dönem raporu — saf fonksiyon (Firestore'suz → unit test, kural §11).
///
/// Dört bağımsız metrik grubu tek dönemde birleşir:
///  1. Kasa: toplam gider + kategori kırılımı ([summarizeLedger]).
///  2. İşçilik: dönemde tahakkuk eden brüt (yoklama kazancı), verilen avans.
///  3. İşçi bazında kazanç dökümü.
///  4. Tarla ve yapılan iş bazında işçilik maliyeti ([buildWorkCosts]) — iki
///     bağımsız kırılım, ikisinin de toplamı işçilik brütüne eşittir.
///
/// Çifte sayım yok (kural §6): kasa ve işçilik AYRI metriklerdir; kasa yalnız
/// ledger'dan, işçilik yalnız yoklama/avanstan türetilir. Girişler
/// dönem dışıysa da güvenli: hepsi [startIso, endIso] aralığına süzülür.
library;

import '../../../core/constants/categories.dart';
import '../../advances/data/advance.dart';
import '../../attendance/data/attendance_record.dart';
import '../../ledger/application/ledger_summary.dart';
import '../../ledger/data/ledger_entry.dart';
import '../../workers/data/worker.dart';
import 'work_cost.dart';

/// Bir işçinin dönem kazanç dökümü (rapor satırı).
class WorkerEarning {
  const WorkerEarning({
    required this.workerId,
    required this.workerName,
    required this.type,
    this.fullDays = 0,
    this.halfDays = 0,
    this.crewDays = 0,
    this.crewHeadcountTotal = 0,
    this.grossKurus = 0,
    this.overtimeHours = 0,
    this.overtimeKurus = 0,
  });

  final String workerId;
  final String workerName;
  final WorkerType type;

  /// Bireysel: tam / yarım gün sayısı.
  final int fullDays;
  final int halfDays;

  /// Elebaşı: kişi girilen gün sayısı ve toplam kişi-gün.
  final int crewDays;
  final int crewHeadcountTotal;

  /// Dönem brüt kazancı (kuruş) — mesai DAHİL.
  final int grossKurus;

  /// Dönemdeki mesai saati ve mesai tutarı (kuruş). [grossKurus] içindedir;
  /// ayrıca gösterilir ki "brütün ne kadarı mesai" görülebilsin.
  final int overtimeHours;
  final int overtimeKurus;

  bool get isCrew => type == WorkerType.elebasi;
}

/// Dönem raporu — kasa özeti + işçilik + işçi bazında kazanç.
class PeriodReport {
  const PeriodReport({
    required this.startIso,
    required this.endIso,
    this.expenseKurus = 0,
    this.expenseByCategory = const {},
    this.grossLaborKurus = 0,
    this.overtimeKurus = 0,
    this.overtimeHours = 0,
    this.advancesGivenKurus = 0,
    this.workerEarnings = const [],
    this.plotCosts = const [],
    this.jobCosts = const [],
  });

  final String startIso;
  final String endIso;

  /// Kasa toplam gideri (kuruş) ve gider kategori kırılımı.
  final int expenseKurus;
  final Map<String, int> expenseByCategory;

  /// Dönemde tahakkuk eden brüt işçilik (yoklama kazançları toplamı, kuruş) —
  /// mesai DAHİLDİR.
  final int grossLaborKurus;

  /// Dönem mesai tutarı (kuruş) ve toplam mesai saati. [grossLaborKurus] içinde
  /// zaten sayılıdır (çifte sayım yok — kural §6); ayrı tutulur ki raporda
  /// "brütün ne kadarı mesai" satırı gösterilebilsin.
  final int overtimeKurus;
  final int overtimeHours;

  /// Dönemde hiç mesai girildi mi? Girilmediyse rapor/PDF/CSV'de mesai satırı
  /// hiç çıkmaz (gürültü olmaz — tarla/iş kırılımıyla aynı desen).
  bool get hasOvertime => overtimeHours > 0 || overtimeKurus > 0;

  /// Dönemde verilen avans toplamı (kuruş).
  final int advancesGivenKurus;

  /// İşçi bazında kazanç, brüte göre azalan sıralı.
  final List<WorkerEarning> workerEarnings;

  /// Tarla bazında işçilik maliyeti (brüte göre azalan; tarlası seçilmemiş
  /// satır en sonda). Toplamı [grossLaborKurus]'a eşittir.
  final List<WorkCost> plotCosts;

  /// Yapılan iş bazında işçilik maliyeti — [plotCosts] ile aynı yoklamanın
  /// ikinci, bağımsız kırılımı (toplamları eşittir; çifte sayım değildir,
  /// aynı parayı iki farklı boyuttan gösterirler).
  ///
  /// 2026-08-07 öncesi kayıtların TAMAMI burada görünür: o tarihe kadar tek
  /// liste vardı ve "tarla" adıyla yapılan iş giriliyordu (bkz. `Job`).
  final List<WorkCost> jobCosts;

  /// En az bir kayıtta tarla seçilmiş mi? Özellik hiç kullanılmadıysa (tek
  /// satır "Tarla seçilmemiş") rapor bölümü gösterilmez — gürültü olmaz.
  bool get hasPlotCosts => hasAssignedCosts(plotCosts);

  /// En az bir kayıtta yapılan iş seçilmiş mi? (bkz. [hasPlotCosts])
  bool get hasJobCosts => hasAssignedCosts(jobCosts);

  /// Dökümde gösterilecek herhangi bir kırılım var mı?
  bool get hasWorkCosts => hasPlotCosts || hasJobCosts;

  /// Dönem mazot gideri (kuruş).
  int get mazotKurus => expenseByCategory[LedgerCategory.mazot] ?? 0;

  /// Dönem tamir gideri (kuruş).
  int get tamirKurus => expenseByCategory[LedgerCategory.tamir] ?? 0;

  /// Dönem bakkal gideri (kuruş).
  int get bakkalKurus => expenseByCategory[LedgerCategory.bakkal] ?? 0;

  /// Rapor tamamen boş mu? (Hiç kayıt yok.)
  bool get isEmpty =>
      expenseKurus == 0 &&
      grossLaborKurus == 0 &&
      advancesGivenKurus == 0 &&
      workerEarnings.isEmpty;
}

bool _inRange(String date, String start, String end) =>
    date.compareTo(start) >= 0 && date.compareTo(end) <= 0;

WorkerType _typeOf(AttendanceRecord r) => switch (r) {
      IndividualAttendance(:final workerType) => workerType,
      CrewAttendance() => WorkerType.elebasi,
    };

/// Dönem raporunu saf biçimde türetir. Tüm girişler [startIso, endIso]
/// aralığına süzülür (önceden süzülmüş veya süzülmemiş liste verilebilir).
PeriodReport buildPeriodReport({
  required String startIso,
  required String endIso,
  required List<AttendanceRecord> attendance,
  required List<Advance> advances,
  required List<LedgerEntry> ledger,
}) {
  // 1. Kasa — dönemdeki gider kayıtları (mevcut saf özet).
  final inPeriodLedger =
      ledger.where((e) => _inRange(e.date, startIso, endIso)).toList();
  final ledgerSummary = summarizeLedger(inPeriodLedger);

  // 2. İşçilik brütü + işçi bazında döküm (dönemdeki yoklamalar).
  var grossLabor = 0;
  var overtimeKurus = 0;
  var overtimeHours = 0;
  final accs = <String, _WorkerAcc>{};
  for (final r in attendance) {
    if (!_inRange(r.date, startIso, endIso)) continue;
    grossLabor += r.earningKurus;
    // Mesai brütün İÇİNDE; burada yalnız kırılımı için ayrıca toplanır.
    overtimeKurus += r.overtimeKurus;
    overtimeHours += r.overtimeHoursCounted;
    accs
        .putIfAbsent(
          r.workerId,
          () => _WorkerAcc(r.workerId, r.workerName, _typeOf(r)),
        )
        .add(r);
  }

  // Verilen avans (dönem içindeki avans tarihleri). Devir (carryover) kaydı
  // gerçek nakit avans DEĞİL — "Hesap Görüldü"de kapanıştan devreden bakiyenin
  // yeni açık avans olarak taşınmasıdır. Orijinal avans zaten sayıldığından onu
  // da saymak çifte sayım olur → `devir-` önekli kayıtlar hariç.
  var advancesGiven = 0;
  for (final a in advances) {
    if (a.id.startsWith(Advance.carryoverIdPrefix)) continue;
    if (_inRange(a.date, startIso, endIso)) advancesGiven += a.amountKurus;
  }

  // Yalnız fiilen çalışılan (gün girilen) işçileri listele → gürültüsüz.
  final earnings = accs.values
      .where((a) => a.hasActivity)
      .map((a) => a.build())
      .toList()
    ..sort((a, b) => b.grossKurus.compareTo(a.grossKurus));

  return PeriodReport(
    startIso: startIso,
    endIso: endIso,
    expenseKurus: ledgerSummary.expenseKurus,
    expenseByCategory: ledgerSummary.expenseByCategory,
    grossLaborKurus: grossLabor,
    overtimeKurus: overtimeKurus,
    overtimeHours: overtimeHours,
    advancesGivenKurus: advancesGiven,
    workerEarnings: earnings,
    // 4. Tarla ve iş bazında işçilik (aynı yoklama listesinden, iki ayrı
    // kırılım; her ikisinin toplamı da grossLabor'a eşittir).
    plotCosts: buildWorkCosts(
      startIso: startIso,
      endIso: endIso,
      attendance: attendance,
      kind: CostGroupKind.plot,
    ),
    jobCosts: buildWorkCosts(
      startIso: startIso,
      endIso: endIso,
      attendance: attendance,
      kind: CostGroupKind.job,
    ),
  );
}

/// İşçi bazında birikimli döküm (yalnız builder içi).
class _WorkerAcc {
  _WorkerAcc(this.workerId, this.workerName, this.type);

  final String workerId;
  final String workerName;
  final WorkerType type;

  int fullDays = 0;
  int halfDays = 0;
  int crewDays = 0;
  int crewHeadcountTotal = 0;
  int grossKurus = 0;
  int overtimeHours = 0;
  int overtimeKurus = 0;

  bool get hasActivity => fullDays + halfDays + crewDays > 0;

  void add(AttendanceRecord r) {
    grossKurus += r.earningKurus;
    overtimeHours += r.overtimeHoursCounted;
    overtimeKurus += r.overtimeKurus;
    switch (r) {
      case IndividualAttendance(:final status):
        if (status == AttendanceStatus.full) {
          fullDays++;
        } else if (status == AttendanceStatus.half) {
          halfDays++;
        }
      case CrewAttendance(:final headcount):
        if (headcount > 0) {
          crewDays++;
          crewHeadcountTotal += headcount;
        }
    }
  }

  WorkerEarning build() => WorkerEarning(
        workerId: workerId,
        workerName: workerName,
        type: type,
        fullDays: fullDays,
        halfDays: halfDays,
        crewDays: crewDays,
        crewHeadcountTotal: crewHeadcountTotal,
        grossKurus: grossKurus,
        overtimeHours: overtimeHours,
        overtimeKurus: overtimeKurus,
      );
}

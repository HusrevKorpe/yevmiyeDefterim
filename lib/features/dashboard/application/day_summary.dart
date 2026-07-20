/// Günlük yoklama özeti — saf fonksiyon (Firestore'suz → unit test, kural §11).
library;

import '../../attendance/data/attendance_record.dart';
import '../../workers/data/worker.dart';

class DaySummary {
  const DaySummary({
    this.fullCount = 0,
    this.halfCount = 0,
    this.absentCount = 0,
    this.femaleCount = 0,
    this.maleCount = 0,
    this.crewHeadcount = 0,
    this.crewCount = 0,
    this.totalKurus = 0,
  });

  /// Tam gün işaretli bireysel işçi sayısı.
  final int fullCount;

  /// Yarım gün işaretli bireysel işçi sayısı.
  final int halfCount;

  /// Yok işaretli bireysel işçi sayısı.
  final int absentCount;

  /// Fiilen gelen (tam/yarım) kadın işçi sayısı. Cinsiyet, işçi listesinden
  /// (workerId → Gender) çözülür; kaydı bulunamayan işçi hiçbir yana sayılmaz.
  final int femaleCount;

  /// Fiilen gelen (tam/yarım) erkek işçi sayısı.
  final int maleCount;

  /// Elebaşılara bağlı toplam kişi sayısı.
  final int crewHeadcount;

  /// Kişi sayısı > 0 olan elebaşı sayısı.
  final int crewCount;

  /// Günün toplam işçilik maliyeti (kuruş) = Σ kazanç. (Ana Sayfa'da gizli.)
  final int totalKurus;

  /// İşaretlenmiş bireysel işçi sayısı (tam + yarım + yok).
  int get markedIndividuals => fullCount + halfCount + absentCount;

  /// Fiilen gelen (tam veya yarım) bireysel işçi sayısı.
  int get presentIndividuals => fullCount + halfCount;

  @override
  bool operator ==(Object other) =>
      other is DaySummary &&
      other.fullCount == fullCount &&
      other.halfCount == halfCount &&
      other.absentCount == absentCount &&
      other.femaleCount == femaleCount &&
      other.maleCount == maleCount &&
      other.crewHeadcount == crewHeadcount &&
      other.crewCount == crewCount &&
      other.totalKurus == totalKurus;

  @override
  int get hashCode => Object.hash(fullCount, halfCount, absentCount, femaleCount,
      maleCount, crewHeadcount, crewCount, totalKurus);
}

/// Bir günün yoklama kayıtlarını özetler.
///
/// [genderById]: işçi kimliğinden cinsiyete eşleme (işçi listesinden kurulur).
/// Fiilen gelen bireysel işçileri kadın/erkek olarak ayırmak için kullanılır;
/// boş verilirse cinsiyet sayıları 0 kalır (özet yine de doğru çalışır).
DaySummary summarizeDay(
  List<AttendanceRecord> records, {
  Map<String, Gender> genderById = const {},
}) {
  var full = 0, half = 0, absent = 0, female = 0, male = 0;
  var crewHead = 0, crewCount = 0, total = 0;
  for (final r in records) {
    total += r.earningKurus;
    switch (r) {
      case IndividualAttendance(:final status, :final workerId):
        switch (status) {
          case AttendanceStatus.full:
            full++;
          case AttendanceStatus.half:
            half++;
          case AttendanceStatus.absent:
            absent++;
        }
        // Yalnız gelenleri (tam/yarım) cinsiyete böl.
        if (status != AttendanceStatus.absent) {
          switch (genderById[workerId]) {
            case Gender.female:
              female++;
            case Gender.male:
              male++;
            case null:
              break; // Bilinmiyorsa hiçbir yana sayma.
          }
        }
      case CrewAttendance(:final headcount):
        crewHead += headcount;
        if (headcount > 0) crewCount++;
    }
  }
  return DaySummary(
    fullCount: full,
    halfCount: half,
    absentCount: absent,
    femaleCount: female,
    maleCount: male,
    crewHeadcount: crewHead,
    crewCount: crewCount,
    totalKurus: total,
  );
}

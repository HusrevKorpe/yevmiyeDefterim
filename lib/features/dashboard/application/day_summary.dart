/// Günlük yoklama özeti — saf fonksiyon (Firestore'suz → unit test, kural §11).
library;

import '../../attendance/data/attendance_record.dart';

class DaySummary {
  const DaySummary({
    this.fullCount = 0,
    this.halfCount = 0,
    this.absentCount = 0,
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

  /// Elebaşılara bağlı toplam kişi sayısı.
  final int crewHeadcount;

  /// Kişi sayısı > 0 olan elebaşı sayısı.
  final int crewCount;

  /// Günün toplam işçilik maliyeti (kuruş) = Σ kazanç.
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
      other.crewHeadcount == crewHeadcount &&
      other.crewCount == crewCount &&
      other.totalKurus == totalKurus;

  @override
  int get hashCode => Object.hash(fullCount, halfCount, absentCount,
      crewHeadcount, crewCount, totalKurus);
}

/// Bir günün yoklama kayıtlarını özetler.
DaySummary summarizeDay(List<AttendanceRecord> records) {
  var full = 0, half = 0, absent = 0, crewHead = 0, crewCount = 0, total = 0;
  for (final r in records) {
    total += r.earningKurus;
    switch (r) {
      case IndividualAttendance(:final status):
        switch (status) {
          case AttendanceStatus.full:
            full++;
          case AttendanceStatus.half:
            half++;
          case AttendanceStatus.absent:
            absent++;
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
    crewHeadcount: crewHead,
    crewCount: crewCount,
    totalKurus: total,
  );
}

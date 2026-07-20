/// Yoklama kaydı (plan §3 `attendance/{date_workerId}`, kural §3, §4).
///
/// Deterministik ID + `merge:true` → çift kayıt yok. İki tür: bireysel işçi
/// (durum + dondurulmuş ücret) ve elebaşı (kişi sayısı + dondurulmuş kişi ücreti).
/// İsim/tür denormalize saklanır (kural §5). Para = tam sayı kuruş (kural §1).
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/money/money.dart';
import '../../workers/data/worker.dart';

part 'attendance_record.freezed.dart';

/// Bireysel işçi günlük durumu.
enum AttendanceStatus { full, half, absent }

extension AttendanceStatusX on AttendanceStatus {
  String get label => switch (this) {
        AttendanceStatus.full => 'Tam',
        AttendanceStatus.half => 'Yarım',
        AttendanceStatus.absent => 'Yok',
      };
}

@freezed
sealed class AttendanceRecord with _$AttendanceRecord {
  const AttendanceRecord._();

  /// Bireysel işçi (sabit/gündelik): durum + o günkü ücret dondurulmuş.
  ///
  /// [paidPayrollId]: bu gün bir hakedişte ödendiyse dolar (Faz 2). Yalnız "Öde"
  /// batch'i alan-bazlı yazar; normal yoklama kaydı bu alanı EZMEZ (kural §3).
  const factory AttendanceRecord.individual({
    required String id,
    required String date,
    required String workerId,
    required String workerName,
    required WorkerType workerType,
    required AttendanceStatus status,
    required int wageSnapshotKurus,
    String? paidPayrollId,
  }) = IndividualAttendance;

  /// Elebaşı: kişi sayısı + o günkü kişi-başı ücret dondurulmuş.
  /// [agreedPayKurus] doluysa günlük toplam ona eşittir (kural §10).
  /// [paidPayrollId]: bkz. [AttendanceRecord.individual].
  const factory AttendanceRecord.crew({
    required String id,
    required String date,
    required String workerId,
    required String workerName,
    required int headcount,
    required int crewRateSnapshotKurus,
    int? agreedPayKurus,
    String? paidPayrollId,
  }) = CrewAttendance;

  /// Bu gün bir hakedişte ödendi mi? Ödenen günler hakediş brütüne tekrar
  /// katılmaz (çifte ödeme engeli — kural §6).
  bool get isPaid => paidPayrollId != null;

  /// O günkü kazanç (kuruş). Geçmiş ücret asla yeniden türetilmez; snapshot okunur
  /// (kural §4). Bireysel: tam=ücret, yarım=ücret~/2, yok=0.
  /// Elebaşı: agreedPay ?? kişi × kişiücret.
  int get earningKurus => switch (this) {
        IndividualAttendance(:final status, :final wageSnapshotKurus) =>
          switch (status) {
            AttendanceStatus.full => wageSnapshotKurus,
            AttendanceStatus.half => halfWage(wageSnapshotKurus),
            AttendanceStatus.absent => 0,
          },
        CrewAttendance(
          :final headcount,
          :final crewRateSnapshotKurus,
          :final agreedPayKurus,
        ) =>
          agreedPayKurus ?? headcount * crewRateSnapshotKurus,
      };

  /// Firestore'a yazılacak alanlar (ts/zaman damgaları repository'de eklenir).
  /// [paidPayrollId] BİLEREK yok: yalnız "Öde" batch'i alan-bazlı yazar, normal
  /// yoklama kaydı ödeme işaretini ezmemeli (kural §3).
  Map<String, dynamic> toMap() => switch (this) {
        IndividualAttendance(
          :final date,
          :final workerId,
          :final workerName,
          :final workerType,
          :final status,
          :final wageSnapshotKurus,
        ) =>
          {
            'date': date,
            'workerId': workerId,
            'workerName': workerName,
            'workerType': workerType.name,
            'status': status.name,
            'wageSnapshotKurus': wageSnapshotKurus,
          },
        CrewAttendance(
          :final date,
          :final workerId,
          :final workerName,
          :final headcount,
          :final crewRateSnapshotKurus,
          :final agreedPayKurus,
        ) =>
          {
            'date': date,
            'workerId': workerId,
            'workerName': workerName,
            'workerType': WorkerType.elebasi.name,
            'headcount': headcount,
            'crewRateSnapshotKurus': crewRateSnapshotKurus,
            'agreedPayKurus': agreedPayKurus,
          },
      };

  /// Firestore dokümanından okur. workerType='elebasi' → elebaşı kaydı.
  factory AttendanceRecord.fromDoc(String id, Map<String, dynamic>? data) {
    final m = data ?? const {};
    final date = (m['date'] as String?) ?? '';
    final workerId = (m['workerId'] as String?) ?? '';
    final workerName = (m['workerName'] as String?) ?? '';
    final isCrew = m['workerType'] == WorkerType.elebasi.name;

    if (isCrew) {
      return AttendanceRecord.crew(
        id: id,
        date: date,
        workerId: workerId,
        workerName: workerName,
        headcount: _asInt(m['headcount']),
        crewRateSnapshotKurus: _asInt(m['crewRateSnapshotKurus']),
        agreedPayKurus: _asIntOrNull(m['agreedPayKurus']),
        paidPayrollId: m['paidPayrollId'] as String?,
      );
    }
    return AttendanceRecord.individual(
      id: id,
      date: date,
      workerId: workerId,
      workerName: workerName,
      workerType: _typeFromName(m['workerType']),
      status: _statusFromName(m['status']),
      wageSnapshotKurus: _asInt(m['wageSnapshotKurus']),
      paidPayrollId: m['paidPayrollId'] as String?,
    );
  }
}

WorkerType _typeFromName(Object? v) => WorkerType.values.firstWhere(
      (t) => t.name == v,
      orElse: () => WorkerType.gundelik,
    );

AttendanceStatus _statusFromName(Object? v) =>
    AttendanceStatus.values.firstWhere(
      (s) => s.name == v,
      orElse: () => AttendanceStatus.absent,
    );

int _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return 0;
}

int? _asIntOrNull(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return null;
}

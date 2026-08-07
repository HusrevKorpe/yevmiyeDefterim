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

/// Bir günde girilebilecek en fazla mesai saati. Hazır çipler (1–4 saat) dışında
/// elle girilen ("Diğer") saat de bu sınırla kırpılır → yanlış basımla 100 saat
/// mesai yazılıp kazancın şişmesi engellenir.
const int kMaxOvertimeHours = 16;

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
  ///
  /// [jobId]/[jobName]: o gün YAPILAN İŞ (çapa, sulama…) ve
  /// [plotId]/[plotName]: o gün çalışılan TARLA. İkisi de İSTEĞE BAĞLI ve
  /// birbirinden bağımsız seçilir. Adlar denormalize saklanır (kural §5): iş/tarla
  /// sonradan silinse/adı değişse bile geçmiş kayıt okunur kalır.
  ///
  /// FIRESTORE ADI TARİHSELDİR: iş alanları diskte `fieldId`/`fieldName` olarak
  /// durur (bkz. [Job]) — 2026-08-07 tarla/iş ayrımında liste yerinde bırakılıp
  /// anlamı düzeltildi, böylece geçmiş kayıtlar göç etmeden doğru tarafa geçti.
  /// Tarla alanları (`plotId`/`plotName`) o tarihte açıldı → eski kayıtlarda YOK.
  ///
  /// [overtimeHours]/[overtimeRateSnapshotKurus]: o gün kalınan mesai (fazla
  /// çalışma) saati + o günkü SAAT ücreti dondurulmuş (kural §4 — yevmiye
  /// snapshot'ıyla aynı mantık). Mesai isteğe bağlıdır; 0 saat = mesai yok.
  const factory AttendanceRecord.individual({
    required String id,
    required String date,
    required String workerId,
    required String workerName,
    required WorkerType workerType,
    required AttendanceStatus status,
    required int wageSnapshotKurus,
    @Default(0) int overtimeHours,
    @Default(0) int overtimeRateSnapshotKurus,
    String? paidPayrollId,
    String? jobId,
    String? jobName,
    String? plotId,
    String? plotName,
  }) = IndividualAttendance;

  /// Elebaşı: kişi sayısı + o günkü kişi-başı ücret dondurulmuş.
  /// [agreedPayKurus] doluysa günlük toplam ona eşittir (kural §10).
  /// [paidPayrollId]: bkz. [AttendanceRecord.individual].
  /// [jobId]/[jobName], [plotId]/[plotName]: bkz. [AttendanceRecord.individual].
  const factory AttendanceRecord.crew({
    required String id,
    required String date,
    required String workerId,
    required String workerName,
    required int headcount,
    required int crewRateSnapshotKurus,
    int? agreedPayKurus,
    String? paidPayrollId,
    String? jobId,
    String? jobName,
    String? plotId,
    String? plotName,
  }) = CrewAttendance;

  /// Bu gün bir hakedişte ödendi mi? Ödenen günler hakediş brütüne tekrar
  /// katılmaz (çifte ödeme engeli — kural §6).
  bool get isPaid => paidPayrollId != null;

  /// O günkü mesai tutarı (kuruş) = saat × dondurulmuş saat ücreti.
  ///
  /// "Yok" işaretli günde 0'dır: gelmeyen işçinin mesaisi olamaz. (Yoklama
  /// ekranı "Yok" seçilince mesai saatini de temizler; bu koruma başka bir
  /// cihazdan gelen tutarsız kayıtta hayalet mesai ücreti oluşmasını engeller.)
  /// Elebaşıda mesai YOK → her zaman 0.
  int get overtimeKurus => switch (this) {
        IndividualAttendance(
          :final status,
          :final overtimeHours,
          :final overtimeRateSnapshotKurus,
        ) =>
          status == AttendanceStatus.absent
              ? 0
              : overtimeHours * overtimeRateSnapshotKurus,
        CrewAttendance() => 0,
      };

  /// Kazanca giren mesai saati. "Yok" günde 0, elebaşıda 0 ([overtimeKurus] ile
  /// aynı kural) → rapor saat toplamı ile mesai tutarı hep tutarlıdır.
  int get overtimeHoursCounted => switch (this) {
        IndividualAttendance(:final status, :final overtimeHours) =>
          status == AttendanceStatus.absent ? 0 : overtimeHours,
        CrewAttendance() => 0,
      };

  /// O günkü kazanç (kuruş). Geçmiş ücret asla yeniden türetilmez; snapshot okunur
  /// (kural §4). Bireysel: tam=ücret, yarım=ücret~/2, yok=0 — üstüne mesai
  /// ([overtimeKurus]) eklenir. Elebaşı: agreedPay ?? kişi × kişiücret.
  int get earningKurus => switch (this) {
        IndividualAttendance(:final status, :final wageSnapshotKurus) =>
          switch (status) {
            AttendanceStatus.full => wageSnapshotKurus,
            AttendanceStatus.half => halfWage(wageSnapshotKurus),
            AttendanceStatus.absent => 0,
          } +
              overtimeKurus,
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
          :final overtimeHours,
          :final overtimeRateSnapshotKurus,
          :final jobId,
          :final jobName,
          :final plotId,
          :final plotName,
        ) =>
          {
            'date': date,
            'workerId': workerId,
            'workerName': workerName,
            'workerType': workerType.name,
            'status': status.name,
            'wageSnapshotKurus': wageSnapshotKurus,
            // 0 olsa da yazılır: merge:true altında mesaiyi kaldırmak (0 saat)
            // Firestore'daki eski saati de temizlemeli (iş/tarla alanlarıyla
            // aynı gerekçe).
            'overtimeHours': overtimeHours,
            'overtimeRateSnapshotKurus': overtimeRateSnapshotKurus,
            // Bilerek null'ken de yazılır: merge:true altında iş/tarla seçimini
            // kaldırmak (null) Firestore'daki eski değeri de temizlemeli.
            // `fieldId`/`fieldName` = YAPILAN İŞ (tarihsel ad, bkz. sınıf notu).
            'fieldId': jobId,
            'fieldName': jobName,
            'plotId': plotId,
            'plotName': plotName,
          },
        CrewAttendance(
          :final date,
          :final workerId,
          :final workerName,
          :final headcount,
          :final crewRateSnapshotKurus,
          :final agreedPayKurus,
          :final jobId,
          :final jobName,
          :final plotId,
          :final plotName,
        ) =>
          {
            'date': date,
            'workerId': workerId,
            'workerName': workerName,
            'workerType': WorkerType.elebasi.name,
            'headcount': headcount,
            'crewRateSnapshotKurus': crewRateSnapshotKurus,
            'agreedPayKurus': agreedPayKurus,
            // `fieldId`/`fieldName` = YAPILAN İŞ (tarihsel ad, bkz. sınıf notu).
            'fieldId': jobId,
            'fieldName': jobName,
            'plotId': plotId,
            'plotName': plotName,
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
        jobId: m['fieldId'] as String?,
        jobName: m['fieldName'] as String?,
        plotId: m['plotId'] as String?,
        plotName: m['plotName'] as String?,
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
      // Eski kayıtlarda alan yok → 0 (mesai yok).
      overtimeHours: _asInt(m['overtimeHours']),
      overtimeRateSnapshotKurus: _asInt(m['overtimeRateSnapshotKurus']),
      paidPayrollId: m['paidPayrollId'] as String?,
      jobId: m['fieldId'] as String?,
      jobName: m['fieldName'] as String?,
      plotId: m['plotId'] as String?,
      plotName: m['plotName'] as String?,
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

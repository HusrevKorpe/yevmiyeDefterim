/// Dönem raporunu CSV'ye çeviren saf fonksiyon (Firestore'suz → test, §11).
///
/// TR-Excel dostu: `;` ayırıcı (virgül ondalıktır), UTF-8 BOM (Türkçe karakter),
/// tutarlar sembolsüz TR formatında ("1.234,56"). Alanlar gerekince tırnaklanır.
library;

import '../../../core/money/money.dart';
import '../../workers/data/worker.dart';
import 'work_cost.dart';
import 'period_report.dart';

/// TR-Excel ayırıcısı (virgül ondalık olduğu için).
const String _sep = ';';

/// UTF-8 BOM — Excel'in Türkçe karakterleri doğru açması için.
const String _bom = '﻿';

/// Bir CSV alanını gerekiyorsa tırnaklar (`;`, `"`, yeni satır içeriyorsa).
String _field(String value) {
  if (value.contains(_sep) || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String _row(List<String> cells) => cells.map(_field).join(_sep);

/// Bir maliyet satırı (tarla ya da iş) — iki bölüm aynı sütun düzenini paylaşır.
List<String> _costRows(WorkCost c) => [
      _row([
        c.groupName,
        formatWorkdays(c.workdays),
        '${c.dayCount}',
        '${c.workerCount}',
        formatKurusPlain(c.grossKurus),
      ]),
    ];

/// Dönem raporunu CSV metnine dönüştürür (paylaşım/dışa aktarma için).
String buildReportCsv(PeriodReport report) {
  final lines = <String>[
    _row(['Yevmiye Defteri - Dönem Raporu']),
    _row(['Dönem', '${report.startIso} - ${report.endIso}']),
    '',
    _row(['KASA']),
    _row(['Toplam gider', formatKurusPlain(report.expenseKurus)]),
    _row(['Mazot', formatKurusPlain(report.mazotKurus)]),
    _row(['Tamir', formatKurusPlain(report.tamirKurus)]),
    _row(['Bakkal', formatKurusPlain(report.bakkalKurus)]),
    '',
    _row(['İŞÇİLİK']),
    _row(['Tahakkuk eden brüt', formatKurusPlain(report.grossLaborKurus)]),
    // Mesai brütün içindedir; kırılım satırı yalnız mesai girildiyse yazılır.
    if (report.hasOvertime) ...[
      _row(['Bunun mesaisi', formatKurusPlain(report.overtimeKurus)]),
      _row(['Mesai saati', '${report.overtimeHours}']),
    ],
    _row(['Verilen avans', formatKurusPlain(report.advancesGivenKurus)]),
    // Tarla ve iş kırılımları yalnız o seçim kullanıldıysa yazılır (boş bölüm
    // yok). İkisi de yazılabilir: aynı parayı iki ayrı boyuttan gösterirler,
    // toplamları eşittir (çifte sayım değil — bkz. [PeriodReport.jobCosts]).
    if (report.hasPlotCosts) ...[
      '',
      _row(['TARLA MALİYETİ (İŞÇİLİK)']),
      _row(['Tarla', 'Yevmiye', 'Gün', 'İşçi', 'Tutar (TL)']),
      for (final c in report.plotCosts) ..._costRows(c),
    ],
    if (report.hasJobCosts) ...[
      '',
      _row(['İŞ MALİYETİ (İŞÇİLİK)']),
      _row(['Yapılan iş', 'Yevmiye', 'Gün', 'İşçi', 'Tutar (TL)']),
      for (final c in report.jobCosts) ..._costRows(c),
    ],
    '',
    _row(['İŞÇİ KAZANÇLARI']),
    _row([
      'İşçi',
      'Tür',
      'Tam gün',
      'Yarım gün',
      'Elebaşı gün',
      'Kişi-gün',
      'Mesai saati',
      'Mesai (TL)',
      'Brüt (TL)',
    ]),
    for (final e in report.workerEarnings)
      _row([
        e.workerName,
        e.type.label,
        '${e.fullDays}',
        '${e.halfDays}',
        '${e.crewDays}',
        '${e.crewHeadcountTotal}',
        '${e.overtimeHours}',
        formatKurusPlain(e.overtimeKurus),
        // Brüt mesai DAHİL toplamdır (mesai kolonu yalnız kırılım).
        formatKurusPlain(e.grossKurus),
      ]),
  ];

  return '$_bom${lines.join('\r\n')}\r\n';
}

/// Paylaşım için önerilen dosya adı (ör. `rapor_2026-07-01_2026-07-31.csv`).
String reportFileBase(PeriodReport report) =>
    'rapor_${report.startIso}_${report.endIso}';

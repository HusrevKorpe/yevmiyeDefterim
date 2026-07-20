/// Dönem raporunu PDF'e çeviren servis (Faz 4). Saf DEĞİL (font yükler) —
/// bu yüzden application katmanında ayrı tutulur; saf metrik [PeriodReport]'tadır.
///
/// Türkçe glif için `printing` Google fontunu (Roboto) yükler; çevrimdışı/önbelleksiz
/// başarısız olursa gömülü Helvetica'ya düşer ve metni ASCII'ye çevirir (glif
/// eksikliğinde kutu yerine okunur metin). Para `₺` yerine "TL" (her iki fontta var).
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/money/money.dart';
import '../../workers/data/worker.dart';
import 'period_report.dart';

/// Yüklenen fontlar + Türkçe glif desteklenmiyorsa çeviri bayrağı.
class _Fonts {
  _Fonts(this.base, this.bold, {required this.translit});
  final pw.Font base;
  final pw.Font bold;
  final bool translit;
}

Future<_Fonts> _loadFonts() async {
  try {
    final base = await PdfGoogleFonts.robotoRegular();
    final bold = await PdfGoogleFonts.robotoBold();
    return _Fonts(base, bold, translit: false);
  } catch (_) {
    // Çevrimdışı ve önbellek yok → gömülü font, Türkçe'yi ASCII'ye çevir.
    return _Fonts(pw.Font.helvetica(), pw.Font.helveticaBold(), translit: true);
  }
}

String _translitTr(String s) => s
    .replaceAll('ı', 'i')
    .replaceAll('İ', 'I')
    .replaceAll('ş', 's')
    .replaceAll('Ş', 'S')
    .replaceAll('ğ', 'g')
    .replaceAll('Ğ', 'G')
    .replaceAll('ü', 'u')
    .replaceAll('Ü', 'U')
    .replaceAll('ö', 'o')
    .replaceAll('Ö', 'O')
    .replaceAll('ç', 'c')
    .replaceAll('Ç', 'C');

/// Dönem raporunu PDF baytlarına dönüştürür (paylaşım/yazdırma için).
Future<Uint8List> buildReportPdf(PeriodReport report) async {
  final f = await _loadFonts();
  String t(String s) => f.translit ? _translitTr(s) : s;
  String money(int k) => '${formatKurusPlain(k)} TL';

  final theme = pw.ThemeData.withFont(base: f.base, bold: f.bold);
  final doc = pw.Document(theme: theme);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => [
        pw.Text(
          t('Yevmiye Defteri - Dönem Raporu'),
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          t('Dönem: ${report.startIso} - ${report.endIso}'),
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 16),

        _title(t('Kasa')),
        _kv(t('Toplam gider'), money(report.expenseKurus), bold: true),
        if (report.mazotKurus > 0) _kv(t('Mazot'), money(report.mazotKurus)),
        pw.SizedBox(height: 14),

        _title(t('İşçilik')),
        _kv(t('Tahakkuk eden brüt'), money(report.grossLaborKurus)),
        _kv(t('Ödenen (net)'), money(report.netPaidKurus)),
        _kv(t('Verilen avans'), money(report.advancesGivenKurus)),
        pw.SizedBox(height: 14),

        _title(t('İşçi Kazançları (${report.workerEarnings.length})')),
        if (report.workerEarnings.isEmpty)
          pw.Text(t('Bu dönemde çalışan işçi kaydı yok.'))
        else
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.centerRight,
            },
            headers: [
              t('İşçi'),
              t('Tür'),
              t('Tam'),
              t('Yarım'),
              t('Kişi-gün'),
              t('Brüt (TL)'),
            ],
            data: [
              for (final e in report.workerEarnings)
                [
                  t(e.workerName),
                  t(e.type.label),
                  e.isCrew ? '-' : '${e.fullDays}',
                  e.isCrew ? '-' : '${e.halfDays}',
                  e.isCrew ? '${e.crewHeadcountTotal}' : '-',
                  formatKurusPlain(e.grossKurus),
                ],
            ],
          ),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _title(String text) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
    );

pw.Widget _kv(String label, String value, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );

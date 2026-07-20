/// Rapor paylaşımı — CSV (share_plus) ve PDF (printing) dışa aktarma (Faz 4).
///
/// Saf üretim [buildReportCsv]/[buildReportPdf]'tedir; burada yalnız platform
/// paylaşım köprüsü. UI'dan çağrılır (BuildContext gerekmez).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'period_report.dart';
import 'report_csv.dart';
import 'report_pdf.dart';

/// Raporu CSV dosyası olarak paylaşır (TR-Excel dostu, UTF-8 BOM).
Future<void> shareReportCsv(PeriodReport report) async {
  final bytes = Uint8List.fromList(utf8.encode(buildReportCsv(report)));
  final file = XFile.fromData(
    bytes,
    mimeType: 'text/csv',
    name: '${reportFileBase(report)}.csv',
  );
  await SharePlus.instance.share(
    ShareParams(files: [file], subject: 'Yevmiye Defteri Raporu'),
  );
}

/// Raporu PDF dosyası olarak paylaşır (yazdır/paylaş yaprağı).
Future<void> shareReportPdf(PeriodReport report) async {
  final bytes = await buildReportPdf(report);
  await Printing.sharePdf(
    bytes: bytes,
    filename: '${reportFileBase(report)}.pdf',
  );
}

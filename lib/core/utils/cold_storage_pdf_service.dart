import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../constants/app_assets.dart';

/// خدمة عامة ومستقلة في Core لطباعة أي تقرير جدولي باللغة العربية بخط Cairo ولوجو الشركة
class ColdStoragePdfService {
  const ColdStoragePdfService._();

  static Future<pw.ThemeData> _loadArabicTheme() async {
    final regularData = await rootBundle.load('assets/font/Cairo-Regular.ttf');
    final boldData = await rootBundle.load('assets/font/Cairo-Bold.ttf');
    return pw.ThemeData.withFont(
      base: pw.Font.ttf(regularData),
      bold: pw.Font.ttf(boldData),
    );
  }

  static Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final bytes = await rootBundle.load(AppAssets.logoBlue);
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  /// دالة موحدة لطباعة أي جدول تقارير (إعدامات، جرد، استلام وصرف، أو حركات يوزرات)
  static Future<void> printCustomTableReport({
    required String reportTitle,
    required String reportSubtitle,
    required List<String> headers,
    required List<List<String>> rows,
    String fileName = 'cold_storage_report.pdf',
    PdfColor headerColor = PdfColors.blueGrey900,
  }) async {
    final theme = await _loadArabicTheme();
    final logo = await _loadLogo();
    final doc = pw.Document();
    final nowStr = intl.DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        header: (_) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey400, width: 1),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    reportTitle,
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '$reportSubtitle | تاريخ الطباعة (بتوقيت مصر): $nowStr',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              if (logo != null) pw.Image(logo, height: 42),
            ],
          ),
        ),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            context: ctx,
            headerDecoration: pw.BoxDecoration(color: headerColor),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 9.5,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.center,
            headers: headers,
            data: rows,
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      name: fileName,
      onLayout: (_) async => doc.save(),
    );
  }
}
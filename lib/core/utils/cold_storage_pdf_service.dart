import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../constants/app_assets.dart';

/// خدمة عامة ومستقلة في Core لطباعة أي تقرير جدولي باللغة العربية بخط Cairo ولوجو الشركة
/// مع فوتر ثابت في أسفل كل صفحة بغض النظر عن كمية المحتوى (قليل أو كثير)
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

  /// دالة موحدة لطباعة أي جدول تقارير مع تثبيت الفوتر أسفل الصفحة دائماً
  static Future<void> printCustomTableReport({
    required String reportTitle,
    required String reportSubtitle,
    required List<String> headers,
    required List<List<String>> rows,
    String fileName = 'cold_storage_report.pdf',
    PdfColor headerColor = PdfColors.blueGrey900,
    Map<String, String>? summaryMetrics,
  }) async {
    final theme = await _loadArabicTheme();
    final logo = await _loadLogo();
    final doc = pw.Document();
    final nowStr = intl.DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4.landscape,
          textDirection: pw.TextDirection.rtl,
          theme: theme,
          // هوامش متوازنة تضمن عدم تداخل المحتوى مع الهيدر أو الفوتر
          margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 24),
        ),
        header: (_) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          margin: const pw.EdgeInsets.only(bottom: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey400, width: 1),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      reportTitle,
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '$reportSubtitle  |  تاريخ الطباعة (بتوقيت مصر): $nowStr',
                      style: const pw.TextStyle(
                        fontSize: 9.5,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              if (logo != null) ...[
                pw.SizedBox(width: 12),
                pw.Image(logo, height: 56, fit: pw.BoxFit.contain),
              ],
            ],
          ),
        ),
        // خاصية footer في MultiPage تثبّت الفوتر في أسفل كل صفحة دائماً
        // سواء كان المحتوى سطراً واحداً أو عشرات الصفحات
        footer: (ctx) => pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(top: 10),
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey400, width: 0.8),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.RichText(
                textDirection: pw.TextDirection.ltr,
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'System ',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.blue900,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.TextSpan(
                      text: 'by ',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.TextSpan(
                      text: 'Alaa Mansour',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.teal700,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Text(
                'ثلاجة المخفض (رمز C) — نظام إدارة المخزون والركات',
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                'صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
            ],
          ),
        ),
        build: (ctx) => [
          if (summaryMetrics != null && summaryMetrics.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              margin: const pw.EdgeInsets.only(bottom: 10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: summaryMetrics.entries
                    .map(
                      (e) => pw.Column(
                        children: [
                          pw.Text(
                            e.key,
                            style: const pw.TextStyle(
                              fontSize: 8.5,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            e.value,
                            style: pw.TextStyle(
                              fontSize: 10.5,
                              fontWeight: pw.FontWeight.bold,
                              color: headerColor,
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          if (rows.isEmpty)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(28),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
              ),
              child: pw.Center(
                child: pw.Text(
                  'لا توجد بيانات مسجلة مطابقة لمعايير هذا التقرير.',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              context: ctx,
              headerDecoration: pw.BoxDecoration(color: headerColor),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9.5,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8.8),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 5,
              ),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
              cellAlignment: pw.Alignment.center,
              headerDirection: pw.TextDirection.rtl,
              tableDirection: pw.TextDirection.rtl,
              headers: headers,
              data: rows,
            ),
        ],
      ),
    );

    await Printing.layoutPdf(name: fileName, onLayout: (_) async => doc.save());
  }
}
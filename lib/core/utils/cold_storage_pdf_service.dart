import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../constants/app_assets.dart';

typedef PdfTableRow = List<String>;
typedef PdfSummaryMetrics = Map<String, String>;

/// محرك طباعة التقارير الموحد لثلاجة المخفض (متجاوب تلقائياً مع Landscape و Portrait،
/// وتوزيع أعمدة ذكي يمنع القصّ أو التداخل، وفوتر مثبّت أسفل كل صفحة دائماً)
class ColdStoragePdfService {
  const ColdStoragePdfService._();

  static const PdfColor _kInkDark = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor _kInkMuted = PdfColor.fromInt(0xFF475569);
  static const PdfColor _kBorderSoft = PdfColor.fromInt(0xFFCBD5E1);
  static const PdfColor _kSurfaceCard = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor _kZebraRow = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor _kDanger = PdfColor.fromInt(0xFFB91C1C);
  static const PdfColor _kWarning = PdfColor.fromInt(0xFFB45309);
  static const PdfColor _kSuccess = PdfColor.fromInt(0xFF15803D);

  static final RegExp _arabicRegex = RegExp(r'[\u0600-\u06FF]');

  static Future<pw.ThemeData> _loadArabicTheme() async {
    final regularData = await rootBundle.load('assets/font/Cairo-Regular.ttf');
    final boldData = await rootBundle.load('assets/font/Cairo-Bold.ttf');
    return pw.ThemeData.withFont(
      base: pw.Font.ttf(regularData),
      bold: pw.Font.ttf(boldData),
    );
  }

  static Future<pw.MemoryImage?> _loadLogo() async {
    const candidates = [
      AppAssets.beytiLogo,
      AppAssets.logoBlue,
      AppAssets.logo,
    ];
    for (final path in candidates) {
      try {
        final bytes = await rootBundle.load(path);
        return pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (e) {
        debugPrint('PDF Logo load failed for $path: $e');
      }
    }
    return null;
  }

  /// دالة موحدة لطباعة أي تقرير جدولي بتصميم احترافي ومتجاوب مع أي مقاس صفحة
  static Future<void> printCustomTableReport({
    required String reportTitle,
    required String reportSubtitle,
    required List<String> headers,
    required List<PdfTableRow> rows,
    String fileName = 'cold_storage_report.pdf',
    PdfColor headerColor = PdfColors.blueGrey900,
    PdfSummaryMetrics? summaryMetrics,
  }) async {
    final theme = await _loadArabicTheme();
    final logo = await _loadLogo();
    final nowStr = intl.DateFormat('yyyy-MM-dd  HH:mm').format(DateTime.now());

    await Printing.layoutPdf(
      name: fileName,
      format: PdfPageFormat.a4.landscape,
      onLayout: (PdfPageFormat format) => _buildPdfBytes(
        format: format,
        theme: theme,
        logo: logo,
        nowStr: nowStr,
        reportTitle: reportTitle,
        reportSubtitle: reportSubtitle,
        headers: headers,
        rows: rows,
        headerColor: headerColor,
        summaryMetrics: summaryMetrics,
      ),
    );
  }

  static Future<Uint8List> _buildPdfBytes({
    required PdfPageFormat format,
    required pw.ThemeData theme,
    required pw.MemoryImage? logo,
    required String nowStr,
    required String reportTitle,
    required String reportSubtitle,
    required List<String> headers,
    required List<PdfTableRow> rows,
    required PdfColor headerColor,
    required PdfSummaryMetrics? summaryMetrics,
  }) async {
    final safeFormat = (format.width.isFinite && format.height.isFinite)
        ? format
        : PdfPageFormat.a4.landscape;

    final isLandscape = safeFormat.width >= safeFormat.height;
    final colCount = headers.length;
    final horizontalMargin = isLandscape ? 18.0 : 14.0;
    final verticalMargin = isLandscape ? 16.0 : 15.0;

    // أحجام خطوط وهـوامش متكيّفة تلقائياً لمنع أي قصّ حتى عند الطباعة الطولية
    final headerFontSize = isLandscape
        ? (colCount >= 9 ? 8.0 : 8.6)
        : (colCount >= 8 ? 6.6 : 7.6);
    final cellFontSize = isLandscape
        ? (colCount >= 9 ? 7.4 : 8.0)
        : (colCount >= 8 ? 6.2 : 7.2);
    final cellHPad = isLandscape ? 4.2 : 2.8;
    final cellVPad = isLandscape ? 3.4 : 3.2;

    final columnWidths = _buildSmartColumnWidths(headers);

    final doc = pw.Document(
      title: reportTitle,
      author: 'Alaa Mansour — Beyti Cold Store',
      creator: 'Discount Cold Store Management System',
    );

    doc.addPage(
      pw.MultiPage(
        maxPages: 200,
        pageTheme: pw.PageTheme(
          pageFormat: safeFormat,
          textDirection: pw.TextDirection.rtl,
          theme: theme,
          margin: pw.EdgeInsets.symmetric(
            horizontal: horizontalMargin,
            vertical: verticalMargin,
          ),
        ),
        header: (ctx) => _buildPageHeader(
          title: reportTitle,
          subtitle: reportSubtitle,
          nowStr: nowStr,
          logo: logo,
          accentColor: headerColor,
          isLandscape: isLandscape,
          isFirstPage: ctx.pageNumber == 1,
        ),
        footer: (ctx) => _buildPageFooter(
          ctx: ctx,
          accentColor: headerColor,
          isLandscape: isLandscape,
        ),
        build: (_) => [
          if (summaryMetrics != null && summaryMetrics.isNotEmpty) ...[
            _buildSummaryStrip(
              summaryMetrics: summaryMetrics,
              accentColor: headerColor,
              isLandscape: isLandscape,
            ),
            pw.SizedBox(height: 9),
          ],
          if (rows.isEmpty)
            _buildEmptyBox()
          else
            _buildProfessionalTable(
              headers: headers,
              rows: rows,
              columnWidths: columnWidths,
              headerColor: headerColor,
              headerFontSize: headerFontSize,
              cellFontSize: cellFontSize,
              cellHPad: cellHPad,
              cellVPad: cellVPad,
            ),
        ],
      ),
    );

    return doc.save();
  }

  /// ترويسة التقرير المؤسسية (تتكرر بشكل أنيق ومختصر في الصفحات التالية)
  static pw.Widget _buildPageHeader({
    required String title,
    required String subtitle,
    required String nowStr,
    required pw.MemoryImage? logo,
    required PdfColor accentColor,
    required bool isLandscape,
    required bool isFirstPage,
  }) {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: isFirstPage ? 9 : 7),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            height: 3.5,
            decoration: pw.BoxDecoration(
              color: accentColor,
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 7),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _kBorderSoft, width: 0.9),
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        title,
                        style: pw.TextStyle(
                          fontSize: isLandscape ? 13.5 : 11.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _kInkDark,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        subtitle,
                        style: pw.TextStyle(
                          fontSize: isLandscape ? 8.6 : 7.6,
                          color: _kInkMuted,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Row(
                        children: [
                          pw.Text(
                            'تاريخ الطباعة (توقيت ام الدنيا): ',
                            style: pw.TextStyle(
                              fontSize: isLandscape ? 7.8 : 6.8,
                              fontWeight: pw.FontWeight.bold,
                              color: _kInkMuted,
                            ),
                          ),
                          pw.Text(
                            nowStr,
                            textDirection: pw.TextDirection.ltr,
                            style: pw.TextStyle(
                              fontSize: isLandscape ? 7.8 : 6.8,
                              color: accentColor,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (logo != null) ...[
                  pw.SizedBox(width: 10),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: _kBorderSoft, width: 0.6),
                    ),
                    child: pw.Image(
                      logo,
                      height: isLandscape ? 42 : 34,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// شريط ملخص المؤشرات (KPIs) بتصميم بطاقات حديثة في الصفحة الأولى
  static pw.Widget _buildSummaryStrip({
    required PdfSummaryMetrics summaryMetrics,
    required PdfColor accentColor,
    required bool isLandscape,
  }) {
    final entries = summaryMetrics.entries.toList();
    return pw.Row(
      children: List.generate(entries.length, (i) {
        final e = entries[i];
        return pw.Expanded(
          child: pw.Container(
            margin: pw.EdgeInsets.only(left: i == entries.length - 1 ? 0 : 6),
            padding: pw.EdgeInsets.symmetric(
              horizontal: isLandscape ? 8 : 5,
              vertical: isLandscape ? 5.5 : 4.5,
            ),
            decoration: pw.BoxDecoration(
              color: _kSurfaceCard,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: _kBorderSoft, width: 0.7),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  e.key,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: isLandscape ? 7.6 : 6.6,
                    color: _kInkMuted,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2.5),
                pw.Text(
                  e.value,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: isLandscape ? 9.2 : 7.8,
                    fontWeight: pw.FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  /// جدول احترافي مخصص بتوزيع أعمدة ذكي وتلوين دلالي وتكرار ترويسة تلقائي
  static pw.Widget _buildProfessionalTable({
    required List<String> headers,
    required List<PdfTableRow> rows,
    required Map<int, pw.TableColumnWidth> columnWidths,
    required PdfColor headerColor,
    required double headerFontSize,
    required double cellFontSize,
    required double cellHPad,
    required double cellVPad,
  }) {
    final tableRows = <pw.TableRow>[
      pw.TableRow(
        repeat: true,
        decoration: pw.BoxDecoration(color: headerColor),
        children: List.generate(headers.length, (colIdx) {
          return pw.Container(
            padding: pw.EdgeInsets.symmetric(
              horizontal: cellHPad,
              vertical: cellVPad + 1.5,
            ),
            alignment: pw.Alignment.center,
            child: pw.Text(
              headers[colIdx],
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: headerFontSize,
              ),
            ),
          );
        }),
      ),
      ...List.generate(rows.length, (rowIdx) {
        final row = rows[rowIdx];
        final isOdd = rowIdx.isOdd;

        return pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isOdd ? _kZebraRow : PdfColors.white,
          ),
          children: List.generate(headers.length, (colIdx) {
            final rawValue = colIdx < row.length ? row[colIdx] : '—';
            final value = rawValue.trim().isEmpty ? '—' : rawValue.trim();
            final headerName = headers[colIdx];

            final isPureLtr = _isPureLtrCell(value);
            final isRightAlignedText = _isWideTextColumn(headerName);
            final semanticColor = _semanticTextColor(headerName, value);
            final isBoldCell = _isEmphasizedColumn(headerName, value);

            return pw.Container(
              padding: pw.EdgeInsets.symmetric(
                horizontal: cellHPad,
                vertical: cellVPad,
              ),
              alignment: isRightAlignedText
                  ? pw.Alignment.centerRight
                  : pw.Alignment.center,
              child: pw.Text(
                value,
                textDirection: isPureLtr
                    ? pw.TextDirection.ltr
                    : pw.TextDirection.rtl,
                textAlign: isRightAlignedText
                    ? pw.TextAlign.right
                    : pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: cellFontSize,
                  lineSpacing: 1.35,
                  fontWeight: isBoldCell
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                  color: semanticColor ?? _kInkDark,
                ),
              ),
            );
          }),
        );
      }),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: _kBorderSoft, width: 0.55),
      columnWidths: columnWidths,
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: tableRows,
    );
  }

  /// فوتر ثابت في أسفل كل صفحة (يعمل بدقة على Landscape و Portrait)
  static pw.Widget _buildPageFooter({
    required pw.Context ctx,
    required PdfColor accentColor,
    required bool isLandscape,
  }) {
    final fontSize = isLandscape ? 8.0 : 7.0;
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _kBorderSoft, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: pw.BoxDecoration(
              color: _kSurfaceCard,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: _kBorderSoft, width: 0.5),
            ),
            child: pw.Text(
              'صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: pw.FontWeight.bold,
                color: accentColor,
              ),
            ),
          ),
          pw.Text(
            'مخازن المنتج التام - ثلاجة المخفض',
            style: pw.TextStyle(fontSize: fontSize, color: _kInkMuted),
          ),
          pw.RichText(
            textDirection: pw.TextDirection.ltr,
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: 'System ',
                  style: pw.TextStyle(
                    fontSize: fontSize,
                    color: PdfColors.blue900,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.TextSpan(
                  text: 'by ',
                  style: pw.TextStyle(fontSize: fontSize, color: _kInkMuted),
                ),
                pw.TextSpan(
                  text: 'Alaa Mansour',
                  style: pw.TextStyle(
                    fontSize: fontSize,
                    color: PdfColors.teal700,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildEmptyBox() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(28),
      decoration: pw.BoxDecoration(
        color: _kSurfaceCard,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _kBorderSoft, width: 0.8),
      ),
      child: pw.Center(
        child: pw.Text(
          'لا توجد بيانات مسجلة مطابقة لمعايير هذا التقرير.',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: _kInkMuted,
          ),
        ),
      ),
    );
  }

  /// توزيع ذكي لعروض الأعمدة حسب دلالة كل عمود لضمان عدم انضغاط أي عمود أو تكسّر الأكواد
  static Map<int, pw.TableColumnWidth> _buildSmartColumnWidths(
    List<String> headers,
  ) {
    final map = <int, pw.TableColumnWidth>{};
    for (var i = 0; i < headers.length; i++) {
      map[i] = pw.FlexColumnWidth(_weightForHeader(headers[i]));
    }
    return map;
  }

  static double _weightForHeader(String rawHeader) {
    final h = rawHeader.trim();
    if (h.contains('الأصناف والكميات')) {
      return 2.90;
    }
    if (h == 'الصنف' || h == 'اسم الصنف') {
      return 2.20;
    }
    if (h.contains('ملاحظات') || h.contains('سبب')) {
      return 1.85;
    }
    if (h.contains('أكواد البالتات')) {
      return 1.75;
    }
    if (h.contains('البالتة') || h.contains('المستند')) {
      return 1.65;
    }
    if (h.contains('التاريخ والوقت') ||
        (h.contains('تاريخ') && h.contains('الوقت')) ||
        h.contains('تاريخ الإعدام') ||
        h.contains('تاريخ الإنشاء')) {
      return 1.45;
    }
    if (h.contains('الموقع') || h.contains('موقع')) {
      return 1.30;
    }
    if (h.contains('الحالة')) {
      return 1.25;
    }
    if (h.contains('إجمالي') || h.contains('الرصيد') || h.contains('الكمية')) {
      return 1.15;
    }
    if (h.contains('نوع')) {
      return 1.20;
    }
    if (h.contains('تاريخ') || h.contains('الانتهاء') || h.contains('الإنتاج')) {
      return 1.10;
    }
    if (h.contains('المستلم') ||
        h.contains('المنفذ') ||
        h.contains('المنشئ') ||
        h.contains('المعتمد') ||
        h.contains('بواسطة') ||
        h.contains('المستخدم')) {
      return 1.10;
    }
    if (h.contains('جهة') || h.contains('الجهة')) {
      return 0.95;
    }
    if (h.contains('الأيام') ||
        h.contains('عدد') ||
        h == 'البنود' ||
        h == 'البالتات') {
      return 0.78;
    }
    return 1.10;
  }

  static bool _isWideTextColumn(String header) {
    return header.contains('الأصناف والكميات') ||
        header == 'الصنف' ||
        header == 'اسم الصنف' ||
        header.contains('ملاحظات') ||
        header.contains('سبب');
  }

  static bool _isPureLtrCell(String text) {
    if (text == '—' || text == '-') {
      return false;
    }
    return !_arabicRegex.hasMatch(text);
  }

  static PdfColor? _semanticTextColor(String header, String value) {
    if (header.contains('الحالة')) {
      if (value.contains('منتهي')) {
        return _kDanger;
      }
      if (value.contains('معكوس') || value.contains('مستحق')) {
        return _kWarning;
      }
      if (value.contains('مكتمل') || value.contains('سليم')) {
        return _kSuccess;
      }
    }
    if (header.contains('المعدمة')) {
      return _kDanger;
    }
    return null;
  }

  static bool _isEmphasizedColumn(String header, String value) {
    return header == 'الصنف' ||
        header == 'اسم الصنف' ||
        header.contains('الكمية') ||
        header.contains('إجمالي') ||
        header.contains('الرصيد') ||
        header.contains('رقم المستند') ||
        value.contains('منتهي');
  }
}
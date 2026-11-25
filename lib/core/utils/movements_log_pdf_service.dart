import 'package:pdf/pdf.dart';

import 'cold_storage_pdf_service.dart';

/// خدمة طباعة سجل الحركات المخزنية الشامل بترتيب أعمدة مطابق لباقي تقارير النظام.
class MovementsLogPdfService {
  MovementsLogPdfService._();

  static Future<void> printReport({
    required List<List<String>> rows,
    int? totalCount,
    int? todayCount,
  }) {
    final total = totalCount ?? rows.length;
    final subtitle = total > rows.length
        ? 'إجمالي الحركات المطابقة: $total (المطبوع: ${rows.length} حركة)'
        : 'إجمالي الحركات المطابقة: $total حركة';

    return ColdStoragePdfService.printCustomTableReport(
      reportTitle: 'سجل الحركات المخزنية الشامل - ثلاجة المخفض',
      reportSubtitle: subtitle,
      headers: const [
        'ملاحظات',
        'الجهة',
        'اسم الصنف',
        'الكمية',
        'الموقع',
        'نوع الحركة',
        'المنفذ',
        'التاريخ والوقت',
      ],
      rows: rows,
      fileName: 'comprehensive_movements_log.pdf',
      headerColor: PdfColors.indigo900,
      summaryMetrics: {
        'إجمالي الحركات': '$total',
        if (todayCount != null) 'حركات اليوم': '$todayCount',
      },
    );
  }
}
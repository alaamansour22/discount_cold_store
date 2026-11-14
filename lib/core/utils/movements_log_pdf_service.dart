import 'package:pdf/pdf.dart';

import 'cold_storage_pdf_service.dart';

/// PDF export for the comprehensive warehouse movements log.
/// Kept in core/utils so the report layout can be maintained independently
/// from the movements-log screen.
class MovementsLogPdfService {
  MovementsLogPdfService._();

  static Future<void> printReport({required List<List<String>> rows}) {
    return ColdStoragePdfService.printCustomTableReport(
      reportTitle: 'سجل الحركات المخزنية الشامل — ثلاجة مخفض (رمز C)',
      reportSubtitle:
          'إجمالي الحركات المطابقة: ${rows.length} | تاريخ الطباعة (توقيت مصر)',
      headers: const [
        'التوقيت',
        'المستخدم',
        'نوع الحركة',
        'موقع البنة',
        'الكمية',
        'اسم الصنف',
        'الجهة',
        'ملاحظات',
      ],
      rows: rows,
      fileName: 'comprehensive_movements_log.pdf',
      headerColor: PdfColors.indigo900,
    );
  }
}

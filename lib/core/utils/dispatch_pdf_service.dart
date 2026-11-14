import 'package:pdf/pdf.dart';

import 'cold_storage_pdf_service.dart';

/// خدمة طباعة سجل مستندات الصرف، مع إبقاء تفاصيل تنسيق PDF داخل Core.
class DispatchPdfService {
  const DispatchPdfService._();

  static Future<void> printDispatchLog({
    required List<List<String>> rows,
    required int documentCount,
    required int itemCount,
  }) {
    return ColdStoragePdfService.printCustomTableReport(
      reportTitle: 'سجل مستندات الصرف — ثلاجة المخفض',
      reportSubtitle:
          'عدد المستندات: $documentCount | عدد بنود الصرف: $itemCount',
      headers: const [
        'رقم المستند',
        'التاريخ',
        'الحالة',
        'اسم الصنف',
        'الكمية',
        'البالتة',
        'الموقع',
        'سبب العكس',
      ],
      rows: rows,
      fileName: 'dispatch_documents_log.pdf',
      headerColor: PdfColors.indigo900,
    );
  }
}

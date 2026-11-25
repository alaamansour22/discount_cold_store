import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdf/pdf.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/cold_storage_pdf_service.dart';
import '../../../../core/widgets/app_pagination_bar.dart';
import '../../../../core/widgets/app_pro_data_table.dart';
import '../../domain/entities/report_entities.dart';
import '../cubit/reports_cubit.dart';

/// نافذة معاينة تقرير بترقيم صفحات وبحث مباشر داخل PostgreSQL + طباعة PDF كاملة
class ReportPreviewDialog extends StatefulWidget {
  final ReportsCubit reportsCubit;
  final ReportQueryParams initialParams;
  final ReportPageEntity initialData;
  final String title;
  final String subtitle;
  final String fileName;
  final PdfColor headerColor;
  final Color accentColor;

  const ReportPreviewDialog({
    super.key,
    required this.reportsCubit,
    required this.initialParams,
    required this.initialData,
    required this.title,
    required this.subtitle,
    required this.fileName,
    required this.headerColor,
    required this.accentColor,
  });

  @override
  State<ReportPreviewDialog> createState() => _ReportPreviewDialogState();
}

class _ReportPreviewDialogState extends State<ReportPreviewDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  late ReportQueryParams _params;
  late ReportPageEntity _data;
  bool _loading = false;
  bool _printing = false;
  String? _error;
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _params = widget.initialParams;
    _data = widget.initialData;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load(ReportQueryParams nextParams) async {
    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _error = null;
      _params = nextParams;
    });

    try {
      final result = await widget.reportsCubit.fetchReportPage(nextParams);
      if (!mounted || seq != _requestSeq) {
        return;
      }

      if (nextParams.page > result.page.totalPages &&
          result.page.totalPages >= 1) {
        await _load(nextParams.copyWith(page: result.page.totalPages));
        return;
      }

      setState(() {
        _loading = false;
        _data = result;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) {
        return;
      }
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      _load(_params.copyWith(search: value.trim(), page: 1));
    });
  }

  Future<void> _printFullReport() async {
    if (_printing) {
      return;
    }
    setState(() => _printing = true);
    try {
      final fullData = await widget.reportsCubit.fetchReportForPrint(_params);
      if (!mounted) {
        return;
      }
      final suffix = _params.search.trim().isEmpty
          ? ''
          : ' | بحث: ${_params.search.trim()}';

      await ColdStoragePdfService.printCustomTableReport(
        reportTitle: widget.title,
        reportSubtitle:
            '${widget.subtitle}$suffix | عدد السجلات: ${fullData.page.totalCount}',
        headers: fullData.headers,
        rows: fullData.page.items,
        fileName: widget.fileName,
        headerColor: widget.headerColor,
        summaryMetrics: fullData.summaryMetrics,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('تعذر تصدير ملف PDF: $e'),
            backgroundColor: AppColors.dangerRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _printing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 640;
    final headers = _data.headers.reversed.toList();
    final previewRows = _data.page.items
        .map((row) => row.reversed.toList())
        .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: EdgeInsets.all(isNarrow ? 10 : 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160, maxHeight: 780),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // رأس نافذة المعاينة
              Container(
                padding: EdgeInsets.fromLTRB(
                  isNarrow ? 14 : 20,
                  14,
                  isNarrow ? 14 : 20,
                  14,
                ),
                decoration: BoxDecoration(
                  color: widget.accentColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.fileText,
                      color: Colors.white,
                      size: 21,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isNarrow ? 14.5 : 16.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(LucideIcons.x, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // مؤشرات الملخص من السيرفر + البحث داخل التقرير
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isNarrow ? 12 : 20,
                  12,
                  isNarrow ? 12 : 20,
                  8,
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: _data.summaryMetrics.entries
                          .map(
                            (e) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: widget.accentColor.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: widget.accentColor.withValues(
                                    alpha: 0.25,
                                  ),
                                ),
                              ),
                              child: Text(
                                '${e.key}: ${e.value}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11.5,
                                  color: widget.accentColor,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    SizedBox(
                      width: isNarrow ? double.infinity : 270,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _searchCtrl,
                        builder: (_, val, _) => TextField(
                          controller: _searchCtrl,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'بحث داخل التقرير...',
                            prefixIcon: const Icon(
                              LucideIcons.search,
                              size: 17,
                            ),
                            suffixIcon: val.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(LucideIcons.x, size: 15),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      _onSearchChanged('');
                                    },
                                  ),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_loading || _printing)
                const LinearProgressIndicator(minHeight: 2.5),

              // جدول البيانات الاحترافي
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 12 : 20,
                    vertical: 6,
                  ),
                  child: _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.circleAlert,
                                size: 38,
                                color: AppColors.dangerRed,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.dangerRed,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () => _load(_params),
                                icon: const Icon(
                                  LucideIcons.refreshCw,
                                  size: 15,
                                ),
                                label: const Text('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        )
                      : previewRows.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.circleAlert,
                                size: 40,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(height: 10),
                              Text(
                                'لا توجد بيانات مطابقة في هذا التقرير.',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : AppProDataTable<ReportCellsRow>(
                          items: previewRows,
                          expandHeight: true,
                          darkHeader: true,
                          minTableWidth: (headers.length * 135.0).clamp(
                            840.0,
                            1320.0,
                          ),
                          columns: List.generate(
                            headers.length,
                            (colIdx) => AppProTableColumn<ReportCellsRow>(
                              label: headers[colIdx],
                              flex: colIdx == 0 || colIdx == 1 ? 2 : 1,
                              cellBuilder: (_, row, _) => Text(
                                colIdx < row.length ? row[colIdx] : '—',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                ),
              ),

              // شريط ترقيم الصفحات (من PostgreSQL)
              if (_data.page.totalCount > 0)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isNarrow ? 12 : 20,
                    2,
                    isNarrow ? 12 : 20,
                    6,
                  ),
                  child: AppPaginationBar(
                    pageData: _data.page,
                    isLoading: _loading,
                    pageSizeOptions: const [15, 25, 50],
                    onPageChanged: (p) => _load(_params.copyWith(page: p)),
                    onPageSizeChanged: (s) =>
                        _load(_params.copyWith(page: 1, pageSize: s)),
                  ),
                ),

              // التذييل وأزرار الإغلاق والطباعة الكاملة
              Container(
                padding: EdgeInsets.fromLTRB(
                  isNarrow ? 12 : 20,
                  10,
                  isNarrow ? 12 : 20,
                  12,
                ),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.borderLight)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'إجمالي السجلات: ${_data.page.totalCount}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _printing
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('إغلاق'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: (_printing || _data.page.totalCount == 0)
                          ? null
                          : _printFullReport,
                      icon: _printing
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(LucideIcons.printer, size: 16),
                      label: Text(_printing ? 'جاري التجهيز...' : 'طباعة PDF'),
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.accentColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
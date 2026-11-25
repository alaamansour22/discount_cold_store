import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdf/pdf.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/cold_storage_pdf_service.dart';
import '../../../../core/widgets/app_pagination_bar.dart';
import '../../../../core/widgets/responsive_shimmer.dart';
import '../../domain/entities/dispatch_entities.dart';
import '../cubit/dispatch_cubit.dart';
import '../cubit/dispatch_state.dart';

const _kDispBorder = Color(0xFFE3E8EF);
const _kDispMuted = Color(0xFF64748B);

String _fmtDispQty(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

String _fmtDispDate(DateTime d) => intl.DateFormat('yyyy-MM-dd').format(d);

String _fmtDispDateTime(DateTime d) =>
    intl.DateFormat('yyyy-MM-dd  HH:mm').format(d);

String _unitAr(String dbUnit) {
  switch (dbUnit) {
    case 'shrink':
      return 'شرنك';
    case 'gallon':
      return 'جالون';
    default:
      return 'كرتونة';
  }
}

/// شاشة سجل مستندات الصرف (البحث والفلاتر والباجينيشن والعكس الذكي داخل PostgreSQL)
class DispatchHistoryView extends StatefulWidget {
  const DispatchHistoryView({super.key});

  @override
  State<DispatchHistoryView> createState() => _DispatchHistoryViewState();
}

class _DispatchHistoryViewState extends State<DispatchHistoryView> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  bool _isExportingPdf = false;
  bool _checkingReversal = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DispatchCubit>().ensureDocumentsLoaded();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      final cubit = context.read<DispatchCubit>();
      cubit.updateDocumentsFilter(
        cubit.state.docsFilter.copyWith(search: value.trim()),
      );
    });
  }

  void _clearAllFilters(DispatchCubit cubit) {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    cubit.clearDocumentsFilters();
  }

  Future<void> _pickDate(
    BuildContext context,
    DispatchCubit cubit,
    DispatchDocumentsFilter filter,
    bool isFrom,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? filter.fromDate : filter.toDate) ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      locale: const Locale('ar', 'EG'),
      helpText: isFrom ? 'اختر تاريخ البداية' : 'اختر تاريخ النهاية',
    );
    if (picked == null || !mounted) {
      return;
    }

    var nextFrom = filter.fromDate;
    var nextTo = filter.toDate;
    if (isFrom) {
      nextFrom = picked;
      if (nextTo != null && nextFrom.isAfter(nextTo)) {
        nextTo = picked;
      }
    } else {
      nextTo = picked;
      if (nextFrom != null && nextTo.isBefore(nextFrom)) {
        nextFrom = picked;
      }
    }

    await cubit.updateDocumentsFilter(
      filter.copyWith(fromDate: nextFrom, toDate: nextTo),
    );
  }

  Future<void> _exportPdf(DispatchCubit cubit) async {
    if (_isExportingPdf) {
      return;
    }
    setState(() => _isExportingPdf = true);

    try {
      final exported = await cubit.fetchDocumentsForExport();
      final docs = exported.page.items;
      final summary = exported.summary;

      final rows = docs
          .map(
            (d) => <String>[
              d.isReversed ? (d.reversalReason ?? '—') : '—',
              d.isReversed ? 'معكوس' : 'مكتمل',
              d.totalsByUnitSummary,
              '${d.itemLineCount}',
              '${d.palletCount}',
              d.palletReferences.isEmpty ? '—' : d.palletReferences.join('، '),
              d.createdByName,
              _fmtDispDateTime(d.createdAt),
              d.number,
            ],
          )
          .toList();

      await ColdStoragePdfService.printCustomTableReport(
        reportTitle: 'سجل مستندات الصرف — ثلاجة المخفض',
        reportSubtitle: 'إجمالي المستندات المطابقة: ${summary.totalDocuments}',
        headers: const [
          'سبب العكس',
          'الحالة',
          'إجمالي الكميات',
          'البنود',
          'البالتات',
          'أكواد البالتات',
          'المنشئ',
          'التاريخ والوقت',
          'رقم المستند',
        ],
        rows: rows,
        fileName: 'dispatch_documents_log.pdf',
        headerColor: PdfColors.indigo900,
        summaryMetrics: {
          'إجمالي المستندات': '${summary.totalDocuments}',
          'مكتملة': '${summary.completedCount}',
          'معكوسة': '${summary.reversedCount}',
          'صافي الوحدات': _fmtDispQty(summary.netDispatchedQuantity),
        },
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
        setState(() => _isExportingPdf = false);
      }
    }
  }

  Future<void> _handleReverseDocument(
    DispatchCubit cubit,
    DispatchDocumentEntity doc,
  ) async {
    if (_checkingReversal) {
      return;
    }
    setState(() => _checkingReversal = true);

    final readiness = await cubit.checkReversalReadiness(doc.id);
    if (!mounted) {
      return;
    }
    setState(() => _checkingReversal = false);

    if (readiness == null) {
      return;
    }

    if (!readiness.canReverse) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('ليس لديك صلاحية التراجع عن مستندات الصرف.'),
            backgroundColor: AppColors.dangerRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    if (readiness.requiresAlternativeSlots &&
        readiness.availableEmptySlots.length <
            readiness.palletsNeedingAlternativeSlot.length) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'لا توجد مواقع فارغة كافية لإعادة تسكين البالتات المغلقة في هذا المستند.',
            ),
            backgroundColor: AppColors.dangerRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    final payload = await showDialog<_ReversalSubmission>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SmartReversalDialog(readiness: readiness),
    );

    if (payload == null || !mounted) {
      return;
    }

    await cubit.reverse(
      documentId: doc.id,
      reason: payload.reason,
      alternativeSlots: payload.alternativeSlots,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DispatchCubit, DispatchState>(
      buildWhen: (prev, curr) =>
          prev.isDocsLoading != curr.isDocsLoading ||
          prev.docsInitialized != curr.docsInitialized ||
          prev.docsData != curr.docsData ||
          prev.docsFilter != curr.docsFilter ||
          prev.details != curr.details ||
          prev.loadingDetailIds != curr.loadingDetailIds ||
          prev.submitting != curr.submitting,
      builder: (context, state) {
        if (!state.docsInitialized && state.isDocsLoading) {
          return const ResponsiveColdStorageShimmer(
            mode: ShimmerLayoutMode.tableList,
            itemCountOverride: 5,
          );
        }

        final cubit = context.read<DispatchCubit>();
        final pageData = state.docsData.page;
        final summary = state.docsData.summary;
        final filter = state.docsFilter;
        final docs = pageData.items;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 900;
              final pad = desktop ? 24.0 : 12.0;

              return RefreshIndicator(
                onRefresh: () => cubit.loadDocuments(),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        pad,
                        desktop ? 18 : 10,
                        pad,
                        10,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (desktop) ...[
                              _buildDesktopHeader(cubit, summary),
                              const SizedBox(height: 12),
                            ],
                            _buildFiltersCard(context, cubit, filter, desktop),
                            if (!desktop) ...[
                              const SizedBox(height: 10),
                              _buildMobileSummaryRow(cubit, summary),
                            ],
                            if (state.isDocsLoading || _checkingReversal) ...[
                              const SizedBox(height: 8),
                              const LinearProgressIndicator(minHeight: 2.5),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (docs.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(cubit, filter),
                      )
                    else ...[
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(pad, 0, pad, 10),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, index) => Padding(
                              padding: EdgeInsets.only(
                                bottom: index == docs.length - 1 ? 0 : 10,
                              ),
                              child: _DispatchDocumentCard(
                                doc: docs[index],
                                lines: state.details[docs[index].id],
                                isLoadingLines: state.loadingDetailIds.contains(
                                  docs[index].id,
                                ),
                                canReverse:
                                    !docs[index].isReversed &&
                                    summary.currentUserCanReverse &&
                                    !state.submitting &&
                                    !_checkingReversal,
                                desktop: desktop,
                                onExpand: () =>
                                    cubit.loadDetails(docs[index].id),
                                onReverse: () => _handleReverseDocument(
                                  cubit,
                                  docs[index],
                                ),
                              ),
                            ),
                            childCount: docs.length,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(pad, 0, pad, 20),
                        sliver: SliverToBoxAdapter(
                          child: AppPaginationBar(
                            pageData: pageData,
                            isLoading: state.isDocsLoading,
                            pageSizeOptions: const [15, 20, 50],
                            onPageChanged: cubit.goToDocumentsPage,
                            onPageSizeChanged: cubit.changeDocumentsPageSize,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMobileSummaryRow(
    DispatchCubit cubit,
    DispatchDocumentsSummaryEntity summary,
  ) {
    return Row(
      children: [
        _pill(
          '${summary.totalDocuments} مستند',
          AppColors.zoneC2Blue,
          icon: LucideIcons.clipboardList,
        ),
        const SizedBox(width: 6),
        if (summary.reversedCount > 0)
          _pill('${summary.reversedCount} معكوس', AppColors.warningAmber),
        const Spacer(),
        _pdfButton(cubit, summary.totalDocuments, desktop: false),
      ],
    );
  }

  Widget _buildDesktopHeader(
    DispatchCubit cubit,
    DispatchDocumentsSummaryEntity summary,
  ) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سجل مستندات الصرف',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryNavy,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'متابعة أذونات الصرف وتفاصيل الأصناف وعكس المستندات للمصرح لهم',
                style: TextStyle(fontSize: 12, color: _kDispMuted),
              ),
            ],
          ),
        ),
        _pill('${summary.completedCount} مكتمل', AppColors.successGreen),
        const SizedBox(width: 6),
        _pill('${summary.reversedCount} معكوس', AppColors.warningAmber),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'تحديث',
          onPressed: () => cubit.loadDocuments(),
          icon: const Icon(LucideIcons.refreshCw, size: 16),
        ),
        const SizedBox(width: 8),
        _pdfButton(cubit, summary.totalDocuments, desktop: true),
      ],
    );
  }

  Widget _pdfButton(
    DispatchCubit cubit,
    int totalDocs, {
    required bool desktop,
  }) {
    return FilledButton.icon(
      onPressed: (totalDocs == 0 || _isExportingPdf)
          ? null
          : () => _exportPdf(cubit),
      icon: _isExportingPdf
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(LucideIcons.fileDown, size: 15),
      label: Text(
        _isExportingPdf ? 'تجهيز...' : (desktop ? 'تصدير PDF' : 'PDF'),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
        visualDensity: desktop ? VisualDensity.standard : VisualDensity.compact,
        padding: EdgeInsets.symmetric(
          horizontal: desktop ? 14 : 11,
          vertical: desktop ? 10 : 8,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _pill(String label, Color color, {IconData? icon}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );

  Widget _buildFiltersCard(
    BuildContext context,
    DispatchCubit cubit,
    DispatchDocumentsFilter filter,
    bool desktop,
  ) {
    final searchField = ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchCtrl,
      builder: (_, val, _) => TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'بحث برقم المستند، الصنف، البالتة أو المنشئ',
          hintStyle: const TextStyle(fontSize: 12.5),
          prefixIcon: const Icon(LucideIcons.search, size: 17),
          suffixIcon: val.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearchChanged('');
                  },
                  icon: const Icon(LucideIcons.x, size: 16),
                ),
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: _kDispBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: _kDispBorder),
          ),
        ),
      ),
    );

    Widget statusChip(String label, String? value) {
      final selected = filter.status == value;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        selectedColor: AppColors.primaryNavy,
        backgroundColor: const Color(0xFFF8FAFC),
        side: BorderSide(
          color: selected ? AppColors.primaryNavy : _kDispBorder,
        ),
        labelStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: selected ? Colors.white : AppColors.primaryNavy,
        ),
        onSelected: (_) => cubit.updateDocumentsFilter(
          filter.copyWith(status: value, clearStatus: value == null),
        ),
      );
    }

    Widget dateBtn({
      required String label,
      required IconData icon,
      required bool active,
      required VoidCallback onTap,
    }) => OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 14,
        color: active ? AppColors.zoneC2Blue : _kDispMuted,
      ),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          color: active ? AppColors.zoneC2Blue : AppColors.primaryNavy,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: active
            ? AppColors.zoneC2Blue.withValues(alpha: 0.06)
            : const Color(0xFFF8FAFC),
        side: BorderSide(color: active ? AppColors.zoneC2Blue : _kDispBorder),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    return Container(
      padding: EdgeInsets.all(desktop ? 14 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kDispBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (desktop)
            Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 10),
                statusChip('الكل', null),
                const SizedBox(width: 6),
                statusChip('مكتمل', 'completed'),
                const SizedBox(width: 6),
                statusChip('معكوس', 'reversed'),
                const SizedBox(width: 10),
                dateBtn(
                  label: filter.fromDate == null
                      ? 'من تاريخ'
                      : _fmtDispDate(filter.fromDate!),
                  icon: LucideIcons.calendarDays,
                  active: filter.fromDate != null,
                  onTap: () => _pickDate(context, cubit, filter, true),
                ),
                const SizedBox(width: 8),
                dateBtn(
                  label: filter.toDate == null
                      ? 'إلى تاريخ'
                      : _fmtDispDate(filter.toDate!),
                  icon: LucideIcons.calendarCheck,
                  active: filter.toDate != null,
                  onTap: () => _pickDate(context, cubit, filter, false),
                ),
                if (filter.hasActiveFilters) ...[
                  const SizedBox(width: 6),
                  TextButton.icon(
                    onPressed: () => _clearAllFilters(cubit),
                    icon: const Icon(LucideIcons.rotateCcw, size: 14),
                    label: const Text('مسح', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            )
          else ...[
            searchField,
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: dateBtn(
                    label: filter.fromDate == null
                        ? 'من تاريخ'
                        : _fmtDispDate(filter.fromDate!),
                    icon: LucideIcons.calendarDays,
                    active: filter.fromDate != null,
                    onTap: () => _pickDate(context, cubit, filter, true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: dateBtn(
                    label: filter.toDate == null
                        ? 'إلى تاريخ'
                        : _fmtDispDate(filter.toDate!),
                    icon: LucideIcons.calendarCheck,
                    active: filter.toDate != null,
                    onTap: () => _pickDate(context, cubit, filter, false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                statusChip('الكل', null),
                const SizedBox(width: 6),
                statusChip('مكتمل', 'completed'),
                const SizedBox(width: 6),
                statusChip('معكوس', 'reversed'),
                const Spacer(),
                if (filter.hasActiveFilters)
                  IconButton.outlined(
                    tooltip: 'مسح الفلاتر',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _clearAllFilters(cubit),
                    icon: const Icon(LucideIcons.rotateCcw, size: 15),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    DispatchCubit cubit,
    DispatchDocumentsFilter filter,
  ) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF0F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.clipboardList,
              size: 26,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'لا توجد مستندات صرف مطابقة',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'ستظهر هنا أذونات الصرف التي يتم إنشاؤها مع تفاصيل الأصناف وحالة العكس.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _kDispMuted),
          ),
          if (filter.hasActiveFilters) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _clearAllFilters(cubit),
              icon: const Icon(LucideIcons.rotateCcw, size: 15),
              label: const Text('مسح الفلاتر'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _DispatchDocumentCard extends StatelessWidget {
  final DispatchDocumentEntity doc;
  final List<DispatchDocumentLineEntity>? lines;
  final bool isLoadingLines;
  final bool canReverse;
  final bool desktop;
  final VoidCallback onExpand;
  final VoidCallback onReverse;

  const _DispatchDocumentCard({
    required this.doc,
    required this.lines,
    required this.isLoadingLines,
    required this.canReverse,
    required this.desktop,
    required this.onExpand,
    required this.onReverse,
  });

  @override
  Widget build(BuildContext context) {
    final reversed = doc.isReversed;
    final statusColor = reversed
        ? AppColors.warningAmber
        : AppColors.successGreen;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: reversed
              ? AppColors.warningAmber.withValues(alpha: 0.35)
              : _kDispBorder,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(
            horizontal: desktop ? 18 : 13,
            vertical: 6,
          ),
          childrenPadding: EdgeInsets.fromLTRB(
            desktop ? 18 : 13,
            0,
            desktop ? 18 : 13,
            14,
          ),
          onExpansionChanged: (open) {
            if (open && lines == null && !isLoadingLines) {
              onExpand();
            }
          },
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              reversed ? LucideIcons.rotateCcw : LucideIcons.truck,
              size: 18,
              color: statusColor,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  doc.number,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  reversed ? 'معكوس' : 'مكتمل',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 5,
                  children: [
                    _miniMeta(
                      LucideIcons.package,
                      '${doc.palletCount} بالتة • ${doc.itemLineCount} بند',
                    ),
                    _miniMeta(
                      LucideIcons.layers,
                      doc.totalsByUnitSummary,
                      highlight: true,
                    ),
                    _miniMeta(LucideIcons.userRound, doc.createdByName),
                    _miniMeta(LucideIcons.clock3, _fmtDispDateTime(doc.createdAt)),
                  ],
                ),
                if (doc.palletReferences.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: doc.palletReferences
                        .take(4)
                        .map(
                          (ref) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              ref,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: _kDispMuted,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          children: [
            const Divider(height: 14, color: Color(0xFFEDF1F5)),
            if (isLoadingLines)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                ),
              )
            else if (lines == null || lines!.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'لا توجد بنود مسجلة في هذا المستند.',
                  style: TextStyle(fontSize: 12, color: _kDispMuted),
                ),
              )
            else
              Column(
                children: lines!
                    .map(
                      (line) => Container(
                        margin: const EdgeInsets.only(bottom: 7),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE8EEF5)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    line.itemName,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryNavy,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        line.palletReference,
                                        textDirection: TextDirection.ltr,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          color: _kDispMuted,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        'الموقع: ${line.slotCode}',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          color: _kDispMuted,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (line.returnedSlotCode != null &&
                                          line.returnedSlotCode!.isNotEmpty)
                                        Text(
                                          'أُعيدت إلى: ${line.returnedSlotCode}',
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            color: AppColors.warningAmber,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${_fmtDispQty(line.quantity)} ${_unitAr(line.unit)}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primaryNavy,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  line.method == 'full_pallet'
                                      ? 'بالتة كاملة'
                                      : 'صرف جزئي',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: _kDispMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            if (reversed &&
                doc.reversalReason != null &&
                doc.reversalReason!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningAmber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.warningAmber.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سبب العكس: ${doc.reversalReason}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    if (doc.reversedByName != null || doc.reversedAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          '${doc.reversedByName ?? ''}${doc.reversedAt != null ? ' • ${_fmtDispDateTime(doc.reversedAt!)}' : ''}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: _kDispMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (canReverse) ...[
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: OutlinedButton.icon(
                  onPressed: onReverse,
                  icon: const Icon(LucideIcons.rotateCcw, size: 15),
                  label: const Text('عكس مستند الصرف'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.dangerRed,
                    side: BorderSide(
                      color: AppColors.dangerRed.withValues(alpha: 0.45),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniMeta(IconData icon, String text, {bool highlight = false}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 12.5,
        color: highlight ? AppColors.zoneC2Blue : _kDispMuted,
      ),
      const SizedBox(width: 4),
      Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
          color: highlight ? AppColors.zoneC2Blue : _kDispMuted,
        ),
      ),
    ],
  );
}

class _ReversalSubmission {
  final String reason;
  final List<DispatchSlotAssignment> alternativeSlots;

  const _ReversalSubmission({
    required this.reason,
    required this.alternativeSlots,
  });
}

class _SmartReversalDialog extends StatefulWidget {
  final DispatchReversalReadinessEntity readiness;

  const _SmartReversalDialog({required this.readiness});

  @override
  State<_SmartReversalDialog> createState() => _SmartReversalDialogState();
}

class _SmartReversalDialogState extends State<_SmartReversalDialog> {
  final TextEditingController _reasonCtrl = TextEditingController();
  final Map<String, String> _selectedAltSlots = {};
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final needs = widget.readiness.palletsNeedingAlternativeSlot;
    final empty = widget.readiness.availableEmptySlots;
    for (var i = 0; i < needs.length && i < empty.length; i++) {
      _selectedAltSlots[needs[i].palletId] = empty[i].slotId;
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      setState(() => _validationError = 'يرجى كتابة سبب عكس المستند.');
      return;
    }

    final needs = widget.readiness.palletsNeedingAlternativeSlot;
    if (needs.isNotEmpty) {
      final usedSlots = <String>{};
      for (final p in needs) {
        final chosen = _selectedAltSlots[p.palletId];
        if (chosen == null || chosen.isEmpty) {
          setState(
            () => _validationError =
                'يرجى اختيار موقع بديل للبالتة ${p.palletReference}.',
          );
          return;
        }
        if (!usedSlots.add(chosen)) {
          setState(
            () => _validationError =
                'لا يمكن اختيار نفس الموقع البديل لأكثر من بالتة.',
          );
          return;
        }
      }
    }

    Navigator.of(context).pop(
      _ReversalSubmission(
        reason: reason,
        alternativeSlots: needs
            .map(
              (p) => {
                'pallet_id': p.palletId,
                'slot_id': _selectedAltSlots[p.palletId]!,
              },
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final needs = widget.readiness.palletsNeedingAlternativeSlot;
    final emptySlots = widget.readiness.availableEmptySlots;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(LucideIcons.rotateCcw, color: AppColors.dangerRed),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'عكس المستند ${widget.readiness.documentNumber}',
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryNavy,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _reasonCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'سبب التراجع / العكس',
                    hintText: 'اكتب سبب إلغاء مستند الصرف وإعادة الكميات...',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (needs.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warningAmber.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.warningAmber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          LucideIcons.triangleAlert,
                          size: 16,
                          color: AppColors.warningAmber,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'الموقع الأصلي لبعض البالتات أصبح مشغولاً؛ اختر موقعاً بديلاً فارغاً لإعادة التسكين:',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...needs.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p.palletReference} (الأصلي: ${p.originalSlotCode})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                          const SizedBox(height: 5),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedAltSlots[p.palletId],
                            isExpanded: true,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            items: emptySlots
                                .map(
                                  (s) => DropdownMenuItem<String>(
                                    value: s.slotId,
                                    child: Text(
                                      '${s.slotCode} (${s.zoneCode})',
                                      textDirection: TextDirection.ltr,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedAltSlots[p.palletId] = val;
                                  _validationError = null;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_validationError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _validationError!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dangerRed,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerRed),
            onPressed: _confirm,
            child: const Text('تأكيد العكس'),
          ),
        ],
      ),
    );
  }
}
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdf/pdf.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/cold_storage_pdf_service.dart';
import '../../../../core/widgets/app_pagination_bar.dart';
import '../../../../core/widgets/app_pro_data_table.dart';
import '../../../../core/widgets/responsive_shimmer.dart';
import '../../domain/entities/receiving_entities.dart';
import '../cubit/receiving_cubit.dart';
import '../cubit/receiving_state.dart';

String _fmtDate(DateTime d) => intl.DateFormat('yyyy-MM-dd').format(d);

String _fmtDateTime(DateTime d) =>
    intl.DateFormat('yyyy-MM-dd  HH:mm').format(d);

String _fmtQty(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

Color _kindColor(ReceiptOperationKind kind) => switch (kind) {
  ReceiptOperationKind.mixed => AppColors.mixedPurple,
  ReceiptOperationKind.addItem => AppColors.zoneC3Teal,
  _ => AppColors.zoneC2Blue,
};

/// شاشة سجل الاستلامات (كافة الحسابات والتجميع والفلترة والباجينيشن داخل PostgreSQL)
class ReceivingHistoryView extends StatefulWidget {
  const ReceivingHistoryView({super.key});

  @override
  State<ReceivingHistoryView> createState() => _ReceivingHistoryViewState();
}

class _ReceivingHistoryViewState extends State<ReceivingHistoryView> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _isExportingPdf = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ReceivingCubit>().ensureReceiptsLoaded();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      final cubit = context.read<ReceivingCubit>();
      cubit.updateReceiptsFilter(
        cubit.state.receiptsFilter.copyWith(search: value.trim()),
      );
    });
  }

  void _clearAllFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();
    context.read<ReceivingCubit>().clearReceiptsFilters();
  }

  String _filterDescription(ReceiptsHistoryFilter f) {
    final parts = <String>[];
    if (f.kind != ReceiptOperationKind.all) {
      parts.add(f.kind.arLabel);
    }
    if (f.source != null) {
      parts.add(f.source!.arLabel);
    }
    if (f.fromDate != null) {
      parts.add('من ${_fmtDate(f.fromDate!)}');
    }
    if (f.toDate != null) {
      parts.add('إلى ${_fmtDate(f.toDate!)}');
    }
    return parts.isEmpty
        ? 'كل الأنواع • كل الجهات • كل الفترات'
        : parts.join(' · ');
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final cubit = context.read<ReceivingCubit>();
    final current = cubit.state.receiptsFilter;
    final picked = await showDatePicker(
      context: context,
      initialDate:
          (isFrom ? current.fromDate : current.toDate) ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      locale: const Locale('ar', 'EG'),
      helpText: isFrom ? 'اختر تاريخ البداية' : 'اختر تاريخ النهاية',
    );
    if (picked == null || !mounted) {
      return;
    }

    var nextFrom = current.fromDate;
    var nextTo = current.toDate;
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

    await cubit.updateReceiptsFilter(
      current.copyWith(fromDate: nextFrom, toDate: nextTo),
    );
  }

  Future<void> _exportPdf() async {
    if (_isExportingPdf) {
      return;
    }
    setState(() => _isExportingPdf = true);

    try {
      final cubit = context.read<ReceivingCubit>();
      final exported = await cubit.fetchReceiptsForExport();
      final operations = exported.page.items;
      final summary = exported.summary;
      final filterDesc = _filterDescription(cubit.state.receiptsFilter);

      final rows = operations.map((op) {
        final itemsText = op.items
            .map(
              (e) =>
                  '${e.itemName}  —  ${_fmtQty(e.quantity)} ${e.unit.arLabel}',
            )
            .join('\n');
        return <String>[
          _fmtDateTime(op.createdAt),
          op.performedByName,
          op.sourceEntity.arLabel,
          op.slotCode,
          op.totalSummary,
          itemsText,
          op.palletReference,
          op.kindDisplayLabel,
        ];
      }).toList();

      await ColdStoragePdfService.printCustomTableReport(
        reportTitle: 'سجل الاستلامات والتسكين — ثلاجة المخفض',
        reportSubtitle:
            'الفلاتر: $filterDesc | إجمالي العمليات: ${summary.totalOperations}',
        headers: const [
          'التاريخ والوقت',
          'المستلم',
          'الجهة',
          'الموقع',
          'إجمالي البالتة',
          'الأصناف والكميات',
          'كود البالتة',
          'نوع العملية',
        ],
        rows: rows,
        fileName: 'receiving_history_report.pdf',
        headerColor: PdfColors.blue900,
        summaryMetrics: {
          'إجمالي العمليات': '${summary.totalOperations}',
          'التوزيع':
              '${summary.singleCount} موحدة • ${summary.mixedCount} ميكس • ${summary.addItemCount} تزويد',
          'إجمالي البنود': '${summary.totalItemLines}',
          'إجمالي الكميات': summary.totalsByUnitSummary,
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

  Future<void> _showMobileFiltersSheet(ReceiptsHistoryFilter current) async {
    var tempKind = current.kind;
    var tempSource = current.source;
    var tempFrom = current.fromDate;
    var tempTo = current.toDate;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'تصفية سجل الاستلامات',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setSheetState(() {
                        tempKind = ReceiptOperationKind.all;
                        tempSource = null;
                        tempFrom = null;
                        tempTo = null;
                      }),
                      child: const Text('إعادة ضبط'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'نوع العملية',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ReceiptOperationKind.values
                      .map(
                        (k) => _filterChip(
                          label: k.arLabel,
                          selected: tempKind == k,
                          activeColor: AppColors.zoneC2Blue,
                          onTap: () => setSheetState(() => tempKind = k),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                const Text(
                  'جهة الاستلام',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _filterChip(
                      label: 'كل الجهات',
                      selected: tempSource == null,
                      onTap: () => setSheetState(() => tempSource = null),
                    ),
                    _filterChip(
                      label: 'الإنتاج',
                      selected: tempSource == ReceivingSource.production,
                      onTap: () => setSheetState(
                        () => tempSource = ReceivingSource.production,
                      ),
                    ),
                    _filterChip(
                      label: 'فحص الجودة',
                      selected: tempSource == ReceivingSource.qualityInspection,
                      onTap: () => setSheetState(
                        () => tempSource = ReceivingSource.qualityInspection,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: tempFrom ?? DateTime.now(),
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2035),
                            locale: const Locale('ar', 'EG'),
                          );
                          if (d != null) {
                            setSheetState(() {
                              tempFrom = d;
                              if (tempTo != null &&
                                  tempFrom!.isAfter(tempTo!)) {
                                tempTo = d;
                              }
                            });
                          }
                        },
                        icon: const Icon(LucideIcons.calendar, size: 16),
                        label: Text(
                          tempFrom == null ? 'من تاريخ' : _fmtDate(tempFrom!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: tempTo ?? DateTime.now(),
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2035),
                            locale: const Locale('ar', 'EG'),
                          );
                          if (d != null) {
                            setSheetState(() {
                              tempTo = d;
                              if (tempFrom != null &&
                                  tempTo!.isBefore(tempFrom!)) {
                                tempFrom = d;
                              }
                            });
                          }
                        },
                        icon: const Icon(LucideIcons.calendarCheck, size: 16),
                        label: Text(
                          tempTo == null ? 'إلى تاريخ' : _fmtDate(tempTo!),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetCtx, true),
                  child: const Text('تطبيق الفلاتر'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (applied == true && mounted) {
      await context.read<ReceivingCubit>().updateReceiptsFilter(
        ReceiptsHistoryFilter(
          page: 1,
          pageSize: current.pageSize,
          search: current.search,
          kind: tempKind,
          source: tempSource,
          fromDate: tempFrom,
          toDate: tempTo,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReceivingCubit, ReceivingState>(
      buildWhen: (prev, curr) =>
          prev.isReceiptsLoading != curr.isReceiptsLoading ||
          prev.receiptsInitialized != curr.receiptsInitialized ||
          prev.receiptsHistory != curr.receiptsHistory ||
          prev.receiptsFilter != curr.receiptsFilter,
      builder: (context, state) {
        final cubit = context.read<ReceivingCubit>();
        final history = state.receiptsHistory;
        final pageData = history.page;
        final summary = history.summary;
        final filter = state.receiptsFilter;
        final highlightQuery = filter.search.trim().toLowerCase();

        return LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 900;
            final pad = desktop ? 24.0 : 14.0;

            return Directionality(
              textDirection: TextDirection.rtl,
              child: RefreshIndicator(
                onRefresh: () => cubit.loadReceiptsHistory(),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        pad,
                        desktop ? 18 : 10,
                        pad,
                        12,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (desktop) ...[
                              _buildHeader(context, desktop, summary),
                              const SizedBox(height: 14),
                            ],
                            _buildKpiRow(desktop: desktop, summary: summary),
                            SizedBox(height: desktop ? 14 : 10),
                            _buildFiltersBar(desktop, filter),
                            SizedBox(height: desktop ? 16 : 12),
                            Row(
                              children: [
                                const Text(
                                  'تفاصيل البالتات المستلمة',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primaryNavy,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF0FF),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${summary.totalOperations} عملية',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.zoneC2Blue,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (desktop)
                                  const Text(
                                    'اضغط على أي صف لمعاينة تفاصيل البالتة كاملة',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  )
                                else
                                  FilledButton.icon(
                                    onPressed:
                                        (summary.totalOperations == 0 ||
                                            _isExportingPdf)
                                        ? null
                                        : _exportPdf,
                                    icon: _isExportingPdf
                                        ? const SizedBox(
                                            width: 13,
                                            height: 13,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            LucideIcons.fileDown,
                                            size: 14,
                                          ),
                                    label: Text(
                                      _isExportingPdf ? 'تجهيز...' : 'PDF',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primaryNavy,
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 7,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!state.receiptsInitialized ||
                        (state.isReceiptsLoading && pageData.items.isEmpty))
                      SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: pad),
                        sliver: const SliverToBoxAdapter(
                          child: SizedBox(
                            height: 320,
                            child: ResponsiveColdStorageShimmer(
                              mode: ShimmerLayoutMode.tableList,
                              itemCountOverride: 5,
                            ),
                          ),
                        ),
                      )
                    else if (pageData.items.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(filter),
                      )
                    else ...[
                      if (desktop)
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(pad, 0, pad, 14),
                          sliver: SliverToBoxAdapter(
                            child: _buildDesktopTable(
                              context,
                              pageData.items,
                              highlightQuery,
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(pad, 0, pad, 12),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _ReceiptMobileCard(
                                operation: pageData.items[index],
                                highlightQuery: highlightQuery,
                                onTap: () => _openDetails(
                                  context,
                                  pageData.items[index],
                                ),
                              ),
                              childCount: pageData.items.length,
                            ),
                          ),
                        ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(pad, 0, pad, 28),
                        sliver: SliverToBoxAdapter(
                          child: AppPaginationBar(
                            pageData: pageData,
                            isLoading: state.isReceiptsLoading,
                            onPageChanged: cubit.goToReceiptsPage,
                            onPageSizeChanged: cubit.changeReceiptsPageSize,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool desktop,
    ReceiptsHistorySummaryEntity summary,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سجل الاستلامات',
                style: TextStyle(
                  fontSize: desktop ? 22 : 19,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'سجل مجمّع من قاعدة البيانات (موحدة وميكس) بإجمالي كل بالتة وترقيم صفحات',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'تحديث',
          onPressed: () => context.read<ReceivingCubit>().loadReceiptsHistory(),
          icon: const Icon(LucideIcons.refreshCw, size: 16),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: (summary.totalOperations == 0 || _isExportingPdf)
              ? null
              : _exportPdf,
          icon: _isExportingPdf
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(LucideIcons.fileDown, size: 16),
          label: Text(
            _isExportingPdf ? 'تجهيز...' : (desktop ? 'تصدير PDF' : 'PDF'),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryNavy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiRow({
    required bool desktop,
    required ReceiptsHistorySummaryEntity summary,
  }) {
    final distribution = summary.addItemCount > 0
        ? '${summary.singleCount} موحدة • ${summary.mixedCount} ميكس • ${summary.addItemCount} تزويد'
        : '${summary.singleCount} موحدة • ${summary.mixedCount} ميكس';

    final tiles = [
      _kpiCard(
        label: 'عمليات الاستلام',
        value: '${summary.totalOperations}',
        subLabel: distribution,
        icon: LucideIcons.clipboardList,
        bg: const Color(0xFFEAF0FF),
        fg: AppColors.zoneC2Blue,
      ),
      _kpiCard(
        label: 'عدد بنود الأصناف',
        value: '${summary.totalItemLines}',
        subLabel: 'إجمالي أسطر الاستلام',
        icon: LucideIcons.package,
        bg: const Color(0xFFE8F7EF),
        fg: AppColors.successGreen,
      ),
      _kpiCard(
        label: 'إجمالي الكميات المستلمة',
        value: summary.totalsByUnitSummary,
        subLabel: 'محسوب بالكامل من قاعدة البيانات',
        icon: LucideIcons.chartNoAxesColumn,
        bg: const Color(0xFFFFF4E5),
        fg: AppColors.warningAmber,
      ),
    ];

    if (desktop) {
      return Row(
        children: [
          Expanded(child: tiles[0]),
          const SizedBox(width: 12),
          Expanded(child: tiles[1]),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: tiles[2]),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: 10),
            Expanded(child: tiles[1]),
          ],
        ),
        const SizedBox(height: 10),
        tiles[2],
      ],
    );
  }

  Widget _kpiCard({
    required String label,
    required String value,
    required String subLabel,
    required IconData icon,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: fg, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryNavy,
                  ),
                ),
                Text(
                  subLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersBar(bool desktop, ReceiptsHistoryFilter filter) {
    final cubit = context.read<ReceivingCubit>();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (_, val, _) => TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText:
                          'ابحث بالصنف أو كود البالتة أو الموقع أو المستلم',
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                      suffixIcon: val.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(LucideIcons.x, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            ),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: const BorderSide(
                          color: AppColors.borderLight,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: const BorderSide(
                          color: AppColors.borderLight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (!desktop) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'الفلاتر',
                  onPressed: () => _showMobileFiltersSheet(filter),
                  icon: const Icon(LucideIcons.slidersHorizontal, size: 18),
                ),
              ],
            ],
          ),
          if (desktop) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...ReceiptOperationKind.values.map(
                  (kind) => _filterChip(
                    label: kind.arLabel,
                    selected: filter.kind == kind,
                    activeColor: AppColors.zoneC2Blue,
                    onTap: () => cubit.updateReceiptsFilter(
                      filter.copyWith(kind: kind),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 22,
                  child: VerticalDivider(color: AppColors.borderLight),
                ),
                _filterChip(
                  label: 'كل الجهات',
                  selected: filter.source == null,
                  onTap: () => cubit.updateReceiptsFilter(
                    filter.copyWith(clearSource: true),
                  ),
                ),
                _filterChip(
                  label: 'الإنتاج',
                  selected: filter.source == ReceivingSource.production,
                  onTap: () => cubit.updateReceiptsFilter(
                    filter.copyWith(source: ReceivingSource.production),
                  ),
                ),
                _filterChip(
                  label: 'فحص الجودة',
                  selected: filter.source == ReceivingSource.qualityInspection,
                  onTap: () => cubit.updateReceiptsFilter(
                    filter.copyWith(source: ReceivingSource.qualityInspection),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickDate(isFrom: true),
                  icon: const Icon(LucideIcons.calendar, size: 15),
                  label: Text(
                    filter.fromDate == null
                        ? 'من تاريخ'
                        : _fmtDate(filter.fromDate!),
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickDate(isFrom: false),
                  icon: const Icon(LucideIcons.calendarCheck, size: 15),
                  label: Text(
                    filter.toDate == null
                        ? 'إلى تاريخ'
                        : _fmtDate(filter.toDate!),
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                if (filter.hasActiveFilters)
                  TextButton.icon(
                    onPressed: _clearAllFilters,
                    icon: const Icon(LucideIcons.rotateCcw, size: 14),
                    label: const Text('مسح', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ] else if (filter.hasActiveFilters) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _filterDescription(filter),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: _clearAllFilters,
                  child: const Text('مسح الفلاتر'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color activeColor = AppColors.primaryNavy,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      selectedColor: activeColor,
      backgroundColor: const Color(0xFFF8FAFC),
      side: BorderSide(color: selected ? activeColor : AppColors.borderLight),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: selected ? Colors.white : AppColors.primaryNavy,
      ),
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildEmptyState(ReceiptsHistoryFilter filter) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.package,
            size: 38,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 10),
          const Text(
            'لا توجد عمليات استلام مطابقة للفلاتر المحددة.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primaryNavy,
            ),
          ),
          if (filter.hasActiveFilters) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(LucideIcons.rotateCcw, size: 15),
              label: const Text('مسح الفلاتر'),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _buildDesktopTable(
    BuildContext context,
    List<ReceiptOperationEntity> operations,
    String highlightQuery,
  ) {
    return AppProDataTable<ReceiptOperationEntity>(
      items: operations,
      expandHeight: false,
      minTableWidth: 980,
      onRowTap: (op) => _openDetails(context, op),
      columns: [
        AppProTableColumn(
          label: 'نوع البالتة',
          fixedWidth: 128,
          cellBuilder: (_, op, _) {
            final color = _kindColor(op.operationKind);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                op.kindDisplayLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          },
        ),
        AppProTableColumn(
          label: 'كود البالتة',
          fixedWidth: 145,
          cellBuilder: (_, op, _) => Text(
            op.palletReference,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: AppColors.primaryNavy,
            ),
          ),
        ),
        AppProTableColumn(
          label: 'الأصناف والكميات',
          flex: 4,
          cellBuilder: (_, op, _) {
            final dotColor = _kindColor(op.operationKind);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: op.items.asMap().entries.map((entry) {
                final e = entry.value;
                final isMatch =
                    highlightQuery.isNotEmpty &&
                    e.itemName.toLowerCase().contains(highlightQuery);

                return Container(
                  margin: EdgeInsets.only(
                    bottom: entry.key == op.items.length - 1 ? 0 : 4,
                  ),
                  padding: isMatch
                      ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                      : EdgeInsets.zero,
                  decoration: isMatch
                      ? BoxDecoration(
                          color: AppColors.zoneC2Blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        )
                      : null,
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          e.itemName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isMatch
                                ? FontWeight.w900
                                : FontWeight.w700,
                            color: isMatch
                                ? AppColors.zoneC2Blue
                                : AppColors.primaryNavy,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_fmtQty(e.quantity)} ${e.unit.arLabel}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
        AppProTableColumn(
          label: 'إجمالي البالتة',
          fixedWidth: 138,
          alignment: Alignment.center,
          cellBuilder: (_, op, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.successGreen.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              op.totalSummary,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: AppColors.successGreen,
              ),
            ),
          ),
        ),
        AppProTableColumn(
          label: 'الموقع',
          fixedWidth: 112,
          alignment: Alignment.center,
          cellBuilder: (_, op, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              op.slotCode,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
                color: AppColors.primaryNavy,
              ),
            ),
          ),
        ),
        AppProTableColumn(
          label: 'المستلم',
          flex: 2,
          cellBuilder: (_, op, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                op.performedByName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryNavy,
                  fontSize: 12,
                ),
              ),
              Text(
                op.sourceEntity.arLabel,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        AppProTableColumn(
          label: 'التاريخ والوقت',
          fixedWidth: 132,
          alignment: AlignmentDirectional.centerEnd,
          cellBuilder: (_, op, _) => Text(
            _fmtDateTime(op.createdAt),
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  void _openDetails(BuildContext context, ReceiptOperationEntity operation) {
    showDialog<void>(
      context: context,
      builder: (_) => _PalletReceiptDetailsDialog(operation: operation),
    );
  }
}

class _ReceiptMobileCard extends StatelessWidget {
  final ReceiptOperationEntity operation;
  final String highlightQuery;
  final VoidCallback onTap;

  const _ReceiptMobileCard({
    required this.operation,
    required this.highlightQuery,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = _kindColor(operation.operationKind);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      operation.kindDisplayLabel,
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      operation.palletReference,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              ...operation.items.asMap().entries.map((entry) {
                final item = entry.value;
                final isMatch =
                    highlightQuery.isNotEmpty &&
                    item.itemName.toLowerCase().contains(highlightQuery);

                return Container(
                  margin: EdgeInsets.only(
                    bottom: entry.key == operation.items.length - 1 ? 0 : 7,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: isMatch
                        ? AppColors.zoneC2Blue.withValues(alpha: 0.08)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isMatch
                          ? AppColors.zoneC2Blue.withValues(alpha: 0.35)
                          : const Color(0xFFEFF3F8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.itemName,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: isMatch
                                ? AppColors.zoneC2Blue
                                : AppColors.primaryNavy,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${_fmtQty(item.quantity)} ${item.unit.arLabel}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.layers,
                      size: 14,
                      color: AppColors.successGreen,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'إجمالي البالتة:',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      operation.totalSummary,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.successGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 18),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 6,
                children: [
                  _ReceiptMetaTag(LucideIcons.mapPin, operation.slotCode),
                  _ReceiptMetaTag(
                    LucideIcons.userRound,
                    operation.performedByName,
                  ),
                  _ReceiptMetaTag(
                    LucideIcons.clock3,
                    _fmtDateTime(operation.createdAt),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PalletReceiptDetailsDialog extends StatelessWidget {
  final ReceiptOperationEntity operation;

  const _PalletReceiptDetailsDialog({required this.operation});

  @override
  Widget build(BuildContext context) {
    final badgeColor = _kindColor(operation.operationKind);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(LucideIcons.package, color: badgeColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تفاصيل البالتة ${operation.palletReference}',
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  Text(
                    '${operation.kindDisplayLabel} • الموقع: ${operation.slotCode}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(LucideIcons.x, size: 18),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: operation.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, idx) {
                    final e = operation.items[idx];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.itemName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryNavy,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${_fmtQty(e.quantity)} ${e.unit.arLabel}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.zoneC2Blue,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 20),
              Row(
                children: [
                  const Text(
                    'إجمالي البالتة:',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    operation.totalSummary,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: AppColors.successGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _ReceiptMetaTag(
                    LucideIcons.userRound,
                    operation.performedByName,
                  ),
                  _ReceiptMetaTag(
                    LucideIcons.building2,
                    operation.sourceEntity.arLabel,
                  ),
                  _ReceiptMetaTag(
                    LucideIcons.clock3,
                    _fmtDateTime(operation.createdAt),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}

class _ReceiptMetaTag extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ReceiptMetaTag(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
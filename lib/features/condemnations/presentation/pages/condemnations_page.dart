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
import '../../domain/entities/condemnations_entities.dart';
import '../cubit/condemnations_cubit.dart';
import '../cubit/condemnations_state.dart';

const _kCondBg = Color(0xFFF3F6FB);
const _kCondBorder = Color(0xFFE3E8EF);
const _kCondMuted = Color(0xFF64748B);

String _fmtCondQty(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

String _fmtCondDate(DateTime d) => intl.DateFormat('yyyy-MM-dd').format(d);

String _fmtCondDateTime(DateTime d) =>
    intl.DateFormat('yyyy-MM-dd  HH:mm').format(d);

/// شاشة إدارة الإعدامات (التنبيهات النشطة + سجل الإعدامات المعتمد عبر PostgreSQL RPCs)
class CondemnationsPage extends StatefulWidget {
  const CondemnationsPage({super.key});

  @override
  State<CondemnationsPage> createState() => _CondemnationsPageState();
}

class _CondemnationsPageState extends State<CondemnationsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _alertsSearchCtrl = TextEditingController();
  final TextEditingController _historySearchCtrl = TextEditingController();
  Timer? _alertsDebounce;
  Timer? _historyDebounce;
  bool _isExportingPdf = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _alertsDebounce?.cancel();
    _historyDebounce?.cancel();
    _alertsSearchCtrl.dispose();
    _historySearchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onAlertsSearchChanged(String value) {
    _alertsDebounce?.cancel();
    _alertsDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      final cubit = context.read<CondemnationsCubit>();
      cubit.updateAlertsFilter(
        cubit.state.alertsFilter.copyWith(search: value.trim()),
      );
    });
  }

  void _clearAlertsFilters(CondemnationsCubit cubit) {
    _alertsDebounce?.cancel();
    _alertsSearchCtrl.clear();
    cubit.clearAlertsFilters();
  }

  void _onHistorySearchChanged(String value) {
    _historyDebounce?.cancel();
    _historyDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      final cubit = context.read<CondemnationsCubit>();
      cubit.updateHistoryFilter(
        cubit.state.historyFilter.copyWith(search: value.trim()),
      );
    });
  }

  void _clearHistoryFilters(CondemnationsCubit cubit) {
    _historyDebounce?.cancel();
    _historySearchCtrl.clear();
    cubit.clearHistoryFilters();
  }

  Future<void> _pickHistoryDate(
    BuildContext context,
    CondemnationsCubit cubit,
    CondemnationHistoryFilter filter,
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

    await cubit.updateHistoryFilter(
      filter.copyWith(fromDate: nextFrom, toDate: nextTo),
    );
  }

  Future<void> _exportAlertsPdf(CondemnationsCubit cubit) async {
    if (_isExportingPdf) {
      return;
    }
    setState(() => _isExportingPdf = true);

    try {
      final exported = await cubit.fetchAlertsForExport();
      final items = exported.page.items;
      final summary = exported.summary;

      final rows = items
          .map(
            (i) => <String>[
              i.isExpired ? 'منتهي الصلاحية' : 'متبقي ${i.daysUntilExpiry} يوم',
              _fmtCondDate(i.expiryDate),
              _fmtCondDate(i.productionDate),
              i.sourceArLabel,
              '${_fmtCondQty(i.quantity)} ${i.unitArLabel}',
              i.slotCode,
              i.palletReference,
              i.itemName,
            ],
          )
          .toList();

      await ColdStoragePdfService.printCustomTableReport(
        reportTitle: 'الأصناف المستحقة للإعدام — ثلاجة المخفض',
        reportSubtitle:
            'حد الثلاجة: ${summary.globalThresholdDays} يوم | تنبيه المستخدم: ${summary.userCustomAlertDays} يوم',
        headers: const [
          'الحالة',
          'تاريخ الانتهاء',
          'تاريخ الإنتاج',
          'الجهة',
          'الكمية',
          'الموقع',
          'رقم البالتة',
          'الصنف',
        ],
        rows: rows,
        fileName: 'condemnation_alerts_report.pdf',
        headerColor: PdfColors.red900,
        summaryMetrics: {
          'إجمالي التنبيهات': '${summary.totalAlerts}',
          'منتهي الصلاحية': '${summary.expiredCount}',
          'قارب الانتهاء': '${summary.dueSoonCount}',
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

  Future<void> _exportHistoryPdf(CondemnationsCubit cubit) async {
    if (_isExportingPdf) {
      return;
    }
    setState(() => _isExportingPdf = true);

    try {
      final exported = await cubit.fetchHistoryForExport();
      final items = exported.page.items;
      final summary = exported.summary;

      final rows = items
          .map(
            (r) => <String>[
              _fmtCondDateTime(r.createdAt),
              r.approvedByName,
              r.reason,
              _fmtCondDate(r.expiryDate),
              r.sourceArLabel,
              '${_fmtCondQty(r.condemnedQuantity)} ${r.unitArLabel}',
              r.slotCode,
              r.palletReference,
              r.itemName,
            ],
          )
          .toList();

      await ColdStoragePdfService.printCustomTableReport(
        reportTitle: 'سجل الإعدامات المعتمد — ثلاجة المخفض',
        reportSubtitle:
            'عدد العمليات: ${summary.totalRecords} | إجمالي المعدم: ${summary.totalsByUnitSummary}',
        headers: const [
          'تاريخ الإعدام',
          'المعتمد',
          'سبب الإعدام',
          'تاريخ الانتهاء',
          'الجهة',
          'الكمية المعدمة',
          'الموقع',
          'رقم البالتة',
          'الصنف',
        ],
        rows: rows,
        fileName: 'condemnations_history_report.pdf',
        headerColor: PdfColors.red900,
        summaryMetrics: {
          'عدد العمليات': '${summary.totalRecords}',
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

  Future<void> _openApproveDialog(
    BuildContext context,
    CondemnationAlertItemEntity item,
  ) async {
    final result = await showDialog<_CondemnationApprovalResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ApproveCondemnationDialog(item: item),
    );
    if (result == null || !mounted) {
      return;
    }

    await context.read<CondemnationsCubit>().approveCondemnation(
      palletItemId: item.palletItemId,
      availableQuantity: item.quantity,
      quantityToCondemn: result.quantity,
      reason: result.reason,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _kCondBg,
      child: BlocConsumer<CondemnationsCubit, CondemnationsState>(
        listenWhen: (prev, curr) =>
            prev.failure != curr.failure ||
            prev.successMessage != curr.successMessage,
        listener: (context, state) {
          final isOffstage =
              context.findAncestorWidgetOfExactType<Offstage>()?.offstage ??
              false;
          if (isOffstage) {
            return;
          }

          final message = state.failure?.message ?? state.successMessage;
          if (message == null) {
            return;
          }
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: state.failure != null
                    ? AppColors.dangerRed
                    : AppColors.successGreen,
                behavior: SnackBarBehavior.floating,
              ),
            );
        },
        builder: (context, state) {
          final cubit = context.read<CondemnationsCubit>();
          final alertsSummary = state.alertsData.summary;
          final historySummary = state.historyData.summary;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 900;
                final wide = constraints.maxWidth >= 1280;

                return Column(
                  children: [
                    if (desktop)
                      _buildDesktopHeader(
                        cubit,
                        alertsSummary,
                        historySummary,
                      ),
                    Material(
                      color: Colors.white,
                      elevation: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: _kCondBorder),
                          ),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          labelColor: AppColors.dangerRed,
                          unselectedLabelColor: _kCondMuted,
                          indicatorColor: AppColors.dangerRed,
                          indicatorWeight: 2.5,
                          labelStyle: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                          tabs: [
                            Tab(
                              height: 46,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.triangleAlert,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'المستحق (${alertsSummary.totalAlerts})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Tab(
                              height: 46,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.history, size: 16),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'السجل (${historySummary.totalRecords})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildAlertsTab(
                            context,
                            cubit,
                            state,
                            desktop,
                            wide,
                          ),
                          _buildHistoryTab(context, cubit, state, desktop),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopHeader(
    CondemnationsCubit cubit,
    CondemnationAlertsSummaryEntity alertsSummary,
    CondemnationHistorySummaryEntity historySummary,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
      color: _kCondBg,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.dangerRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              LucideIcons.flame,
              color: AppColors.dangerRed,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إدارة الإعدامات وصلاحية المخزون',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryNavy,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'متابعة الأصناف المنتهية والمقتربة من الإعدام واعتمادها رسمياً',
                  style: TextStyle(fontSize: 12, color: _kCondMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: _kCondBorder),
            ),
            child: Text(
              'حد الثلاجة: ${alertsSummary.globalThresholdDays} يوم  •  تنبيهك: ${alertsSummary.userCustomAlertDays} يوم',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryNavy,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'تحديث',
            onPressed: () => cubit.loadAll(),
            icon: const Icon(LucideIcons.refreshCw, size: 16),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // التبويب الأول: الأصناف المستحقة للإعدام (Server-Side Pagination)
  // ===========================================================================
  Widget _buildAlertsTab(
    BuildContext context,
    CondemnationsCubit cubit,
    CondemnationsState state,
    bool desktop,
    bool wide,
  ) {
    if (!state.alertsInitialized && state.isAlertsLoading) {
      return const ResponsiveColdStorageShimmer(
        mode: ShimmerLayoutMode.dashboardCards,
        itemCountOverride: 6,
      );
    }

    final pageData = state.alertsData.page;
    final summary = state.alertsData.summary;
    final filter = state.alertsFilter;
    final items = pageData.items;
    final pad = desktop ? 24.0 : 12.0;
    final columns = wide
        ? 3
        : desktop
        ? 2
        : 1;

    return RefreshIndicator(
      onRefresh: () => cubit.loadAlerts(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, desktop ? 16 : 10, pad, 10),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAlertsSummaryBanner(cubit, summary, desktop),
                  const SizedBox(height: 10),
                  _buildAlertsFiltersCard(cubit, filter, desktop),
                  if (state.isAlertsLoading || state.isSubmitting) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(minHeight: 2.5),
                  ],
                ],
              ),
            ),
          ),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(
                title: filter.hasActiveFilters
                    ? 'لا توجد أصناف مطابقة للفلتر'
                    : 'لا توجد أصناف مستحقة للإعدام حالياً',
                subtitle: filter.hasActiveFilters
                    ? 'جرّب تعديل كلمة البحث أو اختيار كل الحالات.'
                    : 'جميع الأرصدة الحالية ضمن فترة الصلاحية الآمنة.',
                icon: filter.hasActiveFilters
                    ? LucideIcons.searchX
                    : LucideIcons.shieldCheck,
                iconColor: filter.hasActiveFilters
                    ? _kCondMuted
                    : AppColors.successGreen,
                onClear: filter.hasActiveFilters
                    ? () => _clearAlertsFilters(cubit)
                    : null,
              ),
            )
          else ...[
            if (columns == 1)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, 10),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, index) => Padding(
                      padding: EdgeInsets.only(
                        bottom: index == items.length - 1 ? 0 : 10,
                      ),
                      child: _buildAlertCard(ctx, items[index], state),
                    ),
                    childCount: items.length,
                  ),
                ),
              )
            else
              _buildDesktopAlertRows(items, columns, pad, state),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, 20),
              sliver: SliverToBoxAdapter(
                child: AppPaginationBar(
                  pageData: pageData,
                  isLoading: state.isAlertsLoading,
                  pageSizeOptions: const [15, 20, 50],
                  onPageChanged: cubit.goToAlertsPage,
                  onPageSizeChanged: cubit.changeAlertsPageSize,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertsSummaryBanner(
    CondemnationsCubit cubit,
    CondemnationAlertsSummaryEntity summary,
    bool desktop,
  ) {
    final pdfBtn = _buildPdfButton(
      enabled: summary.totalAlerts > 0 && !_isExportingPdf,
      desktop: desktop,
      onPressed: () => _exportAlertsPdf(cubit),
    );

    if (!desktop) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.dangerRed.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: AppColors.dangerRed.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _miniBadge(
                        '${summary.expiredCount} منتهي',
                        AppColors.dangerRed,
                      ),
                      _miniBadge(
                        '${summary.dueSoonCount} قارب الانتهاء',
                        AppColors.warningAmber,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'حد الثلاجة: ${summary.globalThresholdDays} يوم • تنبيهك: ${summary.userCustomAlertDays} يوم',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kCondMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            pdfBtn,
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dangerRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.clockAlert,
            color: AppColors.dangerRed,
            size: 20,
          ),
          const SizedBox(width: 10),
          _miniBadge('${summary.expiredCount} منتهي الصلاحية', AppColors.dangerRed),
          const SizedBox(width: 8),
          _miniBadge(
            '${summary.dueSoonCount} قارب الانتهاء',
            AppColors.warningAmber,
          ),
          const Spacer(),
          pdfBtn,
        ],
      ),
    );
  }

  Widget _buildAlertsFiltersCard(
    CondemnationsCubit cubit,
    CondemnationAlertsFilter filter,
    bool desktop,
  ) {
    final searchField = ValueListenableBuilder<TextEditingValue>(
      valueListenable: _alertsSearchCtrl,
      builder: (_, val, _) => TextField(
        controller: _alertsSearchCtrl,
        onChanged: _onAlertsSearchChanged,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'بحث بالصنف، الموقع، رقم البالتة أو المستلم',
          hintStyle: const TextStyle(fontSize: 12.5),
          prefixIcon: const Icon(LucideIcons.search, size: 17),
          suffixIcon: val.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _alertsSearchCtrl.clear();
                    _onAlertsSearchChanged('');
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
            borderSide: const BorderSide(color: _kCondBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: _kCondBorder),
          ),
        ),
      ),
    );

    Widget statusChip(String label, String? value, Color activeColor) {
      final selected = filter.status == value;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        selectedColor: activeColor,
        backgroundColor: const Color(0xFFF8FAFC),
        side: BorderSide(color: selected ? activeColor : _kCondBorder),
        labelStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: selected ? Colors.white : AppColors.primaryNavy,
        ),
        onSelected: (_) => cubit.updateAlertsFilter(
          filter.copyWith(status: value, clearStatus: value == null),
        ),
      );
    }

    final chips = Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        statusChip('الكل', null, AppColors.primaryNavy),
        statusChip('منتهي', 'expired', AppColors.dangerRed),
        statusChip('قارب الانتهاء', 'due_soon', AppColors.warningAmber),
        if (filter.hasActiveFilters)
          TextButton.icon(
            onPressed: () => _clearAlertsFilters(cubit),
            icon: const Icon(LucideIcons.rotateCcw, size: 13),
            label: const Text('مسح', style: TextStyle(fontSize: 11.5)),
          ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(desktop ? 14 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kCondBorder),
      ),
      child: desktop
          ? Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 12),
                chips,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: 8),
                chips,
              ],
            ),
    );
  }

  Widget _buildDesktopAlertRows(
    List<CondemnationAlertItemEntity> items,
    int columns,
    double pad,
    CondemnationsState state,
  ) {
    final rowCount = (items.length / columns).ceil();
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(pad, 0, pad, 12),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((ctx, rowIdx) {
          final start = rowIdx * columns;
          return Padding(
            padding: EdgeInsets.only(bottom: rowIdx == rowCount - 1 ? 0 : 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(columns, (col) {
                final idx = start + col;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      end: col == columns - 1 ? 0 : 12,
                    ),
                    child: idx < items.length
                        ? _buildAlertCard(ctx, items[idx], state)
                        : const SizedBox.shrink(),
                  ),
                );
              }),
            ),
          );
        }, childCount: rowCount),
      ),
    );
  }

  Widget _buildAlertCard(
    BuildContext context,
    CondemnationAlertItemEntity item,
    CondemnationsState state,
  ) {
    final expired = item.isExpired;
    final statusColor = expired ? AppColors.dangerRed : AppColors.warningAmber;
    final daysLabel = expired
        ? (item.daysUntilExpiry == 0
              ? 'ينتهي اليوم'
              : 'منتهي منذ ${item.daysUntilExpiry.abs()} يوم')
        : 'متبقي ${item.daysUntilExpiry} يوم';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. الصف العلوي: أيقونة + اسم الصنف + كود البالتة + شارة الحالة
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    LucideIcons.packageX,
                    size: 18,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.itemName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                          color: AppColors.primaryNavy,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.palletReference,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: _kCondMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _miniBadge(daysLabel, statusColor),
              ],
            ),

            const SizedBox(height: 11),

            // 2. شريط الكمية والموقع متوازن 50/50
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE7EDF4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'الرصيد المتاح',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _kCondMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_fmtCondQty(item.quantity)} ${item.unitArLabel}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 28, color: _kCondBorder),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'موقع التخزين',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _kCondMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.slotCode,
                          textDirection: TextDirection.ltr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 3. تواريخ الصلاحية والجهة والمستلم
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _metaTag(
                  LucideIcons.calendar,
                  'إنتاج: ${_fmtCondDate(item.productionDate)}',
                ),
                _metaTag(
                  LucideIcons.calendarClock,
                  'انتهاء: ${_fmtCondDate(item.expiryDate)}',
                  highlightColor: statusColor,
                ),
                _metaTag(LucideIcons.factory, item.sourceArLabel),
                _metaTag(LucideIcons.userRound, item.receivedByName),
              ],
            ),

            const SizedBox(height: 12),

            // 4. زر اعتماد الإعدام
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.dangerRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                onPressed: state.isSubmitting
                    ? null
                    : () => _openApproveDialog(context, item),
                icon: const Icon(LucideIcons.flame, size: 16),
                label: const Text(
                  'مراجعة واعتماد الإعدام',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // التبويب الثاني: سجل الإعدامات المعتمد (Server-Side Pagination)
  // ===========================================================================
  Widget _buildHistoryTab(
    BuildContext context,
    CondemnationsCubit cubit,
    CondemnationsState state,
    bool desktop,
  ) {
    if (!state.historyInitialized && state.isHistoryLoading) {
      return const ResponsiveColdStorageShimmer(
        mode: ShimmerLayoutMode.tableList,
        itemCountOverride: 5,
      );
    }

    final pageData = state.historyData.page;
    final summary = state.historyData.summary;
    final filter = state.historyFilter;
    final records = pageData.items;

    // تخطيط الموبايل: سحب للأسفل على كامل الشاشة + كروت نظيفة + AppPaginationBar
    if (!desktop) {
      return RefreshIndicator(
        onRefresh: () => cubit.loadHistory(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHistoryFiltersCard(context, cubit, filter, false),
                    const SizedBox(height: 10),
                    _buildHistorySummaryRow(cubit, summary, false),
                    if (state.isHistoryLoading) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(minHeight: 2.5),
                    ],
                  ],
                ),
              ),
            ),
            if (records.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(
                  title: 'لا توجد سجلات إعدام مطابقة',
                  subtitle: filter.hasActiveFilters
                      ? 'جرّب تغيير نطاق التاريخ أو الجهة أو كلمة البحث.'
                      : 'أي إعدام يتم اعتماده سيظهر هنا بالتفاصيل الكاملة.',
                  icon: LucideIcons.searchX,
                  iconColor: _kCondMuted,
                  onClear: filter.hasActiveFilters
                      ? () => _clearHistoryFilters(cubit)
                      : null,
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: EdgeInsets.only(
                        bottom: i == records.length - 1 ? 0 : 10,
                      ),
                      child: _HistoryMobileCard(record: records[i]),
                    ),
                    childCount: records.length,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                sliver: SliverToBoxAdapter(
                  child: AppPaginationBar(
                    pageData: pageData,
                    isLoading: state.isHistoryLoading,
                    pageSizeOptions: const [15, 20, 50],
                    onPageChanged: cubit.goToHistoryPage,
                    onPageSizeChanged: cubit.changeHistoryPageSize,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // تخطيط الكمبيوتر: فلاتر + شريط ملخص + جدول AppProDataTable ممتد + ترقيم صفحات
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHistoryFiltersCard(context, cubit, filter, true),
          const SizedBox(height: 12),
          _buildHistorySummaryRow(cubit, summary, true),
          if (state.isHistoryLoading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2.5),
          ],
          const SizedBox(height: 10),
          Expanded(
            child: records.isEmpty
                ? _buildEmptyState(
                    title: 'لا توجد سجلات إعدام مطابقة',
                    subtitle: filter.hasActiveFilters
                        ? 'جرّب تغيير نطاق التاريخ أو الجهة أو كلمة البحث.'
                        : 'أي إعدام يتم اعتماده سيظهر هنا بالتفاصيل الكاملة.',
                    icon: LucideIcons.searchX,
                    iconColor: _kCondMuted,
                    onClear: filter.hasActiveFilters
                        ? () => _clearHistoryFilters(cubit)
                        : null,
                  )
                : _buildDesktopHistoryTable(context, records, summary),
          ),
          if (pageData.totalCount > 0) ...[
            const SizedBox(height: 10),
            AppPaginationBar(
              pageData: pageData,
              isLoading: state.isHistoryLoading,
              pageSizeOptions: const [15, 20, 50],
              onPageChanged: cubit.goToHistoryPage,
              onPageSizeChanged: cubit.changeHistoryPageSize,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistorySummaryRow(
    CondemnationsCubit cubit,
    CondemnationHistorySummaryEntity summary,
    bool desktop,
  ) {
    return Row(
      children: [
        _miniBadge('${summary.totalRecords} عملية إعدام', AppColors.dangerRed),
        const SizedBox(width: 6),
        if (summary.totalRecords > 0)
          Flexible(
            child: _miniBadge(
              summary.totalsByUnitSummary,
              AppColors.primaryNavy,
            ),
          ),
        const Spacer(),
        _buildPdfButton(
          enabled: summary.totalRecords > 0 && !_isExportingPdf,
          desktop: desktop,
          onPressed: () => _exportHistoryPdf(cubit),
        ),
      ],
    );
  }

  Widget _buildHistoryFiltersCard(
    BuildContext context,
    CondemnationsCubit cubit,
    CondemnationHistoryFilter filter,
    bool desktop,
  ) {
    final searchField = ValueListenableBuilder<TextEditingValue>(
      valueListenable: _historySearchCtrl,
      builder: (_, val, _) => TextField(
        controller: _historySearchCtrl,
        onChanged: _onHistorySearchChanged,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'بحث بالصنف، الموقع، البالتة، السبب أو المعتمد',
          hintStyle: const TextStyle(fontSize: 12.5),
          prefixIcon: const Icon(LucideIcons.search, size: 17),
          suffixIcon: val.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _historySearchCtrl.clear();
                    _onHistorySearchChanged('');
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
            borderSide: const BorderSide(color: _kCondBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: _kCondBorder),
          ),
        ),
      ),
    );

    Widget sourceChip(String label, String? value) {
      final selected = filter.source == value;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        selectedColor: AppColors.primaryNavy,
        backgroundColor: const Color(0xFFF8FAFC),
        side: BorderSide(color: selected ? AppColors.primaryNavy : _kCondBorder),
        labelStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: selected ? Colors.white : AppColors.primaryNavy,
        ),
        onSelected: (_) => cubit.updateHistoryFilter(
          filter.copyWith(source: value, clearSource: value == null),
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
        color: active ? AppColors.zoneC2Blue : _kCondMuted,
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
        side: BorderSide(color: active ? AppColors.zoneC2Blue : _kCondBorder),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    return Container(
      padding: EdgeInsets.all(desktop ? 14 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kCondBorder),
      ),
      child: desktop
          ? Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 10),
                sourceChip('الكل', null),
                const SizedBox(width: 6),
                sourceChip('الإنتاج', 'production'),
                const SizedBox(width: 6),
                sourceChip('فحص الجودة', 'quality_inspection'),
                const SizedBox(width: 10),
                dateBtn(
                  label: filter.fromDate == null
                      ? 'من تاريخ'
                      : _fmtCondDate(filter.fromDate!),
                  icon: LucideIcons.calendarDays,
                  active: filter.fromDate != null,
                  onTap: () => _pickHistoryDate(context, cubit, filter, true),
                ),
                const SizedBox(width: 8),
                dateBtn(
                  label: filter.toDate == null
                      ? 'إلى تاريخ'
                      : _fmtCondDate(filter.toDate!),
                  icon: LucideIcons.calendarCheck,
                  active: filter.toDate != null,
                  onTap: () => _pickHistoryDate(context, cubit, filter, false),
                ),
                if (filter.hasActiveFilters) ...[
                  const SizedBox(width: 6),
                  TextButton.icon(
                    onPressed: () => _clearHistoryFilters(cubit),
                    icon: const Icon(LucideIcons.rotateCcw, size: 14),
                    label: const Text('مسح', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: dateBtn(
                        label: filter.fromDate == null
                            ? 'من تاريخ'
                            : _fmtCondDate(filter.fromDate!),
                        icon: LucideIcons.calendarDays,
                        active: filter.fromDate != null,
                        onTap: () =>
                            _pickHistoryDate(context, cubit, filter, true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: dateBtn(
                        label: filter.toDate == null
                            ? 'إلى تاريخ'
                            : _fmtCondDate(filter.toDate!),
                        icon: LucideIcons.calendarCheck,
                        active: filter.toDate != null,
                        onTap: () =>
                            _pickHistoryDate(context, cubit, filter, false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    sourceChip('الكل', null),
                    const SizedBox(width: 6),
                    sourceChip('الإنتاج', 'production'),
                    const SizedBox(width: 6),
                    sourceChip('الجودة', 'quality_inspection'),
                    const Spacer(),
                    if (filter.hasActiveFilters)
                      IconButton.outlined(
                        tooltip: 'مسح الفلاتر',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _clearHistoryFilters(cubit),
                        icon: const Icon(LucideIcons.rotateCcw, size: 15),
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildDesktopHistoryTable(
    BuildContext context,
    List<CondemnationHistoryRecordEntity> records,
    CondemnationHistorySummaryEntity summary,
  ) {
    return AppProDataTable<CondemnationHistoryRecordEntity>(
      items: records,
      expandHeight: true,
      minTableWidth: 960,
      footerLabel:
          'إجمالي سجلات الإعدام المطابقة: ${summary.totalRecords} عملية (${summary.totalsByUnitSummary})',
      onRowTap: (rec) => _showHistoryDetailsDialog(context, rec),
      columns: [
        AppProTableColumn(
          label: 'التاريخ والوقت',
          fixedWidth: 132,
          cellBuilder: (_, r, _) => Text(
            _fmtCondDateTime(r.createdAt),
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontSize: 11.5,
              color: _kCondMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        AppProTableColumn(
          label: 'الصنف والبالتة',
          flex: 3,
          cellBuilder: (_, r, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                r.itemName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
              ),
              Text(
                '${r.palletReference} • انتهاء: ${_fmtCondDate(r.expiryDate)}',
                style: const TextStyle(fontSize: 10.5, color: _kCondMuted),
              ),
            ],
          ),
        ),
        AppProTableColumn(
          label: 'الكمية المعدمة',
          fixedWidth: 116,
          alignment: Alignment.center,
          cellBuilder: (_, r, _) => Text(
            '${_fmtCondQty(r.condemnedQuantity)} ${r.unitArLabel}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.dangerRed,
            ),
          ),
        ),
        AppProTableColumn(
          label: 'الموقع',
          fixedWidth: 112,
          alignment: Alignment.center,
          cellBuilder: (_, r, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              r.slotCode,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryNavy,
              ),
            ),
          ),
        ),
        AppProTableColumn(
          label: 'السبب',
          flex: 2,
          cellBuilder: (_, r, _) => Text(
            r.reason,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        AppProTableColumn(
          label: 'المعتمد والجهة',
          flex: 2,
          cellBuilder: (_, r, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                r.approvedByName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
              ),
              Text(
                r.sourceArLabel,
                style: const TextStyle(fontSize: 10.5, color: _kCondMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showHistoryDetailsDialog(
    BuildContext context,
    CondemnationHistoryRecordEntity rec,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              const Icon(LucideIcons.flame, color: AppColors.dangerRed),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec.itemName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    Text(
                      '${rec.palletReference} • الموقع: ${rec.slotCode}',
                      style: const TextStyle(fontSize: 11.5, color: _kCondMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(LucideIcons.x, size: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: AppColors.dangerRed.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'الكمية المعدمة:',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _kCondMuted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_fmtCondQty(rec.condemnedQuantity)} ${rec.unitArLabel}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.dangerRed,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kCondBorder),
                  ),
                  child: Text(
                    'السبب: ${rec.reason}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 7,
                  children: [
                    _metaTag(LucideIcons.userCheck, rec.approvedByName),
                    _metaTag(LucideIcons.building2, rec.sourceArLabel),
                    _metaTag(
                      LucideIcons.calendar,
                      'إنتاج: ${_fmtCondDate(rec.productionDate)}',
                    ),
                    _metaTag(
                      LucideIcons.calendarClock,
                      'انتهاء: ${_fmtCondDate(rec.expiryDate)}',
                    ),
                    _metaTag(LucideIcons.clock3, _fmtCondDateTime(rec.createdAt)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfButton({
    required bool enabled,
    required bool desktop,
    required VoidCallback onPressed,
  }) {
    return FilledButton.icon(
      onPressed: enabled ? onPressed : null,
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

  Widget _miniBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.11),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    ),
  );

  Widget _metaTag(IconData icon, String text, {Color? highlightColor}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12.5, color: highlightColor ?? _kCondMuted),
      const SizedBox(width: 4),
      Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: highlightColor != null ? FontWeight.w800 : FontWeight.w600,
          color: highlightColor ?? _kCondMuted,
        ),
      ),
    ],
  );

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    VoidCallback? onClear,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: _kCondMuted),
          ),
          if (onClear != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(LucideIcons.rotateCcw, size: 15),
              label: const Text('مسح الفلاتر'),
            ),
          ],
        ],
      ),
    ),
  );
}

// =============================================================================
// كارت موبايل نظيف لسجل الإعدامات المعتمد
// =============================================================================
class _HistoryMobileCard extends StatelessWidget {
  final CondemnationHistoryRecordEntity record;

  const _HistoryMobileCard({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCondBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.dangerRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    LucideIcons.trash2,
                    size: 18,
                    color: AppColors.dangerRed,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.itemName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${record.palletReference} • ${record.slotCode}',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _kCondMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.dangerRed,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${_fmtCondQty(record.condemnedQuantity)} ${record.unitArLabel}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.dangerRed.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.fileText,
                    size: 13.5,
                    color: AppColors.dangerRed,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'السبب: ${record.reason}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 18, color: Color(0xFFEDF1F5)),
            Row(
              children: [
                const Icon(
                  LucideIcons.userCheck,
                  size: 12.5,
                  color: _kCondMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${record.approvedByName} • ${record.sourceArLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ),
                const Icon(LucideIcons.clock3, size: 12, color: _kCondMuted),
                const SizedBox(width: 4),
                Text(
                  _fmtCondDateTime(record.createdAt),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: _kCondMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// نافذة اعتماد الإعدام الآمنة (تُغلق Controllers تلقائياً مع تحقق فوري)
// =============================================================================
class _CondemnationApprovalResult {
  final double quantity;
  final String reason;

  const _CondemnationApprovalResult({
    required this.quantity,
    required this.reason,
  });
}

class _ApproveCondemnationDialog extends StatefulWidget {
  final CondemnationAlertItemEntity item;

  const _ApproveCondemnationDialog({required this.item});

  @override
  State<_ApproveCondemnationDialog> createState() =>
      _ApproveCondemnationDialogState();
}

class _ApproveCondemnationDialogState extends State<_ApproveCondemnationDialog> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _reasonCtrl;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: _fmtCondQty(widget.item.quantity));
    _reasonCtrl = TextEditingController(
      text: widget.item.isExpired
          ? 'إعدام لانتهاء الصلاحية'
          : 'إعدام لاقتراب انتهاء الصلاحية (${widget.item.daysUntilExpiry} يوم متبقي)',
    );
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final qty = double.tryParse(_qtyCtrl.text.trim());
    if (qty == null || qty <= 0 || qty > widget.item.quantity) {
      setState(
        () => _validationError =
            'أدخل كمية صحيحة بين 1 و ${_fmtCondQty(widget.item.quantity)}.',
      );
      return;
    }

    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      setState(() => _validationError = 'يرجى كتابة سبب الإعدام.');
      return;
    }
    if (reason.length > 500) {
      setState(
        () => _validationError = 'سبب الإعدام أطول من الحد المسموح (500 حرف).',
      );
      return;
    }

    Navigator.of(
      context,
    ).pop(_CondemnationApprovalResult(quantity: qty, reason: reason));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(LucideIcons.flame, color: AppColors.dangerRed),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'اعتماد إعدام: ${item.itemName}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryNavy,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kCondBorder),
                  ),
                  child: Text(
                    'الموقع: [${item.slotCode}] • المتاح: ${_fmtCondQty(item.quantity)} ${item.unitArLabel}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) {
                    if (_validationError != null) {
                      setState(() => _validationError = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'الكمية المراد إعدامها (${item.unitArLabel})',
                    prefixIcon: const Icon(LucideIcons.hash, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reasonCtrl,
                  maxLines: 2,
                  onChanged: (_) {
                    if (_validationError != null) {
                      setState(() => _validationError = null);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'سبب الإعدام (يظهر في السجل والتقرير)',
                    prefixIcon: Icon(LucideIcons.fileText, size: 18),
                  ),
                ),
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
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerRed),
            onPressed: _confirm,
            icon: const Icon(LucideIcons.flame, size: 16),
            label: const Text('تأكيد الإعدام'),
          ),
        ],
      ),
    );
  }
}
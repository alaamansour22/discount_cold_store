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
import '../../domain/entities/rack_transfer_entities.dart';
import '../cubit/rack_transfer_cubit.dart';
import '../cubit/rack_transfer_state.dart';

const _kHistBorder = Color(0xFFE3E8EF);
const _kHistMuted = Color(0xFF687386);

String _fmtHistQty(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);

String _fmtHistDate(DateTime d) => intl.DateFormat('yyyy-MM-dd').format(d);

String _fmtHistDateTime(DateTime d) =>
    intl.DateFormat('yyyy-MM-dd  HH:mm').format(d);

/// شاشة سجل تحويلات الراكات (البحث والفلترة والباجينيشن بالكامل داخل PostgreSQL)
class RackTransferHistoryView extends StatefulWidget {
  const RackTransferHistoryView({super.key});

  @override
  State<RackTransferHistoryView> createState() =>
      _RackTransferHistoryViewState();
}

class _RackTransferHistoryViewState extends State<RackTransferHistoryView> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  bool _isExportingPdf = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RackTransferCubit>().ensureHistoryLoaded();
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
      final cubit = context.read<RackTransferCubit>();
      cubit.updateHistoryFilter(
        cubit.state.historyFilter.copyWith(search: value.trim()),
      );
    });
  }

  void _clearAllFilters(RackTransferCubit cubit) {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    cubit.clearHistoryFilters();
  }

  Future<void> _pickDate(
    BuildContext context,
    RackTransferCubit cubit,
    RackTransferHistoryFilter filter,
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

  Future<void> _exportPdf(RackTransferCubit cubit) async {
    if (_isExportingPdf) {
      return;
    }
    setState(() => _isExportingPdf = true);

    try {
      final exported = await cubit.fetchHistoryForExport();
      final items = exported.page.items;
      final total = exported.summary.totalTransfers;

      final rows = items
          .map(
            (h) => <String>[
              _fmtHistDateTime(h.createdAt),
              h.performedByName,
              h.notes,
              h.toSlotCode,
              h.fromSlotCode,
              '${_fmtHistQty(h.quantity)} ${h.unitArLabel}',
              h.palletReference,
              h.itemName,
            ],
          )
          .toList();

      await ColdStoragePdfService.printCustomTableReport(
        reportTitle: 'سجل تحويلات الراكات — ثلاجة المخفض',
        reportSubtitle: 'إجمالي حركات النقل المطابقة: $total حركة تحويل',
        headers: const [
          'التاريخ والوقت',
          'بواسطة',
          'الملاحظات',
          'إلى موقع',
          'من موقع',
          'الكمية',
          'كود البالتة',
          'الصنف',
        ],
        rows: rows,
        fileName: 'rack_transfers_history.pdf',
        headerColor: PdfColors.teal900,
        summaryMetrics: {'إجمالي التحويلات': '$total'},
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RackTransferCubit, RackTransferState>(
      buildWhen: (prev, curr) =>
          prev.isHistoryLoading != curr.isHistoryLoading ||
          prev.historyInitialized != curr.historyInitialized ||
          prev.historyData != curr.historyData ||
          prev.historyFilter != curr.historyFilter,
      builder: (context, state) {
        if (!state.historyInitialized && state.isHistoryLoading) {
          return const ResponsiveColdStorageShimmer(
            mode: ShimmerLayoutMode.tableList,
          );
        }

        final cubit = context.read<RackTransferCubit>();
        final pageData = state.historyData.page;
        final summary = state.historyData.summary;
        final filter = state.historyFilter;
        final rows = pageData.items;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 840;

              // تخطيط الموبايل: سحب للأسفل للتحديث + بدون عنوان مكرر ولا زر تحديث
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
                              _buildFiltersCard(context, cubit, filter, false),
                              const SizedBox(height: 10),
                              _buildMobileSummaryRow(cubit, summary),
                              if (state.isHistoryLoading) ...[
                                const SizedBox(height: 8),
                                const LinearProgressIndicator(minHeight: 2.5),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (rows.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(cubit, filter),
                        )
                      else ...[
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: i == rows.length - 1 ? 0 : 10,
                                ),
                                child: _HistoryMobileCard(history: rows[i]),
                              ),
                              childCount: rows.length,
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
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

              // تخطيط الكمبيوتر: رأس كامل + جدول احترافي ممتد + ترقيم صفحات
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDesktopHeader(cubit, summary),
                    const SizedBox(height: 12),
                    _buildFiltersCard(context, cubit, filter, true),
                    if (state.isHistoryLoading) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(minHeight: 2.5),
                    ],
                    const SizedBox(height: 12),
                    Expanded(
                      child: rows.isEmpty
                          ? _buildEmptyState(cubit, filter)
                          : _buildHistoryTable(rows, summary.totalTransfers),
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
            },
          ),
        );
      },
    );
  }

  /// شريط الموبايل الخفيف: العدد + تصدير PDF فقط (التحديث عبر السحب للأسفل)
  Widget _buildMobileSummaryRow(
    RackTransferCubit cubit,
    RackTransferHistorySummaryEntity summary,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryNavy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.arrowLeftRight,
                size: 13,
                color: AppColors.primaryNavy,
              ),
              const SizedBox(width: 5),
              Text(
                '${summary.totalTransfers} عملية تحويل',
                style: const TextStyle(
                  color: AppColors.primaryNavy,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        _buildPdfButton(cubit, summary.totalTransfers, desktop: false),
      ],
    );
  }

  /// ترويسة الكمبيوتر الكاملة
  Widget _buildDesktopHeader(
    RackTransferCubit cubit,
    RackTransferHistorySummaryEntity summary,
  ) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سجل تحويلات الراكات',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryNavy,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'متابعة حركات نقل البالتات بين مواقع التخزين',
                style: TextStyle(fontSize: 12, color: _kHistMuted),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primaryNavy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            '${summary.totalTransfers} عملية',
            style: const TextStyle(
              color: AppColors.primaryNavy,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'تحديث',
          onPressed: () => cubit.loadHistory(),
          icon: const Icon(LucideIcons.refreshCw, size: 16),
        ),
        const SizedBox(width: 8),
        _buildPdfButton(cubit, summary.totalTransfers, desktop: true),
      ],
    );
  }

  Widget _buildPdfButton(
    RackTransferCubit cubit,
    int totalTransfers, {
    required bool desktop,
  }) {
    return FilledButton.icon(
      onPressed: (totalTransfers == 0 || _isExportingPdf)
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

  Widget _buildFiltersCard(
    BuildContext context,
    RackTransferCubit cubit,
    RackTransferHistoryFilter filter,
    bool desktop,
  ) {
    final searchField = ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchCtrl,
      builder: (_, val, _) => TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'بحث بالصنف، البالتة، الراك أو المستخدم',
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
            borderSide: const BorderSide(color: _kHistBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: _kHistBorder),
          ),
        ),
      ),
    );

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
        color: active ? AppColors.zoneC2Blue : _kHistMuted,
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
        side: BorderSide(color: active ? AppColors.zoneC2Blue : _kHistBorder),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    return Container(
      padding: EdgeInsets.all(desktop ? 14 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kHistBorder),
      ),
      child: desktop
          ? Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 10),
                dateBtn(
                  label: filter.fromDate == null
                      ? 'من تاريخ'
                      : _fmtHistDate(filter.fromDate!),
                  icon: LucideIcons.calendarDays,
                  active: filter.fromDate != null,
                  onTap: () => _pickDate(context, cubit, filter, true),
                ),
                const SizedBox(width: 8),
                dateBtn(
                  label: filter.toDate == null
                      ? 'إلى تاريخ'
                      : _fmtHistDate(filter.toDate!),
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
                            : _fmtHistDate(filter.fromDate!),
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
                            : _fmtHistDate(filter.toDate!),
                        icon: LucideIcons.calendarCheck,
                        active: filter.toDate != null,
                        onTap: () => _pickDate(context, cubit, filter, false),
                      ),
                    ),
                    if (filter.hasActiveFilters) ...[
                      const SizedBox(width: 6),
                      IconButton.outlined(
                        tooltip: 'مسح الفلاتر',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _clearAllFilters(cubit),
                        icon: const Icon(LucideIcons.rotateCcw, size: 15),
                      ),
                    ],
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildHistoryTable(
    List<RackTransferHistoryEntity> rows,
    int totalTransfers,
  ) {
    return AppProDataTable<RackTransferHistoryEntity>(
      items: rows,
      expandHeight: true,
      minTableWidth: 920,
      footerLabel: 'إجمالي التحويلات المطابقة: $totalTransfers حركة تحويل',
      columns: [
        AppProTableColumn(
          label: 'الصنف والبالتة',
          flex: 3,
          cellBuilder: (_, h, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                h.itemName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
              ),
              Text(
                h.notes.trim().isNotEmpty
                    ? '${h.palletReference} • ${h.notes}'
                    : h.palletReference,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: _kHistMuted),
              ),
            ],
          ),
        ),
        AppProTableColumn(
          label: 'الكمية',
          fixedWidth: 112,
          alignment: Alignment.center,
          cellBuilder: (_, h, _) => Text(
            '${_fmtHistQty(h.quantity)} ${h.unitArLabel}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.primaryNavy,
            ),
          ),
        ),
        AppProTableColumn(
          label: 'من موقع',
          fixedWidth: 120,
          alignment: Alignment.center,
          cellBuilder: (_, h, _) =>
              _slotCodeBadge(h.fromSlotCode, AppColors.dangerRed),
        ),
        AppProTableColumn(
          label: 'إلى موقع',
          fixedWidth: 120,
          alignment: Alignment.center,
          cellBuilder: (_, h, _) =>
              _slotCodeBadge(h.toSlotCode, AppColors.successGreen),
        ),
        AppProTableColumn(
          label: 'بواسطة',
          flex: 2,
          cellBuilder: (_, h, _) => Text(
            h.performedByName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryNavy,
            ),
          ),
        ),
        AppProTableColumn(
          label: 'التاريخ والوقت',
          fixedWidth: 136,
          alignment: AlignmentDirectional.centerEnd,
          cellBuilder: (_, h, _) => Text(
            _fmtHistDateTime(h.createdAt),
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontSize: 11.5,
              color: _kHistMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _slotCodeBadge(String code, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      code,
      textDirection: TextDirection.ltr,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w800,
        fontSize: 11.5,
      ),
    ),
  );

  Widget _buildEmptyState(
    RackTransferCubit cubit,
    RackTransferHistoryFilter filter,
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
              LucideIcons.history,
              size: 26,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'لا توجد عمليات تحويل مطابقة',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'جرّب تغيير البحث أو نطاق التاريخ المختار',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _kHistMuted),
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

/// كارت موبايل احترافي ومنظّم لسجل التحويلات
class _HistoryMobileCard extends StatelessWidget {
  final RackTransferHistoryEntity history;

  const _HistoryMobileCard({required this.history});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kHistBorder),
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
            // 1. الصف العلوي: أيقونة + اسم الصنف + كود البالتة + شارة الكمية
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.zoneC3Teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    LucideIcons.arrowLeftRight,
                    size: 18,
                    color: AppColors.zoneC3Teal,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        history.itemName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryNavy,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          history.palletReference,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: _kHistMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryNavy,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_fmtHistQty(history.quantity)} ${history.unitArLabel}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 2. مسار النقل (من ⬅ إلى) بتوازن 50/50 واضح
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE6ECF4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _routeTile(
                      label: 'من موقع',
                      code: history.fromSlotCode,
                      color: AppColors.dangerRed,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: _kHistBorder),
                    ),
                    child: const Icon(
                      LucideIcons.arrowLeft,
                      size: 14,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  Expanded(
                    child: _routeTile(
                      label: 'إلى موقع',
                      code: history.toSlotCode,
                      color: AppColors.successGreen,
                    ),
                  ),
                ],
              ),
            ),

            // 3. الملاحظة إن وُجدت
            if (history.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 9),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.fileText,
                      size: 13,
                      color: _kHistMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        history.notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: _kHistMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Divider(height: 18, color: Color(0xFFEDF1F5)),

            // 4. التذييل: المنفذ + التوقيت
            Row(
              children: [
                const Icon(
                  LucideIcons.userRound,
                  size: 13,
                  color: _kHistMuted,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    history.performedByName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ),
                const Icon(LucideIcons.clock3, size: 12.5, color: _kHistMuted),
                const SizedBox(width: 4),
                Text(
                  _fmtHistDateTime(history.createdAt),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kHistMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _routeTile({
    required String label,
    required String code,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            code,
            textDirection: TextDirection.ltr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
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
import '../../domain/entities/deleted_record_entity.dart';
import '../cubit/deleted_records_cubit.dart';

class DeletedRecordsPage extends StatefulWidget {
  const DeletedRecordsPage({super.key});

  @override
  State<DeletedRecordsPage> createState() => _DeletedRecordsPageState();
}

class _DeletedRecordsPageState extends State<DeletedRecordsPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _isExportingPdf = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) => intl.DateFormat('yyyy-MM-dd').format(d);

  String _fmtDateTime(DateTime d) =>
      intl.DateFormat('yyyy-MM-dd  HH:mm').format(d);

  String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  Color _kindColor(DeletedRecordEntity r) =>
      r.isFullPallet ? AppColors.dangerRed : AppColors.warningAmber;

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      final cubit = context.read<DeletedRecordsCubit>();
      cubit.updateFilter(cubit.state.filter.copyWith(search: value.trim()));
    });
  }

  void _clearAllFilters(DeletedRecordsCubit cubit) {
    _searchDebounce?.cancel();
    _searchController.clear();
    cubit.clearFilters();
  }

  Future<void> _exportPdf(DeletedRecordsCubit cubit) async {
    if (_isExportingPdf) {
      return;
    }
    setState(() => _isExportingPdf = true);

    try {
      final exported = await cubit.fetchForExport();
      final records = exported.page.items;
      final summary = exported.summary;

      final rows = records.map((r) {
        final itemsText = r.items.isEmpty
            ? '—'
            : r.items
                  .map(
                    (i) =>
                        '${i.itemName} (${_fmtQty(i.quantity)} ${i.unit.arLabel})',
                  )
                  .join(' | ');
        return <String>[
          r.reason,
          r.deletedByName,
          r.slotCode,
          itemsText,
          r.palletReference,
          r.actionKind.arLabel,
          _fmtDateTime(r.deletedAt),
        ];
      }).toList();

      await ColdStoragePdfService.printCustomTableReport(
        reportTitle: 'سجل المحذوفات (التسكين الخاطئ) — ثلاجة المخفض',
        reportSubtitle: 'إجمالي عمليات الحذف المسجلة: ${summary.totalDeletions}',
        headers: const [
          'سبب الحذف',
          'المنفذ',
          'الموقع',
          'الأصناف والكميات',
          'رقم البالتة',
          'نوع الحذف',
          'التاريخ والوقت',
        ],
        rows: rows,
        fileName: 'deleted_records_audit_log.pdf',
        headerColor: PdfColors.red900,
        summaryMetrics: {
          'إجمالي السجلات': '${summary.totalDeletions}',
          'بالتات محذوفة': '${summary.fullPalletCount}',
          'أصناف محذوفة': '${summary.singleItemCount}',
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

  Future<void> _pickDate(
    BuildContext context,
    DeletedRecordsCubit cubit,
    DeletedRecordsFilter filter,
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

    await cubit.updateFilter(
      filter.copyWith(fromDate: nextFrom, toDate: nextTo),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DeletedRecordsCubit, DeletedRecordsState>(
      listenWhen: (prev, curr) =>
          prev.failure != curr.failure && curr.failure != null,
      listener: (context, state) {
        final isOffstage =
            context.findAncestorWidgetOfExactType<Offstage>()?.offstage ??
            false;
        if (isOffstage || state.failure == null) {
          return;
        }
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(state.failure!.message),
              backgroundColor: AppColors.dangerRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
      },
      builder: (context, state) {
        if (!state.initialized && state.isLoading) {
          return const ResponsiveColdStorageShimmer(
            mode: ShimmerLayoutMode.tableList,
          );
        }

        final cubit = context.read<DeletedRecordsCubit>();
        final pageData = state.data.page;
        final summary = state.data.summary;
        final records = pageData.items;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 24 : 14,
                  vertical: isWide ? 20 : 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFiltersCard(context, cubit, state.filter, isWide),
                    const SizedBox(height: 12),
                    _buildHeaderRow(summary, cubit, isWide),
                    if (state.isLoading) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(minHeight: 2.5),
                    ],
                    const SizedBox(height: 10),
                    Expanded(
                      child: records.isEmpty
                          ? RefreshIndicator(
                              onRefresh: () => cubit.loadRecords(),
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height: 260,
                                    child: _buildEmptyState(
                                      cubit,
                                      state.filter,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : isWide
                          ? _buildDesktopTable(context, records, summary)
                          : RefreshIndicator(
                              onRefresh: () => cubit.loadRecords(),
                              child: _buildMobileList(records),
                            ),
                    ),
                    if (pageData.totalCount > 0) ...[
                      const SizedBox(height: 10),
                      AppPaginationBar(
                        pageData: pageData,
                        isLoading: state.isLoading,
                        pageSizeOptions: const [15, 20, 50],
                        onPageChanged: cubit.goToPage,
                        onPageSizeChanged: cubit.changePageSize,
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

  Widget _buildFiltersCard(
    BuildContext context,
    DeletedRecordsCubit cubit,
    DeletedRecordsFilter filter,
    bool isWide,
  ) {
    return Container(
      padding: EdgeInsets.all(isWide ? 14 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (_, val, _) => TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText:
                    'ابحث بالصنف أو رقم البالتة أو الموقع أو السبب أو المنفذ',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                suffixIcon: val.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(LucideIcons.x, size: 17),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      ),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _kindChip(
                label: 'الكل',
                selected: filter.kind == null,
                onTap: () => cubit.updateFilter(filter.copyWith(clearKind: true)),
              ),
              _kindChip(
                label: 'بالتة كاملة',
                selected: filter.kind == DeletedActionKind.fullPallet,
                onTap: () => cubit.updateFilter(
                  filter.copyWith(kind: DeletedActionKind.fullPallet),
                ),
              ),
              _kindChip(
                label: 'صنف محدد',
                selected: filter.kind == DeletedActionKind.singleItem,
                onTap: () => cubit.updateFilter(
                  filter.copyWith(kind: DeletedActionKind.singleItem),
                ),
              ),
              _dateFilterButton(
                label: filter.fromDate == null
                    ? 'من تاريخ'
                    : _fmtDate(filter.fromDate!),
                icon: LucideIcons.calendarDays,
                onTap: () => _pickDate(context, cubit, filter, true),
              ),
              _dateFilterButton(
                label: filter.toDate == null
                    ? 'إلى تاريخ'
                    : _fmtDate(filter.toDate!),
                icon: LucideIcons.calendarCheck,
                onTap: () => _pickDate(context, cubit, filter, false),
              ),
              if (filter.hasActiveFilters)
                TextButton.icon(
                  onPressed: () => _clearAllFilters(cubit),
                  icon: const Icon(LucideIcons.rotateCcw, size: 14),
                  label: const Text('مسح', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateFilterButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: AppColors.primaryNavy,
        side: const BorderSide(color: AppColors.borderLight),
      ),
    );
  }

  Widget _kindChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      selectedColor: AppColors.dangerRed,
      backgroundColor: const Color(0xFFF8FAFC),
      side: BorderSide(
        color: selected ? AppColors.dangerRed : AppColors.borderLight,
      ),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: selected ? Colors.white : AppColors.primaryNavy,
      ),
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildHeaderRow(
    DeletedRecordsSummaryEntity summary,
    DeletedRecordsCubit cubit,
    bool isWide,
  ) {
    return Row(
      children: [
        const Icon(LucideIcons.trash2, size: 18, color: AppColors.dangerRed),
        const SizedBox(width: 7),
        const Text(
          'سجل المحذوفات',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: AppColors.primaryNavy,
          ),
        ),
        const SizedBox(width: 8),
        _headerBadge('${summary.totalDeletions}', AppColors.dangerRed),
        if (isWide) ...[
          const SizedBox(width: 6),
          _headerBadge(
            '${summary.fullPalletCount} بالتة',
            AppColors.dangerRed,
          ),
          const SizedBox(width: 6),
          _headerBadge(
            '${summary.singleItemCount} صنف',
            AppColors.warningAmber,
          ),
        ],
        const Spacer(),
        IconButton.filledTonal(
          tooltip: 'تحديث',
          onPressed: () => cubit.loadRecords(),
          icon: const Icon(LucideIcons.refreshCw, size: 16),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: (summary.totalDeletions == 0 || _isExportingPdf)
              ? null
              : () => _exportPdf(cubit),
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
            _isExportingPdf ? 'تجهيز...' : (isWide ? 'تصدير PDF' : 'PDF'),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryNavy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerBadge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    ),
  );

  Widget _buildMobileList(List<DeletedRecordEntity> records) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: records.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) => _recordCard(records[index]),
    );
  }

  Widget _recordCard(DeletedRecordEntity record) {
    final badgeColor = _kindColor(record);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _actionBadge(record, badgeColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  record.palletReference,
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
          const SizedBox(height: 10),
          if (record.items.isNotEmpty) _itemsListBox(record.items),
          const SizedBox(height: 9),
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
                  size: 14,
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
          const Divider(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _metaItem(LucideIcons.mapPin, record.slotCode),
              _metaItem(LucideIcons.userRound, record.deletedByName),
              _metaItem(LucideIcons.clock3, _fmtDateTime(record.deletedAt)),
              if (record.sourceEntity != null)
                _metaItem(LucideIcons.building2, record.sourceEntity!.arLabel),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBadge(DeletedRecordEntity record, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            record.isFullPallet ? LucideIcons.packageX : LucideIcons.trash2,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              record.actionKind.arLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemsListBox(List<DeletedItemSnapshot> items) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          return Padding(
            padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 6),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.package,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    item.itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_fmtQty(item.quantity)} ${item.unit.arLabel}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.dangerRed,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _metaItem(IconData icon, String text) => Row(
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

  Widget _buildDesktopTable(
    BuildContext context,
    List<DeletedRecordEntity> records,
    DeletedRecordsSummaryEntity summary,
  ) {
    return AppProDataTable<DeletedRecordEntity>(
      items: records,
      expandHeight: true,
      minTableWidth: 940,
      footerLabel:
          'إجمالي السجلات المحذوفة: ${summary.totalDeletions} عملية (${summary.fullPalletCount} بالتة • ${summary.singleItemCount} صنف)',
      onRowTap: (record) => _showRecordDetailsDialog(context, record),
      columns: [
        AppProTableColumn(
          label: 'التاريخ والوقت',
          fixedWidth: 132,
          cellBuilder: (_, r, _) => Text(
            _fmtDateTime(r.deletedAt),
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        AppProTableColumn(
          label: 'نوع الحذف',
          fixedWidth: 132,
          cellBuilder: (_, r, _) => _actionBadge(r, _kindColor(r)),
        ),
        AppProTableColumn(
          label: 'رقم البالتة',
          fixedWidth: 142,
          cellBuilder: (_, r, _) => Text(
            r.palletReference,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: AppColors.primaryNavy,
            ),
          ),
        ),
        AppProTableColumn(
          label: 'الأصناف المحذوفة',
          flex: 3,
          cellBuilder: (_, r, _) {
            if (r.items.isEmpty) {
              return const Text('—');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: r.items.asMap().entries.map((entry) {
                final item = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key == r.items.length - 1 ? 0 : 4,
                  ),
                  child: Text(
                    '${item.itemName} (${_fmtQty(item.quantity)} ${item.unit.arLabel})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        AppProTableColumn(
          label: 'الموقع',
          fixedWidth: 108,
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
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
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
          label: 'المنفذ',
          fixedWidth: 120,
          cellBuilder: (_, r, _) => Text(
            r.deletedByName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primaryNavy,
            ),
          ),
        ),
      ],
    );
  }

  void _showRecordDetailsDialog(
    BuildContext context,
    DeletedRecordEntity record,
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
              const Icon(LucideIcons.trash2, color: AppColors.dangerRed),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.actionKind.arLabel,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    Text(
                      '${record.palletReference} • الموقع: ${record.slotCode}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
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
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (record.items.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: SingleChildScrollView(
                      child: _itemsListBox(record.items),
                    ),
                  ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.dangerRed.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'السبب: ${record.reason}',
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
                  runSpacing: 6,
                  children: [
                    _metaItem(LucideIcons.userRound, record.deletedByName),
                    _metaItem(
                      LucideIcons.clock3,
                      _fmtDateTime(record.deletedAt),
                    ),
                    if (record.sourceEntity != null)
                      _metaItem(
                        LucideIcons.building2,
                        record.sourceEntity!.arLabel,
                      ),
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

  Widget _buildEmptyState(
    DeletedRecordsCubit cubit,
    DeletedRecordsFilter filter,
  ) => Center(
    child: Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.fileSearch,
            size: 40,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 10),
          const Text(
            'لا توجد عمليات حذف مسجلة',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'أي بالتة أو صنف يتم حذفه بالخطأ سيظهر هنا بالتفاصيل والسبب.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
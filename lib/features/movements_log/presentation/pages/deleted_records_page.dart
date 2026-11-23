import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdf/pdf.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/cold_storage_pdf_service.dart';
import '../../../../core/widgets/responsive_shimmer.dart';
import '../../domain/entities/deleted_record_entity.dart';
import '../cubit/deleted_records_cubit.dart';

class DeletedRecordsPage extends StatefulWidget {
  const DeletedRecordsPage({super.key});

  @override
  State<DeletedRecordsPage> createState() => _DeletedRecordsPageState();
}

class _DeletedRecordsPageState extends State<DeletedRecordsPage> {
  final ValueNotifier<String> _searchNotifier = ValueNotifier<String>('');
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchNotifier.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) => intl.DateFormat('yyyy-MM-dd').format(d);
  String _fmtDateTime(DateTime d) =>
      intl.DateFormat('yyyy-MM-dd  HH:mm').format(d);

  String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  Future<void> _exportPdf(List<DeletedRecordEntity> records) async {
    final rows = records.map((r) {
      final itemsText = r.items.isEmpty
          ? '—'
          : r.items
                .map((i) => '${i.itemName} (${_fmtQty(i.quantity)} ${i.unit.arLabel})')
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

    final fullCount = records.where((e) => e.isFullPallet).length;
    final itemCount = records.length - fullCount;

    await ColdStoragePdfService.printCustomTableReport(
      reportTitle: 'سجل المحذوفات (التسكين الخاطئ) — ثلاجة المخفض',
      reportSubtitle: 'إجمالي عمليات الحذف المسجلة: ${records.length}',
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
        'إجمالي السجلات': '${records.length}',
        'بالتات محذوفة': '$fullCount',
        'أصناف محذوفة': '$itemCount',
      },
    );
  }

  List<DeletedRecordEntity> _filterLocal(
    List<DeletedRecordEntity> records,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return records;
    return records.where((r) {
      final matchesItems = r.items.any(
        (i) => i.itemName.toLowerCase().contains(q),
      );
      return matchesItems ||
          r.palletReference.toLowerCase().contains(q) ||
          r.slotCode.toLowerCase().contains(q) ||
          r.reason.toLowerCase().contains(q) ||
          r.deletedByName.toLowerCase().contains(q) ||
          r.actionKind.arLabel.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DeletedRecordsCubit, DeletedRecordsState>(
      listenWhen: (prev, curr) =>
          prev.failure != curr.failure && curr.failure != null,
      listener: (context, state) {
        if (state.failure == null) return;
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
        if (state.isLoading) {
          return const ResponsiveColdStorageShimmer(
            mode: ShimmerLayoutMode.tableList,
          );
        }

        final cubit = context.read<DeletedRecordsCubit>();
        return Directionality(
          textDirection: TextDirection.rtl,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final pageWidth = constraints.maxWidth > 1500
                  ? 1440.0
                  : constraints.maxWidth;

              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: pageWidth,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 24 : 14,
                      vertical: isWide ? 20 : 12,
                    ),
                    child: ValueListenableBuilder<String>(
                      valueListenable: _searchNotifier,
                      builder: (context, query, _) {
                        final filtered = _filterLocal(state.records, query);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildFiltersCard(context, cubit, state, isWide),
                            const SizedBox(height: 12),
                            _buildHeaderRow(
                              filtered,
                              cubit,
                              isWide,
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: () => cubit.loadRecords(),
                                child: filtered.isEmpty
                                    ? ListView(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        children: [
                                          SizedBox(
                                            height: 260,
                                            child: _buildEmptyState(),
                                          ),
                                        ],
                                      )
                                    : isWide
                                    ? _buildDesktopTable(filtered)
                                    : _buildMobileList(filtered),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
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
    DeletedRecordsState state,
    bool isWide,
  ) {
    final hasFilters =
        state.fromDate != null ||
        state.toDate != null ||
        state.kindFilter != null ||
        _searchNotifier.value.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(isWide ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) => _searchNotifier.value = v,
            decoration: InputDecoration(
              hintText: 'ابحث بالصنف أو رقم البالتة أو الموقع أو السبب أو المنفذ',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              suffixIcon: _searchNotifier.value.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(LucideIcons.x, size: 17),
                      onPressed: () {
                        _searchController.clear();
                        _searchNotifier.value = '';
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _kindChip(
                label: 'الكل',
                selected: state.kindFilter == null,
                onTap: () => cubit.applyFilters(
                  fromDate: state.fromDate,
                  toDate: state.toDate,
                  clearKindFilter: true,
                ),
              ),
              _kindChip(
                label: 'بالتة كاملة',
                selected: state.kindFilter == DeletedActionKind.fullPallet,
                onTap: () => cubit.applyFilters(
                  fromDate: state.fromDate,
                  toDate: state.toDate,
                  kindFilter: DeletedActionKind.fullPallet,
                ),
              ),
              _kindChip(
                label: 'صنف محدد',
                selected: state.kindFilter == DeletedActionKind.singleItem,
                onTap: () => cubit.applyFilters(
                  fromDate: state.fromDate,
                  toDate: state.toDate,
                  kindFilter: DeletedActionKind.singleItem,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDate(context, cubit, state, true),
                icon: const Icon(LucideIcons.calendarDays, size: 15),
                label: Text(
                  state.fromDate == null ? 'من تاريخ' : _fmtDate(state.fromDate!),
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.primaryNavy,
                  side: const BorderSide(color: AppColors.borderLight),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDate(context, cubit, state, false),
                icon: const Icon(LucideIcons.calendarCheck, size: 15),
                label: Text(
                  state.toDate == null ? 'إلى تاريخ' : _fmtDate(state.toDate!),
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.primaryNavy,
                  side: const BorderSide(color: AppColors.borderLight),
                ),
              ),
              if (hasFilters)
                TextButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    _searchNotifier.value = '';
                    cubit.applyFilters(
                      clearFromDate: true,
                      clearToDate: true,
                      clearKindFilter: true,
                    );
                  },
                  icon: const Icon(LucideIcons.rotateCcw, size: 14),
                  label: const Text('مسح', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
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

  Future<void> _pickDate(
    BuildContext context,
    DeletedRecordsCubit cubit,
    DeletedRecordsState state,
    bool isFrom,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? state.fromDate : state.toDate) ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    await cubit.applyFilters(
      fromDate: isFrom ? picked : state.fromDate,
      toDate: isFrom ? state.toDate : picked,
      kindFilter: state.kindFilter,
    );
  }

  Widget _buildHeaderRow(
    List<DeletedRecordEntity> records,
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.dangerRed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${records.length}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.dangerRed,
            ),
          ),
        ),
        const Spacer(),
        IconButton.filledTonal(
          tooltip: 'تحديث',
          onPressed: () => cubit.loadRecords(),
          icon: const Icon(LucideIcons.refreshCw, size: 16),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: records.isEmpty ? null : () => _exportPdf(records),
          icon: const Icon(LucideIcons.fileDown, size: 16),
          label: Text(isWide ? 'تصدير PDF' : 'PDF'),
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

  Widget _buildMobileList(List<DeletedRecordEntity> records) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 18),
      itemCount: records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) => _recordCard(records[index]),
    );
  }

  Widget _recordCard(DeletedRecordEntity record) {
    final badgeColor = record.isFullPallet
        ? AppColors.dangerRed
        : AppColors.warningAmber;

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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      record.isFullPallet
                          ? LucideIcons.packageX
                          : LucideIcons.trash2,
                      size: 13,
                      color: badgeColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      record.actionKind.arLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
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
          if (record.items.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: List.generate(record.items.length, (i) {
                  final item = record.items[i];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: i == record.items.length - 1 ? 0 : 6,
                    ),
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
            ),
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

  Widget _buildDesktopTable(List<DeletedRecordEntity> records) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF3F6FB)),
              headingTextStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryNavy,
              ),
              columns: const [
                DataColumn(label: Text('التاريخ والوقت')),
                DataColumn(label: Text('نوع الحذف')),
                DataColumn(label: Text('رقم البالتة')),
                DataColumn(label: Text('الأصناف المحذوفة')),
                DataColumn(label: Text('الموقع')),
                DataColumn(label: Text('السبب')),
                DataColumn(label: Text('المنفذ')),
              ],
              rows: records.map((r) {
                final color = r.isFullPallet
                    ? AppColors.dangerRed
                    : AppColors.warningAmber;
                final itemsSummary = r.items
                    .map(
                      (i) =>
                          '${i.itemName} (${_fmtQty(i.quantity)} ${i.unit.arLabel})',
                    )
                    .join('\n');
                return DataRow(
                  cells: [
                    DataCell(Text(_fmtDateTime(r.deletedAt))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          r.actionKind.arLabel,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(r.palletReference, textDirection: TextDirection.ltr),
                    ),
                    DataCell(
                      SizedBox(
                        width: 240,
                        child: Text(
                          itemsSummary.isEmpty ? '—' : itemsSummary,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text(r.slotCode)),
                    DataCell(
                      SizedBox(
                        width: 180,
                        child: Text(
                          r.reason,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text(r.deletedByName)),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() => Center(
    child: Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.fileSearch, size: 40, color: AppColors.textSecondary),
          SizedBox(height: 10),
          Text(
            'لا توجد عمليات حذف مسجلة',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.primaryNavy,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'أي بالتة أو صنف يتم حذفه بالخطأ سيظهر هنا بالتفاصيل والسبب.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}
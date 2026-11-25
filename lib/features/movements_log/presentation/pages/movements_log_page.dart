import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/movements_log_pdf_service.dart';
import '../../../../core/widgets/app_pagination_bar.dart';
import '../../../../core/widgets/app_pro_data_table.dart';
import '../../../../core/widgets/responsive_shimmer.dart';
import '../../../receiving/domain/entities/receiving_entities.dart';
import '../../domain/entities/movements_log_entities.dart';
import '../cubit/movements_log_cubit.dart';
import '../cubit/movements_log_state.dart';

class MovementsLogPage extends StatefulWidget {
  const MovementsLogPage({super.key});

  @override
  State<MovementsLogPage> createState() => _MovementsLogPageState();
}

class _MovementsLogPageState extends State<MovementsLogPage> {
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

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      final cubit = context.read<MovementsLogCubit>();
      cubit.updateFilter(cubit.state.filter.copyWith(search: value.trim()));
    });
  }

  void _clearAllFilters(MovementsLogCubit cubit) {
    _searchDebounce?.cancel();
    _searchController.clear();
    cubit.clearFilters();
  }

  Future<void> _printMovementsPdf(MovementsLogCubit cubit) async {
    if (_isExportingPdf) {
      return;
    }
    setState(() => _isExportingPdf = true);

    try {
      final exported = await cubit.fetchForExport();
      final movements = exported.page.items;
      final rows = movements
          .map(
            (m) => <String>[
              _fmtDateTime(m.createdAt),
              m.performedByName,
              m.movementType.arLabel,
              m.toSlotCode ?? m.fromSlotCode ?? '-',
              '${_fmtQty(m.quantityChanged)} ${m.unit.arLabel}',
              m.itemName,
              m.sourceEntity.arLabel,
              m.notes ?? '-',
            ],
          )
          .toList();
      await MovementsLogPdfService.printReport(rows: rows);
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
    MovementsLogCubit cubit,
    MovementsLogFilter filter,
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
    return BlocConsumer<MovementsLogCubit, MovementsLogState>(
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

        final cubit = context.read<MovementsLogCubit>();
        final pageData = state.data.page;
        final summary = state.data.summary;
        final movements = pageData.items;

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
                    _buildFilters(context, cubit, state.filter, isWide),
                    const SizedBox(height: 14),
                    _buildResultsHeader(cubit, summary, isWide),
                    if (state.isLoading) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(minHeight: 2.5),
                    ],
                    const SizedBox(height: 10),
                    Expanded(
                      child: movements.isEmpty
                          ? RefreshIndicator(
                              onRefresh: () => cubit.loadMovements(),
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
                          ? _buildDesktopTable(context, movements, summary)
                          : RefreshIndicator(
                              onRefresh: () => cubit.loadMovements(),
                              child: _buildMobileList(movements),
                            ),
                    ),
                    if (pageData.totalCount > 0) ...[
                      const SizedBox(height: 10),
                      AppPaginationBar(
                        pageData: pageData,
                        isLoading: state.isLoading,
                        pageSizeOptions: const [15, 25, 50],
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

  Widget _buildFilters(
    BuildContext context,
    MovementsLogCubit cubit,
    MovementsLogFilter filter,
    bool isWide,
  ) {
    final dateControls = Row(
      children: [
        Expanded(
          child: _dateButton(
            label: filter.fromDate == null
                ? 'من تاريخ'
                : _fmtDate(filter.fromDate!),
            icon: LucideIcons.calendarDays,
            onTap: () => _pickDate(context, cubit, filter, true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _dateButton(
            label: filter.toDate == null
                ? 'إلى تاريخ'
                : _fmtDate(filter.toDate!),
            icon: LucideIcons.calendarCheck,
            onTap: () => _pickDate(context, cubit, filter, false),
          ),
        ),
      ],
    );

    final dropdowns = Row(
      children: [
        Expanded(
          child: _filterDropdown<MovementActionType>(
            label: 'نوع الحركة',
            value: filter.movementType,
            items: MovementActionType.values
                .map(
                  (e) => DropdownMenuItem<MovementActionType?>(
                    value: e,
                    child: Text(e.arLabel, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) => cubit.updateFilter(
              filter.copyWith(
                movementType: value,
                clearMovementType: value == null,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _filterDropdown<ReceivingSource>(
            label: 'الجهة',
            value: filter.source,
            items: ReceivingSource.values
                .map(
                  (e) => DropdownMenuItem<ReceivingSource?>(
                    value: e,
                    child: Text(e.arLabel, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) => cubit.updateFilter(
              filter.copyWith(source: value, clearSource: value == null),
            ),
          ),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(isWide ? 16 : 13),
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
                hintText: 'ابحث بالصنف أو كود البالتة أو الموقع أو المستخدم',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                suffixIcon: val.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح البحث',
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (isWide)
            Row(
              children: [
                Expanded(flex: 5, child: dateControls),
                const SizedBox(width: 12),
                Expanded(flex: 5, child: dropdowns),
                if (filter.hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _clearAllFilters(cubit),
                    icon: const Icon(LucideIcons.rotateCcw, size: 14),
                    label: const Text('مسح'),
                  ),
                ],
              ],
            )
          else ...[
            dateControls,
            const SizedBox(height: 9),
            dropdowns,
            if (filter.hasActiveFilters) ...[
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => _clearAllFilters(cubit),
                  icon: const Icon(LucideIcons.rotateCcw, size: 14),
                  label: const Text('مسح الفلاتر'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _filterDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T?>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 42),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(11),
      ),
      child: DropdownButton<T?>(
        isExpanded: true,
        value: value,
        hint: Text(label, style: const TextStyle(fontSize: 12)),
        underline: const SizedBox.shrink(),
        isDense: true,
        items: [
          DropdownMenuItem<T?>(value: null, child: Text('كل $label')),
          ...items,
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _dateButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryNavy,
        side: const BorderSide(color: AppColors.borderLight),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
    );
  }

  Widget _buildResultsHeader(
    MovementsLogCubit cubit,
    MovementsLogSummaryEntity summary,
    bool isWide,
  ) {
    return Row(
      children: [
        const Icon(LucideIcons.history, size: 18, color: AppColors.zoneC2Blue),
        const SizedBox(width: 7),
        const Text(
          'سجل الحركات',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: AppColors.primaryNavy,
          ),
        ),
        const SizedBox(width: 8),
        _headerBadge('${summary.totalMovements}', AppColors.zoneC2Blue),
        if (isWide) ...[
          const SizedBox(width: 6),
          _headerBadge(
            'اليوم: ${summary.todayMovements}',
            AppColors.successGreen,
          ),
        ],
        const Spacer(),
        IconButton.filledTonal(
          tooltip: 'تحديث',
          onPressed: () => cubit.loadMovements(),
          icon: const Icon(LucideIcons.refreshCw, size: 16),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: (summary.totalMovements == 0 || _isExportingPdf)
              ? null
              : () => _printMovementsPdf(cubit),
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

  Widget _buildMobileList(List<SystemMovementEntity> movements) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: movements.length,
      separatorBuilder: (_, _) => const SizedBox(height: 9),
      itemBuilder: (context, index) => _movementCard(movements[index]),
    );
  }

  Widget _movementCard(SystemMovementEntity m) {
    final color = _getMovementColor(m.movementType);
    final location = m.toSlotCode ?? m.fromSlotCode ?? '—';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  _getMovementIcon(m.movementType),
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.itemName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${m.movementType.arLabel} • ${m.palletReference}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_fmtQty(m.quantityChanged)} ${m.unit.arLabel}',
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryNavy,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Wrap(
            spacing: 14,
            runSpacing: 7,
            children: [
              _metaItem(LucideIcons.clock3, _fmtDateTime(m.createdAt)),
              _metaItem(LucideIcons.mapPin, location),
              _metaItem(LucideIcons.userRound, m.performedByName),
              _metaItem(LucideIcons.building2, m.sourceEntity.arLabel),
            ],
          ),
          if (m.notes != null && m.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                m.notes!,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ),
          ],
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _balanceChip(
                  'الرصيد السابق',
                  '${_fmtQty(m.previousQuantity)} ${m.unit.arLabel}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _balanceChip(
                  'الرصيد الجديد',
                  '${_fmtQty(m.newQuantity)} ${m.unit.arLabel}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaItem(IconData icon, String value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: AppColors.textSecondary),
      const SizedBox(width: 4),
      Text(
        value,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _balanceChip(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F7FB),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryNavy,
          ),
        ),
      ],
    ),
  );

  Widget _buildDesktopTable(
    BuildContext context,
    List<SystemMovementEntity> movements,
    MovementsLogSummaryEntity summary,
  ) {
    return AppProDataTable<SystemMovementEntity>(
      items: movements,
      expandHeight: true,
      minTableWidth: 960,
      footerLabel:
          'إجمالي الحركات المطابقة: ${summary.totalMovements} حركة (منها ${summary.todayMovements} اليوم)',
      onRowTap: (m) => _showMovementDetailsDialog(context, m),
      columns: [
        AppProTableColumn(
          label: 'التاريخ والوقت',
          fixedWidth: 132,
          cellBuilder: (_, m, _) => Text(
            _fmtDateTime(m.createdAt),
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        AppProTableColumn(
          label: 'نوع الحركة',
          fixedWidth: 145,
          cellBuilder: (_, m, _) {
            final color = _getMovementColor(m.movementType);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                m.movementType.arLabel,
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
          label: 'الصنف',
          flex: 3,
          cellBuilder: (_, m, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                m.itemName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
              ),
              Text(
                m.palletReference,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        AppProTableColumn(
          label: 'الكمية',
          fixedWidth: 105,
          alignment: Alignment.center,
          cellBuilder: (_, m, _) => Text(
            '${_fmtQty(m.quantityChanged)} ${m.unit.arLabel}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.primaryNavy,
            ),
          ),
        ),
        AppProTableColumn(
          label: 'الرصيد',
          fixedWidth: 102,
          alignment: Alignment.center,
          cellBuilder: (_, m, _) => Text(
            '${_fmtQty(m.previousQuantity)} → ${_fmtQty(m.newQuantity)}',
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        AppProTableColumn(
          label: 'الموقع',
          fixedWidth: 112,
          alignment: Alignment.center,
          cellBuilder: (_, m, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              m.toSlotCode ?? m.fromSlotCode ?? '—',
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
          label: 'المنفذ والجهة',
          flex: 2,
          cellBuilder: (_, m, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                m.performedByName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryNavy,
                  fontSize: 12,
                ),
              ),
              Text(
                m.sourceEntity.arLabel,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showMovementDetailsDialog(
    BuildContext context,
    SystemMovementEntity m,
  ) {
    final color = _getMovementColor(m.movementType);
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
              Icon(_getMovementIcon(m.movementType), color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.movementType.arLabel,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    Text(
                      '${m.itemName} • ${m.palletReference}',
                      style: const TextStyle(
                        fontSize: 12,
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
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _balanceChip(
                        'السابق',
                        '${_fmtQty(m.previousQuantity)} ${m.unit.arLabel}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _balanceChip(
                        'كمية الحركة',
                        '${_fmtQty(m.quantityChanged)} ${m.unit.arLabel}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _balanceChip(
                        'الجديد',
                        '${_fmtQty(m.newQuantity)} ${m.unit.arLabel}',
                      ),
                    ),
                  ],
                ),
                if (m.notes != null && m.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Text(
                      'الملاحظات: ${m.notes}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _metaItem(
                      LucideIcons.mapPin,
                      m.toSlotCode ?? m.fromSlotCode ?? '—',
                    ),
                    _metaItem(LucideIcons.userRound, m.performedByName),
                    _metaItem(LucideIcons.building2, m.sourceEntity.arLabel),
                    _metaItem(LucideIcons.clock3, _fmtDateTime(m.createdAt)),
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
    MovementsLogCubit cubit,
    MovementsLogFilter filter,
  ) => Center(
    child: Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.fileSearch, size: 42, color: Color(0xFF9AA8B8)),
          const SizedBox(height: 12),
          const Text(
            'لا توجد حركات مطابقة',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'جرّب تغيير كلمات البحث أو الفلاتر المحددة.',
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

  Color _getMovementColor(MovementActionType type) {
    switch (type) {
      case MovementActionType.receiveNew:
        return AppColors.successGreen;
      case MovementActionType.addItemToPallet:
        return AppColors.mixedPurple;
      case MovementActionType.dispatch:
        return AppColors.zoneC2Blue;
      case MovementActionType.dispatchReversal:
        return AppColors.warningAmber;
      case MovementActionType.condemn:
        return AppColors.dangerRed;
      case MovementActionType.relocate:
        return AppColors.zoneC3Teal;
      case MovementActionType.adjustQuantity:
        return AppColors.warningAmber;
    }
  }

  IconData _getMovementIcon(MovementActionType type) {
    switch (type) {
      case MovementActionType.receiveNew:
        return LucideIcons.packagePlus;
      case MovementActionType.addItemToPallet:
        return LucideIcons.package;
      case MovementActionType.dispatch:
        return LucideIcons.truck;
      case MovementActionType.dispatchReversal:
        return LucideIcons.rotateCcw;
      case MovementActionType.condemn:
        return LucideIcons.flame;
      case MovementActionType.relocate:
        return LucideIcons.arrowLeftRight;
      case MovementActionType.adjustQuantity:
        return LucideIcons.slidersHorizontal;
    }
  }
}
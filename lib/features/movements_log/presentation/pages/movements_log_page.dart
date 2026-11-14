import 'package:discount_cold_store/features/movements_log/domain/entities/movements_log_entities.dart';
import 'package:discount_cold_store/features/receiving/domain/entities/receiving_entities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/movements_log_pdf_service.dart';
import '../../../../core/widgets/responsive_shimmer.dart';
import '../cubit/movements_log_cubit.dart';
import '../cubit/movements_log_state.dart';

class MovementsLogPage extends StatefulWidget {
  const MovementsLogPage({super.key});

  @override
  State<MovementsLogPage> createState() => _MovementsLogPageState();
}

class _MovementsLogPageState extends State<MovementsLogPage> {
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

  Future<void> _printMovementsPdf(List<SystemMovementEntity> movements) async {
    final rows = movements
        .map(
          (m) => <String>[
            _fmtDateTime(m.createdAt),
            m.performedByName,
            m.movementType.arLabel,
            m.toSlotCode ?? m.fromSlotCode ?? '-',
            '${m.quantityChanged} ${m.unit.arLabel}',
            m.itemName,
            m.sourceEntity.arLabel,
            m.notes ?? '-',
          ],
        )
        .toList();
    await MovementsLogPdfService.printReport(rows: rows);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MovementsLogCubit, MovementsLogState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const ResponsiveColdStorageShimmer(
            mode: ShimmerLayoutMode.tableList,
          );
        }

        final cubit = context.read<MovementsLogCubit>();
        return LayoutBuilder(
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
                    vertical: isWide ? 22 : 14,
                  ),
                  child: ValueListenableBuilder<String>(
                    valueListenable: _searchNotifier,
                    builder: (context, query, _) {
                      final filtered = _filterMovements(state.movements, query);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildFilters(context, cubit, state, isWide),
                          const SizedBox(height: 14),
                          _buildResultsHeader(
                            filtered.length,
                            filtered,
                            isWide,
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: () => cubit.loadMovements(),
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
                                  ? _buildDesktopRefreshTable(filtered)
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
        );
      },
    );
  }

  List<SystemMovementEntity> _filterMovements(
    List<SystemMovementEntity> movements,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return movements;
    return movements
        .where(
          (m) =>
              m.itemName.toLowerCase().contains(q) ||
              m.performedByName.toLowerCase().contains(q) ||
              m.palletId.toLowerCase().contains(q) ||
              (m.toSlotCode ?? '').toLowerCase().contains(q) ||
              (m.fromSlotCode ?? '').toLowerCase().contains(q) ||
              m.movementType.arLabel.toLowerCase().contains(q) ||
              m.sourceEntity.arLabel.toLowerCase().contains(q) ||
              (m.notes ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  Widget _buildFilters(
    BuildContext context,
    MovementsLogCubit cubit,
    MovementsLogState state,
    bool isWide,
  ) {
    final dateControls = Row(
      children: [
        Expanded(
          child: _dateButton(
            label: state.fromDate == null
                ? 'من تاريخ'
                : _fmtDate(state.fromDate!),
            icon: LucideIcons.calendarDays,
            onTap: () => _pickDate(context, cubit, state, true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _dateButton(
            label: state.toDate == null ? 'إلى تاريخ' : _fmtDate(state.toDate!),
            icon: LucideIcons.calendarCheck,
            onTap: () => _pickDate(context, cubit, state, false),
          ),
        ),
      ],
    );

    final dropdowns = Row(
      children: [
        Expanded(
          child: _filterDropdown<MovementActionType>(
            label: 'نوع الحركة',
            value: state.movementTypeFilter,
            items: MovementActionType.values
                .map(
                  (e) => DropdownMenuItem<MovementActionType?>(
                    value: e,
                    child: Text(e.arLabel, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) => cubit.applyFilters(
              fromDate: state.fromDate,
              toDate: state.toDate,
              movementTypeFilter: value,
              clearMovementType: value == null,
              sourceFilter: state.sourceFilter,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _filterDropdown<ReceivingSource>(
            label: 'الجهة',
            value: state.sourceFilter,
            items: ReceivingSource.values
                .map(
                  (e) => DropdownMenuItem<ReceivingSource?>(
                    value: e,
                    child: Text(e.arLabel, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) => cubit.applyFilters(
              fromDate: state.fromDate,
              toDate: state.toDate,
              movementTypeFilter: state.movementTypeFilter,
              sourceFilter: value,
              clearSource: value == null,
            ),
          ),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(isWide ? 18 : 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) => _searchNotifier.value = v,
            decoration: InputDecoration(
              hintText: 'ابحث بالصنف أو البالتة أو الموقع أو المستخدم',
              prefixIcon: const Icon(LucideIcons.search, size: 19),
              suffixIcon: _searchNotifier.value.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _searchNotifier.value = '';
                      },
                    ),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFD),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 11),
          if (isWide)
            Row(
              children: [
                Expanded(flex: 5, child: dateControls),
                const SizedBox(width: 12),
                Expanded(flex: 4, child: dropdowns),
              ],
            )
          else ...[
            dateControls,
            const SizedBox(height: 9),
            dropdowns,
          ],
          if (state.fromDate != null ||
              state.toDate != null ||
              state.movementTypeFilter != null ||
              state.sourceFilter != null ||
              _searchNotifier.value.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  _searchNotifier.value = '';
                  cubit.applyFilters(
                    fromDate: null,
                    toDate: null,
                    clearMovementType: true,
                    clearSource: true,
                  );
                },
                icon: const Icon(LucideIcons.rotateCcw, size: 15),
                label: const Text('مسح الفلاتر'),
              ),
            ),
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
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryNavy,
        side: const BorderSide(color: Color(0xFFDCE4EF)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    MovementsLogCubit cubit,
    MovementsLogState state,
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
      movementTypeFilter: state.movementTypeFilter,
      sourceFilter: state.sourceFilter,
    );
  }

  Widget _buildResultsHeader(
    int count,
    List<SystemMovementEntity> movements,
    bool isWide,
  ) {
    return Row(
      children: [
        const Text(
          'سجل الحركات',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: AppColors.primaryNavy,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0FF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryNavy,
            ),
          ),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: movements.isEmpty
              ? null
              : () => _printMovementsPdf(movements),
          icon: const Icon(LucideIcons.fileDown, size: 17),
          label: Text(isWide ? 'تصدير PDF' : 'PDF'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryNavy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileList(List<SystemMovementEntity> movements) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 18),
      itemCount: movements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (context, index) => _movementCard(movements[index]),
    );
  }

  Widget _movementCard(SystemMovementEntity m) {
    final color = _getMovementColor(m.movementType);
    final location = m.toSlotCode ?? m.fromSlotCode ?? '-';
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE7ECF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080D2742),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getMovementIcon(m.movementType),
                  color: color,
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.itemName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      m.movementType.arLabel,
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
                '${m.quantityChanged} ${m.unit.arLabel}',
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryNavy,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFEDF1F6)),
          ),
          Wrap(
            spacing: 16,
            runSpacing: 9,
            children: [
              _metaItem(LucideIcons.clock3, _fmtDateTime(m.createdAt)),
              _metaItem(LucideIcons.mapPin, location),
              _metaItem(LucideIcons.userRound, m.performedByName),
              _metaItem(LucideIcons.building2, m.sourceEntity.arLabel),
            ],
          ),
          if (m.notes != null && m.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                m.notes!,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _balanceChip(
                  'السابق',
                  '${m.previousQuantity} ${m.unit.arLabel}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _balanceChip(
                  'الجديد',
                  '${m.newQuantity} ${m.unit.arLabel}',
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
      Icon(icon, size: 13, color: const Color(0xFF8292A6)),
      const SizedBox(width: 5),
      Text(
        value,
        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
      ),
    ],
  );

  Widget _balanceChip(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
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
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryNavy,
          ),
        ),
      ],
    ),
  );

  Widget _buildDesktopRefreshTable(List<SystemMovementEntity> movements) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [SizedBox(height: 520, child: _buildDesktopTable(movements))],
    );
  }

  Widget _buildDesktopTable(List<SystemMovementEntity> movements) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE7ECF3)),
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
              dataTextStyle: const TextStyle(
                fontSize: 12,
                color: Color(0xFF344054),
              ),
              columnSpacing: 26,
              horizontalMargin: 18,
              columns: const [
                DataColumn(label: Text('التاريخ والوقت')),
                DataColumn(label: Text('نوع الحركة')),
                DataColumn(label: Text('الصنف')),
                DataColumn(label: Text('الكمية')),
                DataColumn(label: Text('الرصيد السابق')),
                DataColumn(label: Text('الرصيد الجديد')),
                DataColumn(label: Text('الموقع')),
                DataColumn(label: Text('المنفذ')),
                DataColumn(label: Text('الجهة')),
              ],
              rows: movements.map((m) {
                final color = _getMovementColor(m.movementType);
                return DataRow(
                  cells: [
                    DataCell(Text(_fmtDateTime(m.createdAt))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          m.movementType.arLabel,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 190,
                        child: Text(
                          m.itemName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${m.quantityChanged} ${m.unit.arLabel}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    DataCell(Text('${m.previousQuantity}')),
                    DataCell(
                      Text(
                        '${m.newQuantity}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    DataCell(Text(m.toSlotCode ?? m.fromSlotCode ?? '-')),
                    DataCell(Text(m.performedByName)),
                    DataCell(Text(m.sourceEntity.arLabel)),
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
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.fileSearch, size: 42, color: Color(0xFF9AA8B8)),
          SizedBox(height: 12),
          Text(
            'لا توجد حركات مطابقة',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.primaryNavy,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'جرّب تغيير كلمات البحث أو الفلاتر المحددة.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );

Color _getMovementColor(MovementActionType type) {
    switch (type) {
      case MovementActionType.receiveNew:
        return AppColors.successGreen; // أو اللون الحالي عندك
      case MovementActionType.addItemToPallet:
        return AppColors.primaryNavy; // أو اللون الحالي عندك
      case MovementActionType.dispatch:
        return AppColors.successGreen; // أو اللون الحالي عندك
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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/responsive_shimmer.dart';
import '../../domain/entities/receiving_entities.dart';
import '../cubit/receiving_cubit.dart';
import '../cubit/receiving_state.dart';

class ReceivingPage extends StatefulWidget {
  final bool historyOnly;
  const ReceivingPage({super.key, this.historyOnly = false});

  @override
  State<ReceivingPage> createState() => _ReceivingPageState();
}

class _ReceivingPageState extends State<ReceivingPage> {
  final ValueNotifier<String> _searchNotifier = ValueNotifier<String>('');
  ReceivingSource? _sourceFilter;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void dispose() {
    _searchNotifier.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) => intl.DateFormat('yyyy-MM-dd').format(d);
  String _fmtDateTime(DateTime d) =>
      intl.DateFormat('yyyy-MM-dd HH:mm').format(d);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReceivingCubit, ReceivingState>(
      listenWhen: (prev, curr) =>
          prev.failure != curr.failure ||
          prev.successMessage != curr.successMessage,
      listener: (context, state) {
        if (state.failure != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.failure!.message),
                backgroundColor: AppColors.dangerRed,
                behavior: SnackBarBehavior.floating,
              ),
            );
        } else if (state.successMessage != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: AppColors.successGreen,
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      },
      buildWhen: (prev, curr) =>
          prev.isLoading != curr.isLoading ||
          prev.slots != curr.slots ||
          prev.movements != curr.movements ||
          prev.selectedZone != curr.selectedZone ||
          prev.selectedRackLetter != curr.selectedRackLetter,
      builder: (context, state) {
        if (state.isLoading) {
          return const ResponsiveColdStorageShimmer(
            mode: ShimmerLayoutMode.tableList,
          );
        }
        return widget.historyOnly
            ? _buildMovementsLogTab(context, state)
            : _WarehouseRackMatrixView(state: state);
      },
    );
  }

  String _palletCode(String id) {
    final normalized = id.replaceAll('-', '').toUpperCase();
    return 'PLT-${normalized.substring(0, normalized.length.clamp(0, 8).toInt())}';
  }

  List<List<ReceivingMovementEntity>> _groupMovements(
    List<ReceivingMovementEntity> movements,
  ) {
    final grouped = <String, List<ReceivingMovementEntity>>{};
    for (final movement in movements) {
      final key =
          '${movement.palletId}|${movement.movementType.dbValue}|${movement.createdAt.toUtc().toIso8601String()}';
      grouped.putIfAbsent(key, () => []).add(movement);
    }
    return grouped.values.toList();
  }

  Widget _buildMovementsLogTab(BuildContext context, ReceivingState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final desktop = width >= 900;
        return ValueListenableBuilder<String>(
          valueListenable: _searchNotifier,
          builder: (context, query, _) {
            final filtered = state.movements.where((m) {
              if (_sourceFilter != null && m.sourceEntity != _sourceFilter) {
                return false;
              }
              if (_fromDate != null &&
                  m.createdAt.isBefore(
                    DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day),
                  )) {
                return false;
              }
              if (_toDate != null &&
                  m.createdAt.isAfter(
                    DateTime(
                      _toDate!.year,
                      _toDate!.month,
                      _toDate!.day,
                      23,
                      59,
                      59,
                    ),
                  )) {
                return false;
              }
              final q = query.trim().toLowerCase();
              if (q.isNotEmpty &&
                  !m.itemName.toLowerCase().contains(q) &&
                  !m.performedByName.toLowerCase().contains(q) &&
                  !(m.toSlotCode ?? '').toLowerCase().contains(q) &&
                  !(m.fromSlotCode ?? '').toLowerCase().contains(q) &&
                  !_palletCode(m.palletId).toLowerCase().contains(q)) {
                return false;
              }
              return true;
            }).toList();
            final groups = _groupMovements(filtered);
            final totalQty = filtered.fold<double>(
              0,
              (sum, m) => sum + m.quantityChanged,
            );
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: RefreshIndicator(
                    onRefresh: () => context.read<ReceivingCubit>().loadData(),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            desktop ? 28 : 16,
                            20,
                            desktop ? 28 : 16,
                            8,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'سجل الاستلامات',
                                            style: TextStyle(
                                              fontSize: desktop ? 25 : 21,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.primaryNavy,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'متابعة عمليات دخول الأصناف إلى المخزن',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (desktop)
                                      OutlinedButton.icon(
                                        onPressed: () => context
                                            .read<ReceivingCubit>()
                                            .loadData(),
                                        icon: const Icon(
                                          LucideIcons.refreshCw,
                                          size: 16,
                                        ),
                                        label: const Text('تحديث'),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    _summaryTile(
                                      'عمليات الاستلام',
                                      '${groups.length}',
                                      LucideIcons.clipboardList,
                                      const Color(0xFFEAF0FF),
                                      AppColors.zoneC2Blue,
                                      desktop,
                                      width,
                                    ),
                                    _summaryTile(
                                      'عدد الأصناف',
                                      '${filtered.length}',
                                      LucideIcons.package,
                                      const Color(0xFFE8F7EF),
                                      AppColors.successGreen,
                                      desktop,
                                      width,
                                    ),
                                    _summaryTile(
                                      'إجمالي الكميات',
                                      totalQty.toStringAsFixed(1),
                                      LucideIcons.chartNoAxesColumn,
                                      const Color(0xFFFFF4E5),
                                      const Color(0xFFB7791F),
                                      desktop,
                                      width,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0xFFE6EBF2),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              onChanged: (v) =>
                                                  _searchNotifier.value = v,
                                              decoration: InputDecoration(
                                                hintText:
                                                    'ابحث بالصنف أو كود البالتة أو الموقع أو المستلم',
                                                prefixIcon: const Icon(
                                                  LucideIcons.search,
                                                  size: 19,
                                                ),
                                                filled: true,
                                                fillColor: const Color(
                                                  0xFFF6F8FC,
                                                ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 14,
                                                    ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(13),
                                                  borderSide: BorderSide.none,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton.filledTonal(
                                            tooltip: 'الفلاتر',
                                            onPressed: () =>
                                                _showFilters(context),
                                            icon: const Icon(
                                              LucideIcons.slidersHorizontal,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _filterDescription(),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () => setState(() {
                                              _fromDate = null;
                                              _toDate = null;
                                              _sourceFilter = null;
                                              _searchNotifier.value = '';
                                            }),
                                            child: const Text('مسح الفلاتر'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    const Text(
                                      'العمليات',
                                      style: TextStyle(
                                        fontSize: 17,
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
                                        '${groups.length}',
                                        style: const TextStyle(
                                          color: AppColors.zoneC2Blue,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                        if (groups.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(
                                'لا توجد عمليات استلام مطابقة للفلاتر المحددة.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          )
                        else if (desktop)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                            sliver: SliverToBoxAdapter(
                              child: _desktopTable(groups),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) =>
                                    _movementCard(groups[index]),
                                childCount: groups.length,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _summaryTile(
    String label,
    String value,
    IconData icon,
    Color bg,
    Color fg,
    bool desktop,
    double availableWidth,
  ) => Container(
    width: desktop ? 220 : (availableWidth - 44) / 2,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE6EBF2)),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: fg, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryNavy,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  String _filterDescription() {
    final parts = <String>[];
    if (_fromDate != null) parts.add('من ${_fmtDate(_fromDate!)}');
    if (_toDate != null) parts.add('إلى ${_fmtDate(_toDate!)}');
    if (_sourceFilter != null) parts.add(_sourceFilter!.arLabel);
    return parts.isEmpty ? 'كل الجهات • كل الفترات' : parts.join('  ·  ');
  }

  Future<void> _showFilters(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'تصفية سجل الاستلامات',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'جهة الاستلام',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('كل الجهات'),
                    selected: _sourceFilter == null,
                    onSelected: (_) =>
                        setSheetState(() => _sourceFilter = null),
                  ),
                  ChoiceChip(
                    label: const Text('الإنتاج'),
                    selected: _sourceFilter == ReceivingSource.production,
                    onSelected: (_) => setSheetState(
                      () => _sourceFilter = ReceivingSource.production,
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('فحص الجودة'),
                    selected:
                        _sourceFilter == ReceivingSource.qualityInspection,
                    onSelected: (_) => setSheetState(
                      () => _sourceFilter = ReceivingSource.qualityInspection,
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
                          context: context,
                          initialDate: _fromDate ?? DateTime.now(),
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2035),
                        );
                        if (d != null) setSheetState(() => _fromDate = d);
                      },
                      icon: const Icon(LucideIcons.calendar, size: 16),
                      label: Text(
                        _fromDate == null ? 'من تاريخ' : _fmtDate(_fromDate!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _toDate ?? DateTime.now(),
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2035),
                        );
                        if (d != null) setSheetState(() => _toDate = d);
                      },
                      icon: const Icon(LucideIcons.calendarCheck, size: 16),
                      label: Text(
                        _toDate == null ? 'إلى تاريخ' : _fmtDate(_toDate!),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('تطبيق الفلاتر'),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _movementCard(List<ReceivingMovementEntity> items) {
    final first = items.first;
    final mixed = items.length > 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7ECF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080B1F3A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  mixed
                      ? 'بالتة ميكس • ${items.length} أصناف'
                      : first.movementType.arLabel,
                  style: const TextStyle(
                    color: AppColors.zoneC2Blue,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _palletCode(first.palletId),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const Icon(
                LucideIcons.package,
                size: 18,
                color: AppColors.zoneC2Blue,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.asMap().entries.map((entry) {
            final item = entry.value;
            return Container(
              margin: EdgeInsets.only(
                bottom: entry.key == items.length - 1 ? 0 : 8,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.itemName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${item.quantityChanged} ${item.unit.arLabel}',
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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.mapPin,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    first.toSlotCode ?? first.fromSlotCode ?? '—',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.userRound,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    first.performedByName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.clock3,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _fmtDateTime(first.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _desktopTable(List<List<ReceivingMovementEntity>> groups) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EAF1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F7FB)),
          columns: const [
            DataColumn(label: Text('نوع العملية')),
            DataColumn(label: Text('كود البالتة')),
            DataColumn(label: Text('الأصناف والكميات')),
            DataColumn(label: Text('الموقع')),
            DataColumn(label: Text('المستلم')),
            DataColumn(label: Text('التاريخ')),
          ],
          rows: groups.map((items) {
            final m = items.first;
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    items.length > 1 ? 'بالتة ميكس' : m.movementType.arLabel,
                  ),
                ),
                DataCell(
                  Text(
                    _palletCode(m.palletId),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 260,
                    child: Text(
                      items
                          .map(
                            (e) =>
                                '${e.itemName} • ${e.quantityChanged} ${e.unit.arLabel}',
                          )
                          .join('\n'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(Text(m.toSlotCode ?? m.fromSlotCode ?? '—')),
                DataCell(Text(m.performedByName)),
                DataCell(Text(_fmtDateTime(m.createdAt))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _WarehouseRackMatrixView extends StatelessWidget {
  final ReceivingState state;
  const _WarehouseRackMatrixView({required this.state});

  void _showQuickRackPickerSheet(BuildContext context, ReceivingCubit cubit) {
    final zoneRacks =
        state.slots
            .where((s) => s.zoneCode == state.selectedZone)
            .map((s) => s.rackLetter)
            .toSet()
            .toList()
          ..sort();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'اختر الراك في منطقة ${state.selectedZone}',
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'يظهر أسفل كل حرف عدد البالتات المسكنة من إجمالي 16 بنة',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 68,
                ),
                itemCount: zoneRacks.length,
                itemBuilder: (_, idx) {
                  final letter = zoneRacks[idx];
                  final isSelected = letter == state.selectedRackLetter;
                  final occCount = state.slots
                      .where((s) => s.rackLetter == letter && s.isOccupied)
                      .length;
                  final isFull = occCount == 16;

                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      cubit.selectRackLetter(letter);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryNavy
                            : isFull
                            ? AppColors.dangerRed.withValues(alpha: 0.08)
                            : AppColors.scaffoldBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accentCyan
                              : isFull
                              ? AppColors.dangerRed
                              : AppColors.borderLight,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'راك $letter',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: isSelected
                                  ? AppColors.accentCyan
                                  : AppColors.primaryNavy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$occCount / 16',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white70
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReceivingCubit>();
    final zoneRacks =
        state.slots
            .where((s) => s.zoneCode == state.selectedZone)
            .map((s) => s.rackLetter)
            .toSet()
            .toList()
          ..sort();

    final currentRackIdx = zoneRacks.indexOf(state.selectedRackLetter);
    final currentOccupiedCount = state.currentRackSlots
        .where((s) => s.isOccupied)
        .length;

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          final mainMatrixContent = Column(
            children: [
              // 1. شريط التحكم العلوي الأنيق والمدمج
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ZonePillButton(
                            title: 'منطقة C2',
                            subtitle: 'راكات A - M',
                            isSelected: state.selectedZone == 'C2',
                            activeColor: AppColors.zoneC2Blue,
                            onTap: () => cubit.selectZone('C2'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ZonePillButton(
                            title: 'منطقة C3',
                            subtitle: 'راكات N - T',
                            isSelected: state.selectedZone == 'C3',
                            activeColor: AppColors.zoneC3Teal,
                            onTap: () => cubit.selectZone('C3'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryNavy,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'الراك السابق',
                            onPressed: currentRackIdx > 0
                                ? () => cubit.selectRackLetter(
                                    zoneRacks[currentRackIdx - 1],
                                  )
                                : null,
                            icon: Icon(
                              LucideIcons.chevronRight,
                              color: currentRackIdx > 0
                                  ? Colors.white
                                  : Colors.white24,
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () =>
                                  _showQuickRackPickerSheet(context, cubit),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      LucideIcons.warehouse,
                                      color: AppColors.accentCyan,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'راك (${state.selectedRackLetter})',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.14,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '$currentOccupiedCount / 16 مشغولة',
                                        style: const TextStyle(
                                          color: AppColors.accentCyan,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      LucideIcons.chevronsUpDown,
                                      color: Colors.white70,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'الراك التالي',
                            onPressed: currentRackIdx < zoneRacks.length - 1
                                ? () => cubit.selectRackLetter(
                                    zoneRacks[currentRackIdx + 1],
                                  )
                                : null,
                            icon: Icon(
                              LucideIcons.chevronLeft,
                              color: currentRackIdx < zoneRacks.length - 1
                                  ? Colors.white
                                  : Colors.white24,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: [
                        _LegendDot(
                          color: AppColors.borderLight,
                          label: 'فارغة (اضغط للتسكين)',
                        ),
                        _LegendDot(
                          color: AppColors.successGreen,
                          label: 'بالتة موحدة',
                        ),
                        _LegendDot(
                          color: AppColors.mixedPurple,
                          label: 'بالتة ميكس',
                        ),
                        _LegendDot(
                          color: AppColors.dangerRed,
                          label: 'تنبيه إعدام',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. شبكة الـ 16 بنة مقسمة بصرياً إلى 4 أدوار
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => cubit.loadData(),
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    children: [4, 3, 2, 1].map((floorNum) {
                      final floorSlots =
                          state.currentRackSlots
                              .where((s) => s.floorNumber == floorNum)
                              .toList()
                            ..sort(
                              (a, b) => a.binNumber.compareTo(b.binNumber),
                            );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryNavy.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    floorNum == 1
                                        ? 'الدور 1 (الأرضي)'
                                        : 'الدور $floorNum',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: AppColors.primaryNavy,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Divider(
                                    color: Colors.grey.shade200,
                                    thickness: 1.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            LayoutBuilder(
                              builder: (ctx, box) {
                                final cols = box.maxWidth >= 560 ? 4 : 2;
                                return GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: cols,
                                        mainAxisSpacing: 10,
                                        crossAxisSpacing: 10,
                                        mainAxisExtent: 122,
                                      ),
                                  itemCount: floorSlots.length,
                                  itemBuilder: (_, idx) {
                                    final slot = floorSlots[idx];
                                    return _PalletBinCard(
                                      slot: slot,
                                      onTap: () {
                                        if (!slot.isOccupied) {
                                          _showReceiveOrAddSheet(
                                            context: context,
                                            slot: slot,
                                          );
                                        } else {
                                          _showManageOccupiedPalletSheet(
                                            context: context,
                                            slot: slot,
                                          );
                                        }
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          );

          if (isDesktop) {
            return Row(
              children: [
                Container(
                  width: 195,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      left: BorderSide(color: AppColors.borderLight),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          'راكات منطقة ${state.selectedZone}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(10),
                          itemCount: zoneRacks.length,
                          itemBuilder: (_, idx) {
                            final letter = zoneRacks[idx];
                            final isSelected =
                                letter == state.selectedRackLetter;
                            final occ = state.slots
                                .where(
                                  (s) => s.rackLetter == letter && s.isOccupied,
                                )
                                .length;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Material(
                                type: MaterialType.transparency,
                                child: ListTile(
                                  dense: true,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  selected: isSelected,
                                  selectedTileColor: AppColors.primaryNavy,
                                  title: Text(
                                    'راك $letter',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? AppColors.accentCyan
                                          : AppColors.primaryNavy,
                                    ),
                                  ),
                                  trailing: Text(
                                    '$occ/16',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                  onTap: () => cubit.selectRackLetter(letter),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: mainMatrixContent),
              ],
            );
          }

          return mainMatrixContent;
        },
      ),
    );
  }

  /// فتح نافذة الاستلام/التزويد المعزولة تماماً عن لاج الكيبورد
  void _showReceiveOrAddSheet({
    required BuildContext context,
    required ReceivingRackSlotEntity slot,
    String? existingPalletId,
  }) {
    final cubit = context.read<ReceivingCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _KeyboardInsetPadding(
        child: _ReceiveOrAddPalletSheet(
          cubit: cubit,
          slot: slot,
          existingPalletId: existingPalletId,
        ),
      ),
    );
  }

void _showManageOccupiedPalletSheet({
    required BuildContext context,
    required ReceivingRackSlotEntity slot,
  }) {
    final pallet = slot.occupiedPallet;
    if (pallet == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إدارة البالتة [${slot.slotCode}]',
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                          Text(
                            pallet.isMixed
                                ? 'بالتة ميكس (${pallet.items.length} أصناف)'
                                : 'بالتة موحدة',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppActionButton(
                      label: 'تزويد صنف',
                      icon: LucideIcons.packagePlus,
                      variant: AppButtonVariant.secondary,
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showReceiveOrAddSheet(
                          context: context,
                          slot: slot,
                          existingPalletId: pallet.id,
                        );
                      },
                    ),
                  ],
                ),
                const Divider(height: 20),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: pallet.items.length,
                    itemBuilder: (_, idx) {
                      final item = pallet.items[idx];
                      final isAlert = item.isDueForCondemnation;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isAlert
                                ? AppColors.dangerRed
                                : AppColors.borderLight,
                            width: isAlert ? 1.5 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.itemName} (${item.quantity} ${item.unit.arLabel})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'متبقي: ${item.daysUntilExpiry} يوم',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: isAlert
                                          ? AppColors.dangerRed
                                          : AppColors.successGreen,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'الجهة: ${item.sourceEntity.arLabel} | المستلم: ${item.receivedByName}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  AppActionButton(
                                    label: 'تعديل الكمية',
                                    icon: LucideIcons.slidersHorizontal,
                                    variant: AppButtonVariant.outline,
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                      _showItemQuantityActionDialog(
                                        context: context,
                                        item: item,
                                        action:
                                            MovementActionType.adjustQuantity,
                                      );
                                    },
                                  ),
                                  AppActionButton(
                                    label: 'إعدام',
                                    icon: LucideIcons.flame,
                                    variant: AppButtonVariant.danger,
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                      _showItemQuantityActionDialog(
                                        context: context,
                                        item: item,
                                        action: MovementActionType.condemn,
                                      );
                                    },
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                      _showDeleteItemConfirmDialog(
                                        context: context,
                                        slot: slot,
                                        item: item,
                                        isOnlyItemOnPallet:
                                            pallet.items.length == 1,
                                      );
                                    },
                                    icon: const Icon(
                                      LucideIcons.trash2,
                                      size: 16,
                                      color: AppColors.dangerRed,
                                    ),
                                    label: const Text(
                                      'حذف الصنف',
                                      style: TextStyle(
                                        color: AppColors.dangerRed,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: AppColors.dangerRed.withValues(
                                          alpha: 0.45,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _showDeletePalletConfirmDialog(
                        context: context,
                        slot: slot,
                        pallet: pallet,
                      );
                    },
                    icon: const Icon(
                      LucideIcons.trash2,
                      color: AppColors.dangerRed,
                      size: 18,
                    ),
                    label: const Text(
                      'حذف البالتة بالكامل (تسكين بالخطأ)',
                      style: TextStyle(
                        color: AppColors.dangerRed,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.dangerRed.withValues(alpha: 0.45),
                      ),
                      backgroundColor: AppColors.dangerRed.withValues(
                        alpha: 0.05,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDeletePalletConfirmDialog({
    required BuildContext context,
    required ReceivingRackSlotEntity slot,
    required ReceivingPalletEntity pallet,
  }) async {
    final cubit = context.read<ReceivingCubit>();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _DeleteConfirmationDialog(
        title: 'تأكيد حذف البالتة بالكامل',
        warningMessage:
            'سيتم حذف البالتة (${pallet.palletReference}) بجميع أصنافها (${pallet.items.length} صنف) وإخلاء الموقع [${slot.slotCode}] فوراً.\nلا يمكن حذف البالتات المرتبطة بمستند صرف أو إعدام رسمي.',
        defaultReason: 'تسكين بالخطأ',
        confirmLabel: 'حذف البالتة',
      ),
    );
    if (reason != null && reason.trim().isNotEmpty) {
      await cubit.deleteMistakenPallet(
        palletId: pallet.id,
        slotCode: slot.slotCode,
        reason: reason,
      );
    }
  }

  Future<void> _showDeleteItemConfirmDialog({
    required BuildContext context,
    required ReceivingRackSlotEntity slot,
    required ReceivingPalletItemEntity item,
    required bool isOnlyItemOnPallet,
  }) async {
    final cubit = context.read<ReceivingCubit>();
    final extraNote = isOnlyItemOnPallet
        ? '\nتنبيه: هذا هو الصنف الوحيد على البالتة، لذا سيتم أيضاً إخلاء الموقع [${slot.slotCode}].'
        : '\nستبقى باقي أصناف البالتة في الموقع [${slot.slotCode}] كما هي.';

    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _DeleteConfirmationDialog(
        title: 'تأكيد حذف الصنف',
        warningMessage:
            'سيتم حذف الصنف (${item.itemName}) بكمية (${item.quantity} ${item.unit.arLabel}) من الموقع [${slot.slotCode}].$extraNote',
        defaultReason: 'إدخال صنف بالخطأ',
        confirmLabel: 'حذف الصنف',
      ),
    );
    if (reason != null && reason.trim().isNotEmpty) {
      await cubit.deleteMistakenPalletItem(
        palletItemId: item.palletItemId,
        itemName: item.itemName,
        slotCode: slot.slotCode,
        reason: reason,
      );
    }
  }

  void _showItemQuantityActionDialog({
    required BuildContext context,
    required ReceivingPalletItemEntity item,
    required MovementActionType action,
  }) {
    final cubit = context.read<ReceivingCubit>();
    final qtyCtrl = TextEditingController(text: item.quantity.toString());
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            '${action.arLabel} — ${item.itemName}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: action == MovementActionType.adjustQuantity
                      ? 'الكمية الجديدة (الحالية: ${item.quantity})'
                      : 'الكمية المطلوبة (المتاح: ${item.quantity})',
                  prefixIcon: const Icon(LucideIcons.hash),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات أو سبب الإجراء',
                  prefixIcon: Icon(LucideIcons.fileText),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
            AppActionButton(
              label: 'تأكيد',
              variant: action == MovementActionType.condemn
                  ? AppButtonVariant.danger
                  : AppButtonVariant.primary,
              onPressed: () async {
                final val = double.tryParse(qtyCtrl.text.trim());
                if (val == null) return;
                Navigator.of(ctx).pop();
                await cubit.adjustOrReleaseItem(
                  palletItemId: item.palletItemId,
                  action: action,
                  targetQuantity: val,
                  notes: notesCtrl.text.trim(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// ويدجت عزل الكيبورد: هو الوحيد الذي يتحرك مع الـ viewInsets دون إعادة بناء الفورم بداخله!
class _KeyboardInsetPadding extends StatelessWidget {
  final Widget child;
  const _KeyboardInsetPadding({required this.child});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: child,
    );
  }
}

/// نافذة استلام أو تزويد البالتة المعزولة بـ RepaintBoundary وبدون أي اشتراك في MediaQuery.viewInsets
class _ReceiveOrAddPalletSheet extends StatefulWidget {
  final ReceivingCubit cubit;
  final ReceivingRackSlotEntity slot;
  final String? existingPalletId;

  const _ReceiveOrAddPalletSheet({
    required this.cubit,
    required this.slot,
    this.existingPalletId,
  });

  @override
  State<_ReceiveOrAddPalletSheet> createState() =>
      _ReceiveOrAddPalletSheetState();
}

class _ReceiveOrAddPalletSheetState extends State<_ReceiveOrAddPalletSheet> {
  ReceivingSource _selectedSource = ReceivingSource.production;
  final List<PalletItemDraft> _drafts = [PalletItemDraft()];

  bool get _isAddingToExisting => widget.existingPalletId != null;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isAddingToExisting
                          ? 'تزويد أصناف على البالتة [${widget.slot.slotCode}]'
                          : 'استلام وتسكين في [${widget.slot.slotCode}]',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _drafts.length > 1
                          ? AppColors.mixedPurple.withValues(alpha: 0.12)
                          : AppColors.zoneC2Blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _drafts.length > 1
                          ? 'ميكس (${_drafts.length})'
                          : 'بالتة موحدة',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                        color: _drafts.length > 1
                            ? AppColors.mixedPurple
                            : AppColors.zoneC2Blue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ReceivingSource>(
                value: _selectedSource,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'الجهة المستلمة',
                  prefixIcon: Icon(LucideIcons.building2, size: 18),
                ),
                items: ReceivingSource.values
                    .map(
                      (s) =>
                          DropdownMenuItem(value: s, child: Text(s.arLabel)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedSource = v);
                },
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _drafts.length,
                    itemBuilder: (context, idx) {
                      final draft = _drafts[idx];
                      return _PalletItemDraftCard(
                        key: ObjectKey(draft),
                        index: idx,
                        draft: draft,
                        canRemove: _drafts.length > 1,
                        onRemove: () => setState(() => _drafts.removeAt(idx)),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AppActionButton(
                label: 'إضافة صنف آخر (بالتة ميكس)',
                icon: LucideIcons.plus,
                variant: AppButtonVariant.outline,
                fullWidth: true,
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  setState(() => _drafts.add(PalletItemDraft()));
                },
              ),
              const SizedBox(height: 8),
              AppActionButton(
                label: _isAddingToExisting
                    ? 'تأكيد تزويد الأصناف'
                    : 'تأكيد الاستلام والتسكين',
                icon: LucideIcons.check,
                fullWidth: true,
                variant: AppButtonVariant.success,
                onPressed: () async {
                  FocusScope.of(context).unfocus();
                  final allValid = _drafts.every((d) => d.isValid);
                  if (!allValid) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'تأكد من إدخال اسم الصنف، الكمية، وتاريخ الانتهاء بشكل صحيح.',
                        ),
                        backgroundColor: AppColors.dangerRed,
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).pop();
                  if (_isAddingToExisting) {
                    await widget.cubit.addItemsToExistingPallet(
                      palletId: widget.existingPalletId!,
                      sourceEntity: _selectedSource,
                      items: _drafts,
                    );
                  } else {
                    await widget.cubit.receiveNewPallet(
                      sourceEntity: _selectedSource,
                      slotId: widget.slot.id,
                      items: _drafts,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// بطاقة صنف مستقلة بـ TextEditingController خاص بها لمنع أي بطء أثناء الكتابة
class _PalletItemDraftCard extends StatefulWidget {
  final int index;
  final PalletItemDraft draft;
  final bool canRemove;
  final VoidCallback onRemove;

  const _PalletItemDraftCard({
    super.key,
    required this.index,
    required this.draft,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  State<_PalletItemDraftCard> createState() => _PalletItemDraftCardState();
}

class _PalletItemDraftCardState extends State<_PalletItemDraftCard> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.draft.itemName);
    _qtyCtrl = TextEditingController(
      text: widget.draft.quantity == widget.draft.quantity.roundToDouble()
          ? widget.draft.quantity.toInt().toString()
          : widget.draft.quantity.toString(),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.scaffoldBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الصنف #${widget.index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryNavy,
                  ),
                ),
                if (widget.canRemove)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      LucideIcons.trash2,
                      color: AppColors.dangerRed,
                      size: 18,
                    ),
                    onPressed: widget.onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'اسم الصنف',
                prefixIcon: Icon(LucideIcons.package, size: 18),
              ),
              onChanged: (v) => draft.itemName = v,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'الكمية',
                      prefixIcon: Icon(LucideIcons.hash, size: 18),
                    ),
                    onChanged: (v) =>
                        draft.quantity = double.tryParse(v.trim()) ?? 0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<PackageUnit>(
                    value: draft.unit,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'الوحدة',
                    ),
                    items: PackageUnit.values
                        .map(
                          (u) => DropdownMenuItem(
                            value: u,
                            child: Text(u.arLabel),
                          ),
                        )
                        .toList(),
                    onChanged: (u) {
                      if (u != null) {
                        setState(() => draft.unit = u);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(LucideIcons.calendar, size: 14),
                    label: Text(
                      'إنتاج: ${intl.DateFormat('yyyy-MM-dd').format(draft.productionDate)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onPressed: () async {
                      FocusScope.of(context).unfocus();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: draft.productionDate,
                        firstDate: DateTime(2023),
                        lastDate: DateTime(2032),
                      );
                      if (picked != null) {
                        setState(() => draft.productionDate = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(LucideIcons.calendarClock, size: 14),
                    label: Text(
                      'انتهاء: ${intl.DateFormat('yyyy-MM-dd').format(draft.expiryDate)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onPressed: () async {
                      FocusScope.of(context).unfocus();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: draft.expiryDate,
                        firstDate: DateTime(2023),
                        lastDate: DateTime(2036),
                      );
                      if (picked != null) {
                        setState(() => draft.expiryDate = picked);
                      }
                    },
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

class _ZonePillButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _ZonePillButton({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : AppColors.scaffoldBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.borderLight,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.snowflake,
              size: 16,
              color: isSelected ? Colors.white : activeColor,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: isSelected ? Colors.white : AppColors.primaryNavy,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isSelected
                          ? Colors.white70
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _PalletBinCard extends StatelessWidget {
  final ReceivingRackSlotEntity slot;
  final VoidCallback onTap;

  const _PalletBinCard({required this.slot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pallet = slot.occupiedPallet;
    final isOccupied = slot.isOccupied && pallet != null;
    final hasAlert = pallet?.hasCondemnationAlert ?? false;
    final isMixed = pallet?.isMixed ?? false;

    final Color accentColor = !isOccupied
        ? Colors.grey.shade400
        : hasAlert
        ? AppColors.dangerRed
        : isMixed
        ? AppColors.mixedPurple
        : AppColors.successGreen;

    final Color bgColor = !isOccupied
        ? AppColors.scaffoldBackground
        : hasAlert
        ? AppColors.dangerRed.withValues(alpha: 0.06)
        : isMixed
        ? AppColors.mixedPurple.withValues(alpha: 0.06)
        : AppColors.successGreen.withValues(alpha: 0.06);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor, width: isOccupied ? 1.8 : 1.1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryNavy,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'بنة ${slot.binNumber}',
                    style: const TextStyle(
                      color: AppColors.accentCyan,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (isOccupied)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isMixed ? 'ميكس (${pallet.items.length})' : 'موحدة',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                  )
                else
                  Icon(
                    LucideIcons.plusCircle,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
              ],
            ),
            const Spacer(),
            if (!isOccupied)
              Center(
                child: Text(
                  "فارغة\nاضغط للتسكين",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else ...[
              Text(
                pallet.items.first.itemName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                pallet.isMixed
                    ? '+ ${pallet.items.length - 1} أصناف أخرى'
                    : '${pallet.items.first.quantity} ${pallet.items.first.unit.arLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'متبقي: ${pallet.minDaysUntilExpiry} يوم',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: hasAlert
                      ? AppColors.dangerRed
                      : AppColors.successGreen,
                ),
              ),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _DeleteConfirmationDialog extends StatefulWidget {
  final String title;
  final String warningMessage;
  final String defaultReason;
  final String confirmLabel;

  const _DeleteConfirmationDialog({
    required this.title,
    required this.warningMessage,
    required this.defaultReason,
    required this.confirmLabel,
  });

  @override
  State<_DeleteConfirmationDialog> createState() =>
      _DeleteConfirmationDialogState();
}

class _DeleteConfirmationDialogState extends State<_DeleteConfirmationDialog> {
  late final TextEditingController _reasonCtrl;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _reasonCtrl = TextEditingController(text: widget.defaultReason);
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(LucideIcons.triangleAlert, color: AppColors.dangerRed),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.dangerRed.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.dangerRed.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                widget.warningMessage,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: AppColors.primaryNavy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _reasonCtrl,
              maxLines: 2,
              onChanged: (_) {
                if (_validationError != null) {
                  setState(() => _validationError = null);
                }
              },
              decoration: InputDecoration(
                labelText: 'سبب الحذف (يُحفظ في سجل التدقيق)',
                errorText: _validationError,
                prefixIcon: const Icon(LucideIcons.fileText, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          AppActionButton(
            label: widget.confirmLabel,
            icon: LucideIcons.trash2,
            variant: AppButtonVariant.danger,
            onPressed: () {
              final text = _reasonCtrl.text.trim();
              if (text.isEmpty) {
                setState(() => _validationError = 'يرجى كتابة سبب الحذف');
                return;
              }
              Navigator.of(context).pop(text);
            },
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/responsive_shimmer.dart';
import '../../domain/entities/receiving_dispatch_entities.dart';
import '../cubit/receiving_dispatch_cubit.dart';
import '../cubit/receiving_dispatch_state.dart';

/// شاشة الموديول الثالث (الاستلام والصرف والراكات C2 & C3):
/// - خالية من أي سطور نصية مكسورة
/// - معزولة بـ RepaintBoundary و LayoutBuilder لمنع اللاج مع الكيبورد
class ReceivingDispatchPage extends StatefulWidget {
  const ReceivingDispatchPage({super.key});

  @override
  State<ReceivingDispatchPage> createState() => _ReceivingDispatchPageState();
}

class _ReceivingDispatchPageState extends State<ReceivingDispatchPage> {
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
  String _fmtDateTime(DateTime d) => intl.DateFormat('yyyy-MM-dd HH:mm').format(d);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReceivingDispatchCubit, ReceivingDispatchState>(
      listener: (context, state) {
        if (state.failure != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.failure!.message),
              backgroundColor: AppColors.dangerRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!),
              backgroundColor: AppColors.successGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Container(
                color: Colors.white,
                child: const TabBar(
                  labelColor: AppColors.zoneC2Blue,
                  indicatorColor: AppColors.zoneC2Blue,
                  tabs: [
                    Tab(
                      icon: Icon(LucideIcons.grid3x3, size: 18),
                      text: 'تسكين الراكات والاستلام والصرف (16 بالتة/راك)',
                    ),
                    Tab(
                      icon: Icon(LucideIcons.history, size: 18),
                      text: 'سجل الاستلامات والصرف والبحث بالفترة',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    state.isLoading
                        ? const ResponsiveColdStorageShimmer(
                            mode: ShimmerLayoutMode.rackGrid,
                          )
                        : _RackGridInteractiveView(state: state),
                    state.isLoading
                        ? const ResponsiveColdStorageShimmer(
                            mode: ShimmerLayoutMode.tableList,
                          )
                        : _buildMovementsLogTab(context, state),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMovementsLogTab(
    BuildContext context,
    ReceivingDispatchState state,
  ) {
    return RepaintBoundary(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'فلترة سجل الاستلامات والصرف (توقيت مصر)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      AppActionButton(
                        label: 'تحديث السجل',
                        icon: LucideIcons.refreshCw,
                        variant: AppButtonVariant.secondary,
                        onPressed: () =>
                            context.read<ReceivingDispatchCubit>().loadData(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'بحث باسم الصنف أو كود الراك أو اسم المستلم...',
                      prefixIcon: Icon(LucideIcons.search),
                    ),
                    onChanged: (v) => _searchNotifier.value = v,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(LucideIcons.calendar, size: 16),
                        label: Text(
                          _fromDate == null
                              ? 'من تاريخ: الكل'
                              : 'من: ${_fmtDate(_fromDate!)}',
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _fromDate ?? DateTime.now(),
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2032),
                          );
                          if (picked != null) setState(() => _fromDate = picked);
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(LucideIcons.calendarCheck, size: 16),
                        label: Text(
                          _toDate == null
                              ? 'إلى تاريخ: الكل'
                              : 'إلى: ${_fmtDate(_toDate!)}',
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _toDate ?? DateTime.now(),
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2032),
                          );
                          if (picked != null) setState(() => _toDate = picked);
                        },
                      ),
                      ChoiceChip(
                        selected: _sourceFilter == null,
                        label: const Text('كل الجهات'),
                        onSelected: (_) => setState(() => _sourceFilter = null),
                      ),
                      ChoiceChip(
                        selected: _sourceFilter == ReceivingSource.production,
                        label: const Text('الإنتاج فقط'),
                        onSelected: (_) => setState(
                          () => _sourceFilter = ReceivingSource.production,
                        ),
                      ),
                      ChoiceChip(
                        selected:
                            _sourceFilter == ReceivingSource.qualityInspection,
                        label: const Text('فحص الجودة فقط'),
                        onSelected: (_) => setState(
                          () => _sourceFilter =
                              ReceivingSource.qualityInspection,
                        ),
                      ),
                      if (_fromDate != null ||
                          _toDate != null ||
                          _sourceFilter != null)
                        TextButton.icon(
                          icon: const Icon(LucideIcons.rotateCcw, size: 16),
                          label: const Text('مسح الفلاتر'),
                          onPressed: () => setState(() {
                            _fromDate = null;
                            _toDate = null;
                            _sourceFilter = null;
                            _searchNotifier.value = '';
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<String>(
            valueListenable: _searchNotifier,
            builder: (context, query, _) {
              final filtered = state.movements.where((m) {
                if (_sourceFilter != null && m.sourceEntity != _sourceFilter) {
                  return false;
                }
                if (_fromDate != null) {
                  final start = DateTime(
                    _fromDate!.year,
                    _fromDate!.month,
                    _fromDate!.day,
                  );
                  if (m.createdAt.isBefore(start)) return false;
                }
                if (_toDate != null) {
                  final end = DateTime(
                    _toDate!.year,
                    _toDate!.month,
                    _toDate!.day,
                    23,
                    59,
                    59,
                  );
                  if (m.createdAt.isAfter(end)) return false;
                }
                if (query.trim().isNotEmpty) {
                  final q = query.trim().toLowerCase();
                  final matchItem = m.itemName.toLowerCase().contains(q);
                  final matchUser = m.performedByName.toLowerCase().contains(q);
                  final matchSlot =
                      (m.toSlotCode ?? '').toLowerCase().contains(q) ||
                          (m.fromSlotCode ?? '').toLowerCase().contains(q);
                  if (!matchItem && !matchUser && !matchSlot) return false;
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('لا توجد حركات مطابقة للفلاتر المحددة.'),
                  ),
                );
              }

              final List<Widget> movementCards = [];
              for (final m in filtered) {
                movementCards.add(
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.zoneC2Blue.withValues(alpha: 0.12),
                        child: const Icon(
                          LucideIcons.arrowUpDown,
                          size: 18,
                          color: AppColors.zoneC2Blue,
                        ),
                      ),
                      title: Text(
                        '${m.movementType.arLabel}: ${m.itemName} (${m.quantityChanged} ${m.unit.arLabel})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الرصيد السابق: ${m.previousQuantity} -> الجديد: ${m.newQuantity} | الجهة: ${m.sourceEntity.arLabel}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'من: ${m.fromSlotCode ?? "-"} إلى: ${m.toSlotCode ?? "-"} | المنفذ: ${m.performedByName}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      trailing: Text(
                        _fmtDateTime(m.createdAt),
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }

              return Column(children: movementCards);
            },
          ),
        ],
      ),
    );
  }
}

class _RackGridInteractiveView extends StatelessWidget {
  final ReceivingDispatchState state;
  const _RackGridInteractiveView({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReceivingDispatchCubit>();
    final zoneRacks = state.slots
        .where((s) => s.zoneCode == state.selectedZone)
        .map((s) => s.rackLetter)
        .toSet()
        .toList()
      ..sort();

    return RepaintBoundary(
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'C2',
                          icon: Icon(LucideIcons.snowflake, size: 16),
                          label: Text('منطقة C2 (A - M)'),
                        ),
                        ButtonSegment(
                          value: 'C3',
                          icon: Icon(LucideIcons.snowflake, size: 16),
                          label: Text('منطقة C3 (N - Z)'),
                        ),
                      ],
                      selected: {state.selectedZone},
                      onSelectionChanged: (s) => cubit.selectZone(s.first),
                    ),
                    const Text(
                      'اضغط على البنة الفارغة للاستلام (موحد/ميكس) أو المشغولة للصرف/التزويد/التعديل',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: zoneRacks.map((letter) {
                      final isSelected = state.selectedRackLetter == letter;
                      final rackOccupied = state.slots
                          .where((s) => s.rackLetter == letter && s.isOccupied)
                          .length;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          selected: isSelected,
                          selectedColor: state.selectedZone == 'C2'
                              ? AppColors.zoneC2Blue
                              : AppColors.zoneC3Teal,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          label: Text('راك $letter ($rackOccupied/16)'),
                          onSelected: (_) => cubit.selectRackLetter(letter),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final cols = width >= 1150
                    ? 4
                    : width >= 750
                        ? 3
                        : width >= 500
                            ? 2
                            : 1;

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 192,
                  ),
                  itemCount: state.currentRackSlots.length,
                  itemBuilder: (context, idx) {
                    final slot = state.currentRackSlots[idx];
                    final pallet = slot.occupiedPallet;
                    final hasAlert = pallet?.hasCondemnationAlert ?? false;
                    final isMixed = pallet?.isMixed ?? false;

                    final Color borderColor = !slot.isOccupied
                        ? AppColors.borderLight
                        : hasAlert
                            ? AppColors.dangerRed
                            : isMixed
                                ? AppColors.mixedPurple
                                : AppColors.successGreen;

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
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
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: borderColor,
                            width: slot.isOccupied ? 2 : 1.2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryNavy,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Text(
                                      slot.slotCode,
                                      textDirection: TextDirection.ltr,
                                      style: const TextStyle(
                                        color: AppColors.accentCyan,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  if (slot.isOccupied && pallet != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isMixed
                                            ? AppColors.mixedPurple
                                                .withValues(alpha: 0.12)
                                            : AppColors.zoneC2Blue
                                                .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isMixed
                                            ? 'ميكس (${pallet.items.length} أصناف)'
                                            : 'موحدة',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: isMixed
                                              ? AppColors.mixedPurple
                                              : AppColors.zoneC2Blue,
                                        ),
                                      ),
                                    )
                                  else
                                    const Icon(
                                      LucideIcons.packagePlus,
                                      color: Colors.grey,
                                      size: 19,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (!slot.isOccupied || pallet == null) ...[
                                const Spacer(),
                                const Center(
                                  child: Text(
                                    'بنة فارغة - اضغط للاستلام والتسكين',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                              ] else ...[
                                Expanded(
                                  child: ListView(
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    children: pallet.items.take(2).map((item) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 3),
                                        child: Text(
                                          '• ${item.itemName} (${item.quantity} ${item.unit.arLabel})',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                if (pallet.items.length > 2)
                                  Text(
                                    '+ ${pallet.items.length - 2} أصناف أخرى...',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                const Divider(height: 10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      pallet.items.first.sourceEntity.arLabel,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      'متبقي: ${pallet.minDaysUntilExpiry} يوم',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: hasAlert
                                            ? AppColors.dangerRed
                                            : AppColors.successGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showReceiveOrAddSheet({
    required BuildContext context,
    required ReceivingRackSlotEntity slot,
    String? existingPalletId,
  }) {
    final cubit = context.read<ReceivingDispatchCubit>();
    ReceivingSource selectedSource = ReceivingSource.production;
    final List<PalletItemDraft> drafts = [PalletItemDraft()];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isAddingToExisting = existingPalletId != null;
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            isAddingToExisting
                                ? 'تزويد أصناف جديدة على البالتة في [${slot.slotCode}]'
                                : 'استلام وتسكين بالتة في الموقع [${slot.slotCode}]',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
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
                            color: drafts.length > 1
                                ? AppColors.mixedPurple.withValues(alpha: 0.12)
                                : AppColors.zoneC2Blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            drafts.length > 1
                                ? 'بالتة ميكس (${drafts.length} أصناف)'
                                : 'صنف واحد',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: drafts.length > 1
                                  ? AppColors.mixedPurple
                                  : AppColors.zoneC2Blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<ReceivingSource>(
                      value: selectedSource,
                      decoration: const InputDecoration(
                        labelText: 'الجهة المستلمة (الإنتاج / فحص الجودة)',
                        prefixIcon: Icon(LucideIcons.building2),
                      ),
                      items: ReceivingSource.values
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.arLabel),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedSource = v);
                      },
                    ),
                    const SizedBox(height: 14),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: drafts.length,
                        itemBuilder: (context, idx) {
                          final draft = drafts[idx];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.scaffoldBackground,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'بيانات الصنف #${idx + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryNavy,
                                      ),
                                    ),
                                    if (drafts.length > 1)
                                      IconButton(
                                        icon: const Icon(
                                          LucideIcons.trash2,
                                          color: AppColors.dangerRed,
                                          size: 19,
                                        ),
                                        onPressed: () => setModalState(
                                          () => drafts.removeAt(idx),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  initialValue: draft.itemName,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'اسم الصنف (مثال: 105 طبيعي أو 170 وفر)',
                                    prefixIcon: Icon(LucideIcons.package),
                                  ),
                                  onChanged: (v) => draft.itemName = v,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: draft.quantity.toString(),
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                          labelText: 'الكمية',
                                          prefixIcon: Icon(LucideIcons.hash),
                                        ),
                                        onChanged: (v) => draft.quantity =
                                            double.tryParse(v) ?? 0,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: DropdownButtonFormField<
                                          PackageUnit>(
                                        value: draft.unit,
                                        decoration: const InputDecoration(
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
                                            setModalState(() => draft.unit = u);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(
                                          LucideIcons.calendar,
                                          size: 16,
                                        ),
                                        label: Text(
                                          'إنتاج: ${intl.DateFormat('yyyy-MM-dd').format(draft.productionDate)}',
                                        ),
                                        onPressed: () async {
                                          final picked = await showDatePicker(
                                            context: ctx,
                                            initialDate: draft.productionDate,
                                            firstDate: DateTime(2023),
                                            lastDate: DateTime(2032),
                                          );
                                          if (picked != null) {
                                            setModalState(
                                              () => draft.productionDate =
                                                  picked,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(
                                          LucideIcons.calendarClock,
                                          size: 16,
                                        ),
                                        label: Text(
                                          'انتهاء: ${intl.DateFormat('yyyy-MM-dd').format(draft.expiryDate)}',
                                        ),
                                        onPressed: () async {
                                          final picked = await showDatePicker(
                                            context: ctx,
                                            initialDate: draft.expiryDate,
                                            firstDate: DateTime(2023),
                                            lastDate: DateTime(2036),
                                          );
                                          if (picked != null) {
                                            setModalState(
                                              () => draft.expiryDate = picked,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    AppActionButton(
                      label: 'إضافة صنف آخر على نفس البالتة (بالتة ميكس)',
                      icon: LucideIcons.plus,
                      variant: AppButtonVariant.outline,
                      fullWidth: true,
                      onPressed: () =>
                          setModalState(() => drafts.add(PalletItemDraft())),
                    ),
                    const SizedBox(height: 10),
                    AppActionButton(
                      label: isAddingToExisting
                          ? 'تأكيد تزويد الأصناف على البالتة'
                          : 'تأكيد الاستلام والتسكين (${drafts.length} أصناف)',
                      icon: LucideIcons.check,
                      fullWidth: true,
                      variant: AppButtonVariant.success,
                      onPressed: () async {
                        final allValid = drafts.every((d) => d.isValid);
                        if (!allValid) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'تأكد من كتابة اسم الصنف، كمية أكبر من صفر، وتاريخ انتهاء بعد تاريخ الإنتاج.',
                              ),
                              backgroundColor: AppColors.dangerRed,
                            ),
                          );
                          return;
                        }
                        Navigator.of(ctx).pop();
                        if (isAddingToExisting) {
                          await cubit.addItemsToExistingPallet(
                            palletId: existingPalletId,
                            sourceEntity: selectedSource,
                            items: drafts,
                          );
                        } else {
                          await cubit.receiveNewPallet(
                            sourceEntity: selectedSource,
                            slotId: slot.id,
                            items: drafts,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إدارة البالتة في الموقع [${slot.slotCode}]',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                          Text(
                            'مرجع: ${pallet.palletReference} | ${pallet.isMixed ? "بالتة ميكس (${pallet.items.length} أصناف)" : "بالتة موحدة"}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppActionButton(
                      label: 'تزويد صنف جديد',
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
                const Divider(height: 22),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.itemName} (${item.quantity} ${item.unit.arLabel})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
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
                                    label: 'صرف',
                                    icon: LucideIcons.truck,
                                    variant: AppButtonVariant.primary,
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                      _showItemQuantityActionDialog(
                                        context: context,
                                        item: item,
                                        action: MovementActionType.dispatch,
                                      );
                                    },
                                  ),
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
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showItemQuantityActionDialog({
    required BuildContext context,
    required ReceivingPalletItemEntity item,
    required MovementActionType action,
  }) {
    final cubit = context.read<ReceivingDispatchCubit>();
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
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: action == MovementActionType.adjustQuantity
                      ? 'الكمية الفعلية الجديدة (الحالية: ${item.quantity})'
                      : 'الكمية المطلوبة (المتاح: ${item.quantity} ${item.unit.arLabel})',
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
              label: 'تأكيد (${action.arLabel})',
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

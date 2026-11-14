import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/responsive_shimmer.dart';
import '../../domain/entities/rack_transfer_entities.dart';
import '../cubit/rack_transfer_cubit.dart';
import '../cubit/rack_transfer_state.dart';

class RackTransferPage extends StatefulWidget {
  final bool historyOnly;

  const RackTransferPage({super.key, this.historyOnly = false});

  @override
  State<RackTransferPage> createState() => _RackTransferPageState();
}

class _RackTransferPageState extends State<RackTransferPage> {
  final TextEditingController _notesCtrl = TextEditingController(
    text: 'تحويل تنظيمي بين الراكات',
  );
  final TextEditingController _historySearchCtrl = TextEditingController();

  static const _pageBg = Color(0xFFF5F7FA);
  static const _border = Color(0xFFE3E8EF);
  static const _muted = Color(0xFF687386);

  @override
  void dispose() {
    _notesCtrl.dispose();
    _historySearchCtrl.dispose();
    super.dispose();
  }

  String _fmtDateTime(DateTime d) =>
      intl.DateFormat('yyyy-MM-dd  HH:mm').format(d);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _pageBg,
      child: BlocConsumer<RackTransferCubit, RackTransferState>(
        listenWhen: (previous, current) =>
            previous.failure != current.failure ||
            previous.successMessage != current.successMessage,
        listener: (context, state) {
          final isOffstage =
              context.findAncestorWidgetOfExactType<Offstage>()?.offstage ??
              false;
          if (isOffstage) return;

          if (state.failure != null) {
            _showMessage(context, state.failure!.message, isError: true);
          } else if (state.successMessage != null) {
            _showMessage(context, state.successMessage!);
          }
        },
        builder: (context, state) {
          if (state.isLoading) {
            return const ResponsiveColdStorageShimmer(
              mode: ShimmerLayoutMode.tableList,
            );
          }
          if (widget.historyOnly) {
            return _buildHistoryTab(context, state);
          }
          return _buildTransferTab(context, state);
        },
      ),
    );
  }

  void _showMessage(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? AppColors.dangerRed
              : AppColors.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  Widget _buildTransferTab(BuildContext context, RackTransferState state) {
    final cubit = context.read<RackTransferCubit>();
    final source = state.selectedSourceSlot;
    final target = state.selectedTargetSlot;
    final occupied = state.occupiedSlots;
    final empty = state.filteredEmptySlots;
    final hasAnyEmpty = state.allSlots.any((s) => !s.isOccupied);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        final horizontalPadding = constraints.maxWidth >= 1200 ? 32.0 : 18.0;

        if (occupied.isEmpty) {
          return Center(
            child: _emptyState(
              'لا توجد بالتات مسكنة حالياً',
              'عند تسكين بالتة على أحد المواقع ستظهر هنا لتتمكن من نقلها',
              LucideIcons.packageOpen,
              onRefresh: () => cubit.loadTransferData(),
            ),
          );
        }

        final sourcePanel = _selectionPanel(
          step: '01',
          title: 'البالتة المراد نقلها',
          subtitle: 'اختر الراك المشغول الذي توجد عليه البالتة',
          icon: LucideIcons.packageCheck,
          accent: AppColors.primaryNavy,
          value: source?.slotCode ?? 'اختر الراك المصدر',
          hint: source == null
              ? 'اضغط للبحث والاختيار'
              : _sourceSummary(source),
          onTap: () async {
            final id = await _openSlotPicker(
              context,
              title: 'اختيار الراك المصدر',
              subtitle: 'ابحث بكود الراك أو اسم الصنف أو رقم البالتة',
              slots: occupied,
              selectedId: source?.slotId,
              isSource: true,
            );
            if (id != null) cubit.selectSourceSlot(id);
          },
          selected: source != null,
        );

        final targetPanel = _selectionPanel(
          step: '02',
          title: 'مكان التخزين الجديد',
          subtitle: 'اختر موقعاً فارغاً لنقل البالتة إليه',
          icon: LucideIcons.mapPin,
          accent: AppColors.zoneC3Teal,
          value: target?.slotCode ?? 'اختر الراك الوجهة',
          hint: target == null
              ? 'اضغط للبحث والاختيار'
              : _targetSummary(target),
          onTap: !hasAnyEmpty
              ? null
              : () async {
                  final id = await _openSlotPicker(
                    context,
                    title: 'اختيار مكان التخزين الجديد',
                    subtitle: 'ابحث بكود الراك وحدد المنطقة المناسبة',
                    slots: state.allSlots.where((s) => !s.isOccupied).toList(),
                    selectedId: target?.slotId,
                    isSource: false,
                    initialZone: state.targetZoneFilter,
                  );
                  if (id != null) cubit.selectTargetSlot(id);
                },
          selected: target != null,
          disabled: !hasAnyEmpty,
        );

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                24,
                horizontalPadding,
                32,
              ),
              children: [
                _buildIntro(context, state),
                const SizedBox(height: 22),
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: sourcePanel),
                      const SizedBox(width: 18),
                      Expanded(child: targetPanel),
                    ],
                  )
                else ...[
                  sourcePanel,
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _border),
                      ),
                      child: const Icon(
                        LucideIcons.arrowDown,
                        color: _muted,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  targetPanel,
                ],
                if (source != null) ...[
                  const SizedBox(height: 18),
                  _sourceDetails(source),
                ],
                const SizedBox(height: 22),
                _zoneFilter(state, cubit),
                if (empty.isEmpty) ...[
                  const SizedBox(height: 12),
                  _inlineNotice(
                    'لا توجد مواقع فارغة في المنطقة المحددة',
                    'غيّر المنطقة إلى الكل أو اختر منطقة أخرى',
                    LucideIcons.info,
                  ),
                ],
                const SizedBox(height: 22),
                _notesField(),
                const SizedBox(height: 20),
                _transferPreview(source, target),
                const SizedBox(height: 18),
                AppActionButton(
                  label: 'تأكيد نقل البالتة',
                  icon: LucideIcons.arrowLeftRight,
                  fullWidth: true,
                  isLoading: state.isSubmitting,
                  variant: AppButtonVariant.primary,
                  onPressed: () {
                    if (source == null || target == null || state.isSubmitting) {
                      return;
                    }
                    FocusScope.of(context).unfocus();
                    cubit.executeTransfer(notes: _notesCtrl.text);
                  },
                ),
                Builder(
                  builder: (ctx) => SizedBox(
                    height: MediaQuery.viewInsetsOf(ctx).bottom,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIntro(BuildContext context, RackTransferState state) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'نقل البالتات بين مواقع التخزين',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryNavy,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'حدد البالتة الحالية ثم اختر موقعها الجديد',
              style: TextStyle(fontSize: 13, color: _muted),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statPill(
              '${state.occupiedSlots.length} مشغول',
              AppColors.primaryNavy,
            ),
            const SizedBox(width: 8),
            _statPill(
              '${state.filteredEmptySlots.length} فارغ',
              AppColors.zoneC3Teal,
            ),
            const SizedBox(width: 8),
            _refreshButton(
              onPressed: () =>
                  context.read<RackTransferCubit>().loadTransferData(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _refreshButton({required VoidCallback onPressed}) {
    return Tooltip(
      message: 'تحديث البيانات',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: _border),
            ),
            child: const Icon(
              LucideIcons.refreshCw,
              size: 16,
              color: AppColors.primaryNavy,
            ),
          ),
        ),
      ),
    );
  }

  Widget _statPill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: color.withValues(alpha: .16)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );

  Widget _selectionPanel({
    required String step,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required String value,
    required String hint,
    required VoidCallback? onTap,
    required bool selected,
    bool disabled = false,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? accent.withValues(alpha: .42) : _border,
              width: selected ? 1.4 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080D1B2A),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
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
                      color: accent.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: accent, size: 19),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(fontSize: 11, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    step,
                    style: TextStyle(
                      color: accent.withValues(alpha: .7),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: disabled
                      ? const Color(0xFFF5F6F8)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: disabled ? _muted : AppColors.primaryNavy,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            hint,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      disabled ? LucideIcons.lock : LucideIcons.search,
                      color: disabled ? Colors.grey : accent,
                      size: 19,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    selected ? LucideIcons.checkCircle2 : LucideIcons.search,
                    size: 14,
                    color: selected ? accent : _muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    selected ? 'تم تحديد الموقع' : 'اضغط لفتح قائمة البحث',
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? accent : _muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _sourceSummary(TransferSlotEntity slot) {
    final items = slot.items
        .map((e) => e.itemName)
        .where((e) => e.isNotEmpty)
        .toSet();
    final itemText = items.isEmpty ? 'بالتة مشغولة' : items.join('، ');
    return '${slot.palletReference ?? 'بدون رقم بالتة'} · $itemText';
  }

  String _targetSummary(TransferSlotEntity slot) =>
      '${slot.zoneCode} · راك ${slot.rackLetter} · الطابق ${slot.floorNumber} · البِنّة ${slot.binNumber}';

  Widget _sourceDetails(TransferSlotEntity source) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE6F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.package,
                color: AppColors.primaryNavy,
                size: 17,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'محتويات البالتة المحددة',
                  style: TextStyle(
                    color: AppColors.primaryNavy,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              if (source.isMixed)
                _smallTag('بالتة ميكس', const Color(0xFF8A5A00))
              else
                _smallTag('صنف موحد', AppColors.successGreen),
            ],
          ),
          const SizedBox(height: 12),
          ...source.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.check,
                    size: 15,
                    color: AppColors.successGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.itemName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${_qty(item.quantity)} ${item.unitArLabel}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryNavy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'متبقي ${item.daysUntilExpiry} يوم',
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _qty(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);

  Widget _smallTag(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
    ),
  );

  Widget _zoneFilter(RackTransferState state, RackTransferCubit cubit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'تصفية مواقع الوجهة',
          style: TextStyle(
            color: AppColors.primaryNavy,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _zoneChip('كل المناطق', 'ALL', state.targetZoneFilter, cubit),
            _zoneChip('منطقة C2', 'C2', state.targetZoneFilter, cubit),
            _zoneChip('منطقة C3', 'C3', state.targetZoneFilter, cubit),
          ],
        ),
      ],
    );
  }

  Widget _zoneChip(
    String label,
    String value,
    String selected,
    RackTransferCubit cubit,
  ) {
    final active = selected == value;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => cubit.selectTargetZoneFilter(value),
      selectedColor: AppColors.primaryNavy,
      backgroundColor: Colors.white,
      side: BorderSide(color: active ? AppColors.primaryNavy : _border),
      labelStyle: TextStyle(
        color: active ? Colors.white : AppColors.primaryNavy,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      showCheckmark: true,
      checkmarkColor: Colors.white,
    );
  }

  Widget _notesField() {
    return TextField(
      controller: _notesCtrl,
      minLines: 1,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'ملاحظات التحويل (اختياري)',
        hintText: 'اكتب سبب أو تفاصيل النقل...',
        prefixIcon: const Icon(LucideIcons.fileText, size: 19),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
      ),
    );
  }

  Widget _transferPreview(
    TransferSlotEntity? source,
    TransferSlotEntity? target,
  ) {
    final ready = source != null && target != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ready ? const Color(0xFFEAF7F3) : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ready ? const Color(0xFFC8E8DC) : _border),
      ),
      child: Row(
        children: [
          Icon(
            ready ? LucideIcons.arrowLeftRight : LucideIcons.info,
            color: ready ? AppColors.successGreen : _muted,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ready
                  ? 'سيتم نقل البالتة من ${source.slotCode} إلى ${target.slotCode}'
                  : 'حدد الراك المصدر ومكان التخزين الجديد لمراجعة عملية النقل',
              style: TextStyle(
                color: ready ? const Color(0xFF176B50) : _muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _openSlotPicker(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<TransferSlotEntity> slots,
    required String? selectedId,
    required bool isSource,
    String initialZone = 'ALL',
  }) {
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    final content = _SlotPickerContent(
      title: title,
      subtitle: subtitle,
      slots: slots,
      selectedId: selectedId,
      isSource: isSource,
      initialZone: initialZone,
    );
    if (isWide) {
      return showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: SizedBox(width: 720, height: 680, child: content),
        ),
      );
    }
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: .88,
        minChildSize: .55,
        maxChildSize: .96,
        expand: false,
        builder: (context, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: Material(
            color: Colors.white,
            child: _SlotPickerContent(
              title: title,
              subtitle: subtitle,
              slots: slots,
              selectedId: selectedId,
              isSource: isSource,
              initialZone: initialZone,
              scrollController: scrollController,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab(BuildContext context, RackTransferState state) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'سجل تحويلات الراكات',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'متابعة جميع حركات نقل البالتات بين مواقع التخزين',
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  _statPill(
                    '${state.history.length} عملية',
                    AppColors.primaryNavy,
                  ),
                  const SizedBox(width: 8),
                  _refreshButton(
                    onPressed: () =>
                        context.read<RackTransferCubit>().loadTransferData(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: TextField(
                controller: _historySearchCtrl,
                decoration: InputDecoration(
                  hintText: 'ابحث باسم الصنف أو كود الراك أو اسم المستخدم...',
                  prefixIcon: const Icon(LucideIcons.search),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _historySearchCtrl,
                    builder: (_, val, __) => val.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            onPressed: () => _historySearchCtrl.clear(),
                            icon: const Icon(LucideIcons.x),
                          ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: _border),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _historySearchCtrl,
                builder: (context, searchVal, _) {
                  final q = searchVal.text.trim().toLowerCase();
                  final filtered = q.isEmpty
                      ? state.history
                      : state.history
                            .where(
                              (h) =>
                                  h.itemName.toLowerCase().contains(q) ||
                                  h.fromSlotCode.toLowerCase().contains(q) ||
                                  h.toSlotCode.toLowerCase().contains(q) ||
                                  h.performedByName.toLowerCase().contains(q),
                            )
                            .toList();

                  if (filtered.isEmpty) {
                    return _emptyState(
                      'لا توجد عمليات تحويل مطابقة',
                      'جرّب البحث بكلمة أو كود مختلف',
                      LucideIcons.history,
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final desktop = constraints.maxWidth >= 760;
                      if (desktop) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
                          child: _historyTable(filtered),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _historyCard(filtered[i]),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyCard(RackTransferHistoryEntity h) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${h.itemName} · ${_qty(h.quantity)} ${h.unitArLabel}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.primaryNavy,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _historyLocation('من', h.fromSlotCode, Colors.redAccent),
            ),
            const Icon(LucideIcons.arrowLeftRight, size: 17, color: _muted),
            Expanded(
              child: _historyLocation(
                'إلى',
                h.toSlotCode,
                AppColors.successGreen,
              ),
            ),
          ],
        ),
        const Divider(height: 22),
        Text(
          '${h.performedByName}  ·  ${_fmtDateTime(h.createdAt)}',
          style: const TextStyle(fontSize: 11, color: _muted),
        ),
        if (h.notes.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(h.notes, style: const TextStyle(fontSize: 12, color: _muted)),
        ],
      ],
    ),
  );

  Widget _historyLocation(String label, String code, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: _muted)),
      const SizedBox(height: 3),
      Text(
        code,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );

  Widget _historyTable(List<RackTransferHistoryEntity> rows) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF0F4F8)),
        columns: const [
          DataColumn(label: Text('الصنف')),
          DataColumn(label: Text('الكمية')),
          DataColumn(label: Text('من')),
          DataColumn(label: Text('إلى')),
          DataColumn(label: Text('بواسطة')),
          DataColumn(label: Text('التاريخ')),
        ],
        rows: rows
            .map(
              (h) => DataRow(
                cells: [
                  DataCell(Text(h.itemName)),
                  DataCell(Text('${_qty(h.quantity)} ${h.unitArLabel}')),
                  DataCell(
                    Text(
                      h.fromSlotCode,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                  DataCell(
                    Text(
                      h.toSlotCode,
                      style: const TextStyle(color: AppColors.successGreen),
                    ),
                  ),
                  DataCell(Text(h.performedByName)),
                  DataCell(Text(_fmtDateTime(h.createdAt))),
                ],
              ),
            )
            .toList(),
      ),
    ),
  );

  Widget _inlineNotice(String title, String subtitle, IconData icon) =>
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1E2B8)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF9A6A00), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF805900),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8B7442),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _emptyState(
    String title,
    String subtitle,
    IconData icon, {
    VoidCallback? onRefresh,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF0F6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 29, color: AppColors.primaryNavy),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
          if (onRefresh != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(LucideIcons.refreshCw, size: 15),
              label: const Text('تحديث البيانات'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _SlotPickerContent extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<TransferSlotEntity> slots;
  final String? selectedId;
  final bool isSource;
  final String initialZone;
  final ScrollController? scrollController;

  const _SlotPickerContent({
    required this.title,
    required this.subtitle,
    required this.slots,
    required this.selectedId,
    required this.isSource,
    required this.initialZone,
    this.scrollController,
  });

  @override
  State<_SlotPickerContent> createState() => _SlotPickerContentState();
}

class _SlotPickerContentState extends State<_SlotPickerContent> {
  final TextEditingController _searchCtrl = TextEditingController();
  late String _zone = widget.initialZone;
  late Map<String, String> _searchIndex;

  @override
  void initState() {
    super.initState();
    _buildSearchIndex();
  }

  @override
  void didUpdateWidget(covariant _SlotPickerContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.slots, widget.slots)) {
      _buildSearchIndex();
    }
  }

  void _buildSearchIndex() {
    _searchIndex = {
      for (final slot in widget.slots)
        slot.slotId: <String>[
          slot.slotCode,
          slot.zoneCode,
          slot.rackLetter,
          slot.palletReference ?? '',
          'راك ${slot.rackLetter}',
          'طابق ${slot.floorNumber}',
          'بنة ${slot.binNumber}',
          ...slot.items.map((e) => e.itemName),
        ].join(' ').toLowerCase(),
    };
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<TransferSlotEntity> _filterSlots(String query) {
    final q = query.trim().toLowerCase();
    return widget.slots.where((slot) {
      if (!widget.isSource && _zone != 'ALL' && slot.zoneCode != _zone) {
        return false;
      }
      if (q.isEmpty) return true;
      return (_searchIndex[slot.slotId] ?? '').contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.isSource
                      ? LucideIcons.packageCheck
                      : LucideIcons.mapPin,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF687386),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'إغلاق',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: widget.isSource
                  ? 'ابحث بكود الراك أو اسم الصنف أو رقم البالتة'
                  : 'ابحث بكود الراك أو الحرف أو الطابق...',
              prefixIcon: const Icon(LucideIcons.search, size: 20),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchCtrl,
                builder: (_, val, __) => val.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        onPressed: () => _searchCtrl.clear(),
                        icon: const Icon(LucideIcons.x, size: 18),
                      ),
              ),
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 15,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE3E8EF)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE3E8EF)),
              ),
            ),
          ),
        ),
        if (!widget.isSource) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 7,
                children: [
                  _filterChip('الكل', 'ALL'),
                  _filterChip('C2', 'C2'),
                  _filterChip('C3', 'C3'),
                ],
              ),
            ),
          ),
        ],
        Expanded(
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchCtrl,
            builder: (context, searchVal, _) {
              final results = _filterSlots(searchVal.text);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                    child: Row(
                      children: [
                        const Text(
                          'نتائج البحث',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryNavy,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${results.length} موقع',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF687386),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE9EDF2)),
                  Expanded(
                    child: results.isEmpty
                        ? _noResults()
                        : ListView.separated(
                            controller: widget.scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                            itemCount: results.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) =>
                                _slotTile(results[index]),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );

    if (widget.scrollController != null) {
      return body;
    }

    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: body,
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _zone == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _zone = value),
      selectedColor: AppColors.primaryNavy,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? AppColors.primaryNavy : const Color(0xFFE3E8EF),
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.primaryNavy,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _slotTile(TransferSlotEntity slot) {
    final selected = slot.slotId == widget.selectedId;
    final accent = widget.isSource
        ? AppColors.primaryNavy
        : AppColors.zoneC3Teal;
    return Material(
      color: selected ? accent.withValues(alpha: .055) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => Navigator.pop(context, slot.slotId),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: .55)
                  : const Color(0xFFE5EAF0),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.isSource ? LucideIcons.package : LucideIcons.mapPin,
                  color: accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            slot.slotCode,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                        ),
                        if (selected)
                          Icon(
                            LucideIcons.checkCircle2,
                            color: accent,
                            size: 18,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${slot.zoneCode}  ·  راك ${slot.rackLetter}  ·  الطابق ${slot.floorNumber}  ·  البِنّة ${slot.binNumber}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF687386),
                      ),
                    ),
                    if (widget.isSource) ...[
                      const SizedBox(height: 7),
                      if (slot.palletReference != null &&
                          slot.palletReference!.isNotEmpty)
                        Text(
                          'رقم البالتة: ${slot.palletReference}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.primaryNavy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const SizedBox(height: 4),
                      ...slot.items
                          .take(2)
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Row(
                                children: [
                                  const Icon(
                                    LucideIcons.box,
                                    size: 12,
                                    color: Color(0xFF8290A2),
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      item.itemName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF4B5666),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${_formatQty(item.quantity)} ${item.unitArLabel}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.primaryNavy,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      if (slot.items.length > 2)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            '+ ${slot.items.length - 2} أصناف أخرى',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF687386),
                            ),
                          ),
                        ),
                    ] else ...[
                      const SizedBox(height: 7),
                      const Text(
                        'موقع فارغ وجاهز لاستقبال البالتة',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.successGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                LucideIcons.chevronLeft,
                size: 17,
                color: Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _noResults() => const Center(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.search, size: 38, color: Color(0xFF9AA5B3)),
          SizedBox(height: 10),
          Text(
            'لا توجد نتائج مطابقة',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primaryNavy,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'تأكد من كلمة البحث أو جرّب كوداً آخر',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF687386)),
          ),
        ],
      ),
    ),
  );

  String _formatQty(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
}
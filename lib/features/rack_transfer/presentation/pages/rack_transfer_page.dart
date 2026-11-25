import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/responsive_shimmer.dart';
import '../../domain/entities/rack_transfer_entities.dart';
import '../cubit/rack_transfer_cubit.dart';
import '../cubit/rack_transfer_state.dart';
import 'rack_transfer_history_view.dart';

// =============================================================================
// ثوابت وأدوات مساعدة موحدة لشاشة تحويل الراكات
// =============================================================================
const _kTransferPageBg = Color(0xFFF5F7FA);
const _kTransferBorder = Color(0xFFE3E8EF);
const _kTransferMuted = Color(0xFF687386);

String _formatTransferQty(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);

String _formatSlotLocation(TransferSlotEntity slot) =>
    '${slot.zoneCode} · راك ${slot.rackLetter} · الطابق ${slot.floorNumber} · البِنّة ${slot.binNumber}';

String _formatPalletTotals(TransferSlotEntity slot) {
  final byUnit = <String, double>{};
  for (final item in slot.items) {
    byUnit[item.unitArLabel] = (byUnit[item.unitArLabel] ?? 0) + item.quantity;
  }
  if (byUnit.isEmpty) {
    return '0';
  }
  return byUnit.entries
      .map((e) => '${_formatTransferQty(e.value)} ${e.key}')
      .join(' + ');
}

// =============================================================================
// الشاشة الرئيسية لتحويل الراكات (وتُفوّض السجل لـ RackTransferHistoryView)
// =============================================================================
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

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _kTransferPageBg,
      child: BlocConsumer<RackTransferCubit, RackTransferState>(
        listenWhen: (previous, current) =>
            previous.failure != current.failure ||
            previous.successMessage != current.successMessage,
        listener: (context, state) {
          final isOffstage =
              context.findAncestorWidgetOfExactType<Offstage>()?.offstage ??
              false;
          if (isOffstage) {
            return;
          }

          if (state.failure != null) {
            _showMessage(context, state.failure!.message, isError: true);
          } else if (state.successMessage != null) {
            _showMessage(context, state.successMessage!);
          }
        },
        buildWhen: (previous, current) {
          if (widget.historyOnly) {
            return false;
          }
          return previous.isLoading != current.isLoading ||
              previous.isSubmitting != current.isSubmitting ||
              previous.allSlots != current.allSlots ||
              previous.selectedSourceSlotId != current.selectedSourceSlotId ||
              previous.selectedTargetSlotId != current.selectedTargetSlotId ||
              previous.targetZoneFilter != current.targetZoneFilter;
        },
        builder: (context, state) {
          if (widget.historyOnly) {
            return const RackTransferHistoryView();
          }
          if (state.isLoading) {
            return const ResponsiveColdStorageShimmer(
              mode: ShimmerLayoutMode.tableList,
            );
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
        final isDesktop = constraints.maxWidth >= 860;
        final horizontalPadding = isDesktop ? 24.0 : 14.0;

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

        final sourcePanel = _SelectionPanel(
          step: '01',
          title: 'البالتة المراد نقلها',
          subtitle: 'اختر الراك المشغول الذي توجد عليه البالتة',
          icon: LucideIcons.packageCheck,
          accent: AppColors.primaryNavy,
          value: source?.slotCode ?? 'اختر الراك المصدر',
          hint: source == null
              ? 'اضغط للبحث والاختيار'
              : _sourceSummary(source),
          selected: source != null,
          onTap: () async {
            final id = await _openSlotPicker(
              context,
              title: 'اختيار الراك المصدر',
              subtitle: 'ابحث بكود الراك أو اسم الصنف أو رقم البالتة',
              slots: occupied,
              selectedId: source?.slotId,
              isSource: true,
            );
            if (id != null) {
              cubit.selectSourceSlot(id);
            }
          },
        );

        final targetPanel = _SelectionPanel(
          step: '02',
          title: 'مكان التخزين الجديد',
          subtitle: 'اختر موقعاً فارغاً لنقل البالتة إليه',
          icon: LucideIcons.mapPin,
          accent: AppColors.zoneC3Teal,
          value: target?.slotCode ?? 'اختر الراك الوجهة',
          hint: target == null
              ? 'اضغط للبحث والاختيار'
              : _formatSlotLocation(target),
          selected: target != null,
          disabled: !hasAnyEmpty,
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
                  if (id != null) {
                    cubit.selectTargetSlot(id);
                  }
                },
        );

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                isDesktop ? 20 : 12,
                horizontalPadding,
                28,
              ),
              children: [
                _buildTransferHeader(context, state, isDesktop),
                SizedBox(height: isDesktop ? 18 : 12),
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: sourcePanel),
                      const SizedBox(width: 16),
                      Expanded(child: targetPanel),
                    ],
                  )
                else ...[
                  sourcePanel,
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _kTransferBorder),
                      ),
                      child: const Icon(
                        LucideIcons.arrowDown,
                        color: _kTransferMuted,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  targetPanel,
                ],
                if (source != null) ...[
                  const SizedBox(height: 14),
                  _SourcePalletDetailsCard(source: source),
                ],
                const SizedBox(height: 16),
                _buildZoneFilterBar(state, cubit),
                if (empty.isEmpty) ...[
                  const SizedBox(height: 12),
                  _inlineNotice(
                    'لا توجد مواقع فارغة في المنطقة المحددة',
                    'غيّر المنطقة إلى الكل أو اختر منطقة أخرى',
                    LucideIcons.info,
                  ),
                ],
                const SizedBox(height: 16),
                _buildNotesField(),
                const SizedBox(height: 14),
                _transferPreview(source, target),
                const SizedBox(height: 14),
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
                  builder: (ctx) =>
                      SizedBox(height: MediaQuery.viewInsetsOf(ctx).bottom),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransferHeader(
    BuildContext context,
    RackTransferState state,
    bool isDesktop,
  ) {
    if (!isDesktop) {
      return Row(
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
          const Spacer(),
          _refreshButton(
            onPressed: () =>
                context.read<RackTransferCubit>().loadTransferData(),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Expanded(
          child: Column(
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
              SizedBox(height: 4),
              Text(
                'حدد البالتة الحالية ثم اختر موقعها الجديد',
                style: TextStyle(fontSize: 12.5, color: _kTransferMuted),
              ),
            ],
          ),
        ),
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
          onPressed: () => context.read<RackTransferCubit>().loadTransferData(),
        ),
      ],
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

  Widget _buildZoneFilterBar(
    RackTransferState state,
    RackTransferCubit cubit,
  ) {
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
            _ZoneFilterChip(
              label: 'كل المناطق',
              selected: state.targetZoneFilter == 'ALL',
              onTap: () => cubit.selectTargetZoneFilter('ALL'),
            ),
            _ZoneFilterChip(
              label: 'منطقة C2',
              selected: state.targetZoneFilter == 'C2',
              onTap: () => cubit.selectTargetZoneFilter('C2'),
            ),
            _ZoneFilterChip(
              label: 'منطقة C3',
              selected: state.targetZoneFilter == 'C3',
              onTap: () => cubit.selectTargetZoneFilter('C3'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotesField() {
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
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kTransferBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kTransferBorder),
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
        border: Border.all(
          color: ready ? const Color(0xFFC8E8DC) : _kTransferBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            ready ? LucideIcons.arrowLeftRight : LucideIcons.info,
            color: ready ? AppColors.successGreen : _kTransferMuted,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ready
                  ? 'سيتم نقل البالتة من ${source.slotCode} إلى ${target.slotCode}'
                  : 'حدد الراك المصدر ومكان التخزين الجديد لمراجعة عملية النقل',
              style: TextStyle(
                color: ready ? const Color(0xFF176B50) : _kTransferMuted,
                fontSize: 12.5,
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
    if (isWide) {
      return showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: SizedBox(
            width: 700,
            height: 660,
            child: _SlotPickerContent(
              title: title,
              subtitle: subtitle,
              slots: slots,
              selectedId: selectedId,
              isSource: isSource,
              initialZone: initialZone,
            ),
          ),
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

  Widget _refreshButton({required VoidCallback onPressed}) => Tooltip(
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
            border: Border.all(color: _kTransferBorder),
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
            style: const TextStyle(fontSize: 12, color: _kTransferMuted),
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

// =============================================================================
// مكونات مساعدة مشتركة داخل شاشة تحويل الراكات
// =============================================================================
class _ZoneFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ZoneFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primaryNavy,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? AppColors.primaryNavy : _kTransferBorder,
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.primaryNavy,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      showCheckmark: true,
      checkmarkColor: Colors.white,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _SearchInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Color fillColor;

  const _SearchInputField({
    required this.controller,
    required this.hintText,
    this.fillColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(LucideIcons.search, size: 19),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, val, _) => val.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  onPressed: controller.clear,
                  icon: const Icon(LucideIcons.x, size: 17),
                ),
        ),
        filled: true,
        fillColor: fillColor,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kTransferBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kTransferBorder),
        ),
      ),
    );
  }
}

class _SelectionPanel extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String value;
  final String hint;
  final VoidCallback? onTap;
  final bool selected;
  final bool disabled;

  const _SelectionPanel({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.value,
    required this.hint,
    required this.onTap,
    required this.selected,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? accent.withValues(alpha: .42) : _kTransferBorder,
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
                          style: const TextStyle(
                            fontSize: 11,
                            color: _kTransferMuted,
                          ),
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
              const SizedBox(height: 15),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: disabled
                      ? const Color(0xFFF5F6F8)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: _kTransferBorder),
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
                              fontSize: 14.5,
                              color: disabled
                                  ? _kTransferMuted
                                  : AppColors.primaryNavy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hint,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _kTransferMuted,
                            ),
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
                    color: selected ? accent : _kTransferMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    selected ? 'تم تحديد الموقع' : 'اضغط لفتح قائمة البحث',
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? accent : _kTransferMuted,
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
}

class _SourcePalletDetailsCard extends StatelessWidget {
  final TransferSlotEntity source;

  const _SourcePalletDetailsCard({required this.source});

  @override
  Widget build(BuildContext context) {
    final tagColor = source.isMixed
        ? const Color(0xFF8A5A00)
        : AppColors.successGreen;

    return Container(
      padding: const EdgeInsets.all(15),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  source.isMixed
                      ? 'بالتة ميكس (${source.items.length} أصناف)'
                      : 'صنف موحد',
                  style: TextStyle(
                    color: tagColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          ...source.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
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
                    '${_formatTransferQty(item.quantity)} ${item.unitArLabel}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryNavy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'متبقي ${item.daysUntilExpiry} يوم',
                    style: const TextStyle(fontSize: 11, color: _kTransferMuted),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 16, color: Color(0xFFD0DCEB)),
          Row(
            children: [
              const Text(
                'إجمالي كمية البالتة:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _kTransferMuted,
                ),
              ),
              const Spacer(),
              Text(
                _formatPalletTotals(source),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryNavy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// منتقي المواقع بالبحث السريع (للكمبيوتر والموبايل)
// =============================================================================
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
      if (q.isEmpty) {
        return true;
      }
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
                        color: _kTransferMuted,
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
          child: _SearchInputField(
            controller: _searchCtrl,
            fillColor: _kTransferPageBg,
            hintText: widget.isSource
                ? 'ابحث بكود الراك أو اسم الصنف أو رقم البالتة'
                : 'ابحث بكود الراك أو الحرف أو الطابق...',
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
                  _ZoneFilterChip(
                    label: 'الكل',
                    selected: _zone == 'ALL',
                    onTap: () => setState(() => _zone = 'ALL'),
                  ),
                  _ZoneFilterChip(
                    label: 'C2',
                    selected: _zone == 'C2',
                    onTap: () => setState(() => _zone = 'C2'),
                  ),
                  _ZoneFilterChip(
                    label: 'C3',
                    selected: _zone == 'C3',
                    onTap: () => setState(() => _zone = 'C3'),
                  ),
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
                            color: _kTransferMuted,
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
                            separatorBuilder: (_, _) =>
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

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: body,
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
                      _formatSlotLocation(slot),
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: _kTransferMuted,
                      ),
                    ),
                    if (widget.isSource) ...[
                      const SizedBox(height: 7),
                      if (slot.palletReference != null &&
                          slot.palletReference!.isNotEmpty)
                        Text(
                          'رقم البالتة: ${slot.palletReference}',
                          style: const TextStyle(
                            fontSize: 10.5,
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
                                    '${_formatTransferQty(item.quantity)} ${item.unitArLabel}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
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
                              fontSize: 10.5,
                              color: _kTransferMuted,
                            ),
                          ),
                        ),
                    ] else ...[
                      const SizedBox(height: 7),
                      const Text(
                        'موقع فارغ وجاهز لاستقبال البالتة',
                        style: TextStyle(
                          fontSize: 10.5,
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
            style: TextStyle(fontSize: 11, color: _kTransferMuted),
          ),
        ],
      ),
    ),
  );
}
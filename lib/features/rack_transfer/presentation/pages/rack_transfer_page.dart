import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/responsive_shimmer.dart';
import '../cubit/rack_transfer_cubit.dart';
import '../cubit/rack_transfer_state.dart';

/// شاشة الموديول الرابع (التحويل والنقل بين الراكات C2 & C3):
/// - معزولة بـ RepaintBoundary و ValueNotifier لمنع أي Lag عند فتح الكيبورد
/// - تستخدم ResponsiveColdStorageShimmer و AppActionButton من core
class RackTransferPage extends StatefulWidget {
  const RackTransferPage({super.key});

  @override
  State<RackTransferPage> createState() => _RackTransferPageState();
}

class _RackTransferPageState extends State<RackTransferPage> {
  final TextEditingController _notesCtrl =
      TextEditingController(text: 'تحويل تنظيمي بين الراكات');
  final ValueNotifier<String> _historySearchNotifier = ValueNotifier<String>('');

  @override
  void dispose() {
    _notesCtrl.dispose();
    _historySearchNotifier.dispose();
    super.dispose();
  }

  String _fmtDateTime(DateTime d) => intl.DateFormat('yyyy-MM-dd HH:mm').format(d);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RackTransferCubit, RackTransferState>(
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
        if (state.isLoading) {
          return const ResponsiveColdStorageShimmer(
            mode: ShimmerLayoutMode.tableList,
          );
        }

        final cubit = context.read<RackTransferCubit>();
        final occupiedSlots = state.occupiedSlots;
        final emptySlots = state.filteredEmptySlots;
        final sourceSlot = state.selectedSourceSlot;
        final targetSlot = state.selectedTargetSlot;

        return RepaintBoundary(
          child: RefreshIndicator(
            onRefresh: () => cubit.loadTransferData(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. بطاقة تنفيذ التحويل الذري بين الراكات
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.arrowLeftRight,
                                    color: AppColors.zoneC3Teal,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'التحويل والنقل الذري بين الراكات (C2 & C3)',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryNavy,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AppActionButton(
                              label: 'تحديث المواقع',
                              icon: LucideIcons.refreshCw,
                              variant: AppButtonVariant.outline,
                              onPressed: () => cubit.loadTransferData(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'اختر الراك الحالي المشغول والراك الجديد الفارغ لنقل البالتة بكامل أصنافها (موحدة أو ميكس) في خطوة واحدة.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Divider(height: 24),
                        if (occupiedSlots.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'لا توجد أي بالتات مسكنة حالياً في الثلاجة لتحويلها.',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          )
                        else ...[
                          DropdownButtonFormField<String>(
                            value: sourceSlot?.slotId,
                            decoration: const InputDecoration(
                              labelText: '1. اختر الراك الحالي المشغول (المصدر)',
                              prefixIcon: Icon(LucideIcons.packageCheck),
                            ),
                            items: occupiedSlots.map((s) {
                              return DropdownMenuItem(
                                value: s.slotId,
                                child: Text(
                                  '${s.slotCode}  —  [${s.itemsPreviewText}]',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) cubit.selectSourceSlot(val);
                            },
                          ),
                          const SizedBox(height: 14),
                          if (sourceSlot != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.scaffoldBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderLight),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'محتويات البالتة في [${sourceSlot.slotCode}] (${sourceSlot.isMixed ? "بالتة ميكس" : "بالتة موحدة"}):',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ...sourceSlot.items.map(
                                    (item) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        '• الصنف: ${item.itemName} | الكمية: ${item.quantity} ${item.unitArLabel} | الجهة: ${item.sourceArLabel} | متبقي: ${item.daysUntilExpiry} يوم',
                                        style: const TextStyle(fontSize: 12.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'تصفية الراكات الفارغة:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              ChoiceChip(
                                selected: state.targetZoneFilter == 'ALL',
                                label: const Text('كل المناطق (C2 & C3)'),
                                onSelected: (_) =>
                                    cubit.selectTargetZoneFilter('ALL'),
                              ),
                              ChoiceChip(
                                selected: state.targetZoneFilter == 'C2',
                                label: const Text('منطقة C2 فقط (A - M)'),
                                onSelected: (_) =>
                                    cubit.selectTargetZoneFilter('C2'),
                              ),
                              ChoiceChip(
                                selected: state.targetZoneFilter == 'C3',
                                label: const Text('منطقة C3 فقط (N - Z)'),
                                onSelected: (_) =>
                                    cubit.selectTargetZoneFilter('C3'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (emptySlots.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'لا توجد بنات فارغة في هذه المنطقة حالياً.',
                                style: TextStyle(color: AppColors.dangerRed),
                              ),
                            )
                          else
                            DropdownButtonFormField<String>(
                              value: targetSlot?.slotId,
                              decoration: const InputDecoration(
                                labelText:
                                    '2. اختر الراك والبنة الجديدة الفارغة (الوجهة)',
                                prefixIcon: Icon(LucideIcons.mapPin),
                              ),
                              items: emptySlots.map((s) {
                                return DropdownMenuItem(
                                  value: s.slotId,
                                  child: Text(
                                    '${s.slotCode}  (منطقة ${s.zoneCode} - راك ${s.rackLetter} - دور ${s.floorNumber} - بنة ${s.binNumber})',
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) cubit.selectTargetSlot(val);
                              },
                            ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _notesCtrl,
                            decoration: const InputDecoration(
                              labelText: 'سبب / ملاحظات التحويل بين الراكات',
                              prefixIcon: Icon(LucideIcons.fileText),
                            ),
                          ),
                          const SizedBox(height: 16),
                          AppActionButton(
                            label: 'تأكيد التحويل والنقل الفوري للبالتة',
                            icon: LucideIcons.arrowLeftRight,
                            fullWidth: true,
                            isLoading: state.isSubmitting,
                            variant: AppButtonVariant.secondary,
                            onPressed: () =>
                                cubit.executeTransfer(notes: _notesCtrl.text),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. سجل التحويلات السابقة بين الراكات مع بحث بدون إعادة رسم الشاشة
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'سجل التحويلات السابقة بين الراكات (${state.history.length} حركة)',
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          decoration: const InputDecoration(
                            labelText:
                                'ابحث في سجل التحويلات باسم الصنف أو كود الراك أو اسم المستخدم...',
                            prefixIcon: Icon(LucideIcons.search),
                          ),
                          onChanged: (v) => _historySearchNotifier.value = v,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<String>(
                  valueListenable: _historySearchNotifier,
                  builder: (context, query, _) {
                    final filteredHistory = state.history.where((h) {
                      if (query.trim().isEmpty) return true;
                      final q = query.trim().toLowerCase();
                      return h.itemName.toLowerCase().contains(q) ||
                          h.fromSlotCode.toLowerCase().contains(q) ||
                          h.toSlotCode.toLowerCase().contains(q) ||
                          h.performedByName.toLowerCase().contains(q);
                    }).toList();

                    if (filteredHistory.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(28),
                        child: Center(
                          child: Text('لا توجد عمليات تحويل مطابقة للبحث.'),
                        ),
                      );
                    }

                    final List<Widget> historyCards = [];
                    for (final h in filteredHistory) {
                      historyCards.add(
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppColors.zoneC3Teal.withValues(alpha: 0.14),
                              child: const Icon(
                                LucideIcons.arrowLeftRight,
                                color: AppColors.zoneC3Teal,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              'نقل الصنف: ${h.itemName} (${h.quantity} ${h.unitArLabel})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'من الراك: [${h.fromSlotCode}]  ⬅️  إلى الراك: [${h.toSlotCode}]',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'المنفذ: ${h.performedByName} | ملاحظات: ${h.notes}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            trailing: Text(
                              _fmtDateTime(h.createdAt),
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

                    return Column(children: historyCards);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

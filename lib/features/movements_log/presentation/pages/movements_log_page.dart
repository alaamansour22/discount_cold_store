import 'package:discount_cold_store/features/movements_log/domain/entities/movements_log_entities.dart';
import 'package:discount_cold_store/features/receiving_dispatch/domain/entities/receiving_dispatch_entities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdf/pdf.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/cold_storage_pdf_service.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/responsive_shimmer.dart';
import '../cubit/movements_log_cubit.dart';
import '../cubit/movements_log_state.dart';

/// الموديول السابع: سجل الحركات الشامل (استلام، صرف، تحويل، إعدام، وتعديل كميات)
/// - مزود بشريط بحث لحظي ValueNotifier بدون إعادة رسم الشاشة بالكامل
/// - دعم الفلترة بالفترة الزمنية، نوع الحركة، والجهة المصدر
/// - طباعة تقرير PDF احترافي بخط Cairo
class MovementsLogPage extends StatefulWidget {
  const MovementsLogPage({super.key});

  @override
  State<MovementsLogPage> createState() => _MovementsLogPageState();
}

class _MovementsLogPageState extends State<MovementsLogPage> {
  final ValueNotifier<String> _searchNotifier = ValueNotifier<String>('');

  @override
  void dispose() {
    _searchNotifier.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) => intl.DateFormat('yyyy-MM-dd').format(d);
  String _fmtDateTime(DateTime d) =>
      intl.DateFormat('yyyy-MM-dd HH:mm').format(d);

  Future<void> _printMovementsPdf(
    MovementsLogState state,
    List<SystemMovementEntity> filteredList,
  ) async {
    final rows = filteredList.map((m) {
      return <String>[
        _fmtDateTime(m.createdAt),
        m.performedByName,
        m.movementType.arLabel,
        m.toSlotCode ?? m.fromSlotCode ?? '-',
        '${m.quantityChanged} ${m.unit.arLabel}',
        m.itemName,
        m.sourceEntity.arLabel,
        m.notes ?? '-',
      ];
    }).toList();

    await ColdStoragePdfService.printCustomTableReport(
      reportTitle: 'سجل الحركات المخزنية الشامل — ثلاجة مخفض (رمز C)',
      reportSubtitle:
          'إجمالي الحركات المطابقة: ${rows.length} | تاريخ الطباعة (توقيت مصر)',
      headers: const [
        'التوقيت',
        'المستخدم',
        'نوع الحركة',
        'موقع البنة',
        'الكمية',
        'اسم الصنف',
        'الجهة',
        'ملاحظات',
      ],
      rows: rows,
      fileName: 'comprehensive_movements_log.pdf',
      headerColor: PdfColors.indigo900,
    );
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

        return RepaintBoundary(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. بطاقة الفلاتر والبحث الشامل
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'سجل الحركات الشامل (استلام، صرف، تحويل، إعدام، وتعديل)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                          ),
                          AppActionButton(
                            label: 'تحديث السجل',
                            icon: LucideIcons.refreshCw,
                            variant: AppButtonVariant.outline,
                            onPressed: () => cubit.loadMovements(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          labelText:
                              'بحث لحظي باسم الصنف، كود الراك، المستخدم، أو الملاحظات...',
                          prefixIcon: Icon(LucideIcons.search),
                        ),
                        onChanged: (v) => _searchNotifier.value = v,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(LucideIcons.calendar, size: 16),
                            label: Text(
                              state.fromDate == null
                                  ? 'من تاريخ: الكل'
                                  : 'من: ${_fmtDate(state.fromDate!)}',
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: state.fromDate ?? DateTime.now(),
                                firstDate: DateTime(2024),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                await cubit.applyFilters(
                                  fromDate: picked,
                                  toDate: state.toDate,
                                  movementTypeFilter: state.movementTypeFilter,
                                  sourceFilter: state.sourceFilter,
                                );
                              }
                            },
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(LucideIcons.calendarCheck, size: 16),
                            label: Text(
                              state.toDate == null
                                  ? 'إلى تاريخ: الكل'
                                  : 'إلى: ${_fmtDate(state.toDate!)}',
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: state.toDate ?? DateTime.now(),
                                firstDate: DateTime(2024),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                await cubit.applyFilters(
                                  fromDate: state.fromDate,
                                  toDate: picked,
                                  movementTypeFilter: state.movementTypeFilter,
                                  sourceFilter: state.sourceFilter,
                                );
                              }
                            },
                          ),
                          // فلتر نوع الحركة
                          DropdownButton<MovementActionType?>(
                            value: state.movementTypeFilter,
                            hint: const Text('كل الحركات'),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('كل الحركات'),
                              ),
                              ...MovementActionType.values.map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(m.arLabel),
                                ),
                              ),
                            ],
                            onChanged: (val) async {
                              await cubit.applyFilters(
                                fromDate: state.fromDate,
                                toDate: state.toDate,
                                movementTypeFilter: val,
                                clearMovementType: val == null,
                                sourceFilter: state.sourceFilter,
                              );
                            },
                          ),
                          // فلتر الجهة
                          DropdownButton<ReceivingSource?>(
                            value: state.sourceFilter,
                            hint: const Text('كل الجهات'),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('كل الجهات'),
                              ),
                              ...ReceivingSource.values.map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s.arLabel),
                                ),
                              ),
                            ],
                            onChanged: (val) async {
                              await cubit.applyFilters(
                                fromDate: state.fromDate,
                                toDate: state.toDate,
                                movementTypeFilter: state.movementTypeFilter,
                                sourceFilter: val,
                                clearSource: val == null,
                              );
                            },
                          ),
                          if (state.fromDate != null ||
                              state.toDate != null ||
                              state.movementTypeFilter != null ||
                              state.sourceFilter != null)
                            TextButton.icon(
                              icon: const Icon(LucideIcons.rotateCcw, size: 16),
                              label: const Text('إعادة ضبط الفلاتر'),
                              onPressed: () {
                                _searchNotifier.value = '';
                                cubit.applyFilters(
                                  fromDate: null,
                                  toDate: null,
                                  clearMovementType: true,
                                  clearSource: true,
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 2. عرض النتائج مع طباعة PDF
              ValueListenableBuilder<String>(
                valueListenable: _searchNotifier,
                builder: (context, query, _) {
                  final filtered = state.movements.where((m) {
                    if (query.trim().isEmpty) return true;
                    final q = query.trim().toLowerCase();
                    return m.itemName.toLowerCase().contains(q) ||
                        m.performedByName.toLowerCase().contains(q) ||
                        (m.toSlotCode ?? '').toLowerCase().contains(q) ||
                        (m.fromSlotCode ?? '').toLowerCase().contains(q) ||
                        (m.notes ?? '').toLowerCase().contains(q);
                  }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AppActionButton(
                          label: 'تصدير السجل المصفى PDF (${filtered.length})',
                          icon: LucideIcons.printer,
                          variant: AppButtonVariant.primary,
                          onPressed: () => _printMovementsPdf(state, filtered),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'لا توجد حركات مخزنية مطابقة للبحث أو الفلاتر.',
                            ),
                          ),
                        )
                      else
                        ...filtered.map(
                          (m) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getMovementColor(m.movementType)
                                    .withValues(alpha: 0.14),
                                child: Icon(
                                  _getMovementIcon(m.movementType),
                                  color: _getMovementColor(m.movementType),
                                  size: 18,
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
                                    'الرصيد السابق: ${m.previousQuantity} ⬅️ الجديد: ${m.newQuantity} | الجهة: ${m.sourceEntity.arLabel}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    'الموقع: [${m.toSlotCode ?? m.fromSlotCode ?? "-"}] | المنفذ: ${m.performedByName}${m.notes != null && m.notes!.isNotEmpty ? " | ملاحظات: ${m.notes}" : ""}',
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
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getMovementColor(MovementActionType type) {
    switch (type) {
      case MovementActionType.receiveNew:
        return AppColors.successGreen;
      case MovementActionType.addItemToPallet:
        return AppColors.zoneC2Blue;
      case MovementActionType.dispatch:
        return AppColors.primaryNavy;
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
      case MovementActionType.condemn:
        return LucideIcons.flame;
      case MovementActionType.relocate:
        return LucideIcons.arrowLeftRight;
      case MovementActionType.adjustQuantity:
        return LucideIcons.slidersHorizontal;
    }
  }
}

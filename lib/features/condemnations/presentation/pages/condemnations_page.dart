import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdf/pdf.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/cold_storage_pdf_service.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/responsive_shimmer.dart';
import '../../domain/entities/condemnations_entities.dart';
import '../cubit/condemnations_cubit.dart';
import '../cubit/condemnations_state.dart';

/// شاشة الموديول الخامس: الإعدامات والبحث في سجل الإعدامات من فترة لفترة (من تاريخ -> إلى تاريخ)
/// - معزولة بـ RepaintBoundary و ValueNotifier لمنع أي Lag عند فتح الكيبورد
/// - مربوطة بخدمة ColdStoragePdfService لطباعة تقارير PDF بخط Cairo ولوجو الشركة
class CondemnationsPage extends StatefulWidget {
  const CondemnationsPage({super.key});

  @override
  State<CondemnationsPage> createState() => _CondemnationsPageState();
}

class _CondemnationsPageState extends State<CondemnationsPage> {
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');

  @override
  void dispose() {
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) => intl.DateFormat('yyyy-MM-dd').format(d);
  String _fmtDateTime(DateTime d) =>
      intl.DateFormat('yyyy-MM-dd HH:mm').format(d);

  Future<void> _printAlertsPdf(CondemnationsState state) async {
    final rows = state.alertItems.map((item) {
      final statusText = item.isExpired ? 'منتهي الصلاحية' : 'مستحق للإعدام';
      return <String>[
        statusText,
        item.daysUntilExpiry.toString(),
        _fmtDate(item.expiryDate),
        _fmtDate(item.productionDate),
        item.sourceArLabel,
        '${item.quantity} ${item.unitArLabel}',
        item.itemName,
        item.slotCode,
      ];
    }).toList();

    await ColdStoragePdfService.printCustomTableReport(
      reportTitle: 'تقرير الأصناف المستحقة للإعدام حالياً — ثلاجة مخفض (رمز C)',
      reportSubtitle:
          'حد الثلاجة العام: ${state.globalThresholdDays} يوم | تنبيه المستخدم: ${state.userCustomAlertDays} يوم | العدد: ${rows.length}',
      headers: const [
        'الحالة',
        'المتبقي (يوم)',
        'تاريخ الانتهاء',
        'تاريخ الإنتاج',
        'جهة الاستلام',
        'الكمية والوحدة',
        'اسم الصنف',
        'موقع الراك',
      ],
      rows: rows,
      fileName: 'active_condemnation_alerts.pdf',
      headerColor: PdfColors.red900,
    );
  }

  Future<void> _printHistoryPdf(
    CondemnationsState state,
    List<CondemnationHistoryRecordEntity> filteredRecords,
  ) async {
    final fromStr = state.fromDateFilter != null
        ? _fmtDate(state.fromDateFilter!)
        : 'البداية';
    final toStr =
        state.toDateFilter != null ? _fmtDate(state.toDateFilter!) : 'اليوم';

    final rows = filteredRecords.map((rec) {
      return <String>[
        _fmtDateTime(rec.createdAt),
        rec.approvedByName,
        rec.reason,
        _fmtDate(rec.expiryDate),
        _fmtDate(rec.productionDate),
        rec.sourceArLabel,
        '${rec.condemnedQuantity} ${rec.unitArLabel}',
        rec.itemName,
        rec.slotCode,
      ];
    }).toList();

    await ColdStoragePdfService.printCustomTableReport(
      reportTitle: 'سجل الإعدامات الفعلي المعتمد — ثلاجة مخفض (رمز C)',
      reportSubtitle:
          'الفترة من: $fromStr إلى: $toStr | إجمالي العمليات: ${rows.length}',
      headers: const [
        'تاريخ الإعدام',
        'المعتمد',
        'سبب الإعدام',
        'الانتهاء',
        'الإنتاج',
        'الجهة المصدر',
        'الكمية المعدمة',
        'اسم الصنف',
        'موقع الراك',
      ],
      rows: rows,
      fileName: 'condemnations_history_report.pdf',
      headerColor: PdfColors.red900,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CondemnationsCubit, CondemnationsState>(
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
                child: TabBar(
                  labelColor: AppColors.dangerRed,
                  indicatorColor: AppColors.dangerRed,
                  tabs: [
                    Tab(
                      icon: const Icon(LucideIcons.triangleAlert, size: 18),
                      text:
                          'الأصناف المستحقة للإعدام حالياً (${state.alertItems.length})',
                    ),
                    Tab(
                      icon: const Icon(LucideIcons.calendarSearch, size: 18),
                      text:
                          'سجل الإعدامات والبحث من فترة لفترة (${state.sourceFilteredHistory.length})',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    state.isLoading
                        ? const ResponsiveColdStorageShimmer(
                            mode: ShimmerLayoutMode.tableList,
                          )
                        : _buildActiveAlertsTab(context, state),
                    state.isLoading
                        ? const ResponsiveColdStorageShimmer(
                            mode: ShimmerLayoutMode.tableList,
                          )
                        : _buildHistorySearchTab(context, state),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveAlertsTab(BuildContext context, CondemnationsState state) {
    final List<Widget> alertCards = [];
    for (final item in state.alertItems) {
      alertCards.add(
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: AppColors.dangerRed.withValues(alpha: 0.45),
              width: 1.3,
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.dangerRed.withValues(alpha: 0.14),
              child: Text(
                '${item.daysUntilExpiry}d',
                style: const TextStyle(
                  color: AppColors.dangerRed,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
            title: Text(
              '${item.itemName} (${item.quantity} ${item.unitArLabel})',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الراك: [${item.slotCode}] | الجهة: ${item.sourceArLabel} | المستلم: ${item.receivedByName}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'الإنتاج: ${_fmtDate(item.productionDate)} | الانتهاء: ${_fmtDate(item.expiryDate)} (${item.isExpired ? "منتهي الصلاحية" : "مقترب من الانتهاء"})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: item.isExpired
                        ? AppColors.dangerRed
                        : AppColors.warningAmber,
                  ),
                ),
              ],
            ),
            trailing: AppActionButton(
              label: 'اعتماد الإعدام',
              icon: LucideIcons.flame,
              variant: AppButtonVariant.danger,
              onPressed: () => _showApproveCondemnationDialog(context, item),
            ),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: RefreshIndicator(
        onRefresh: () =>
            context.read<CondemnationsCubit>().loadCondemnationsData(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: AppColors.dangerRed.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 10,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.flame,
                          color: AppColors.dangerRed,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'حساب الإعدامات التلقائي بتوقيت مصر (حد الثلاجة: ${state.globalThresholdDays} يوم | تنبيهك الشخصي: ${state.userCustomAlertDays} يوم)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    AppActionButton(
                      label: 'طباعة المستحق للإعدام PDF',
                      icon: LucideIcons.printer,
                      variant: AppButtonVariant.danger,
                      onPressed: () => _printAlertsPdf(state),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (alertCards.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'ممتاز! لا توجد أي أصناف مستحقة للإعدام في الثلاجة حالياً.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              )
            else
              Column(children: alertCards),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySearchTab(BuildContext context, CondemnationsState state) {
    final cubit = context.read<CondemnationsCubit>();

    return RepaintBoundary(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                          'البحث في سجل الإعدامات من فترة لفترة (من تاريخ -> إلى تاريخ)',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                      ),
                      AppActionButton(
                        label: 'تحديث السجل',
                        icon: LucideIcons.refreshCw,
                        variant: AppButtonVariant.outline,
                        onPressed: () => cubit.loadCondemnationsData(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText:
                          'ابحث باسم الصنف، كود الراك، سبب الإعدام، أو اسم المعتمد...',
                      prefixIcon: Icon(LucideIcons.search),
                    ),
                    onChanged: (v) => _searchQueryNotifier.value = v,
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
                          state.fromDateFilter == null
                              ? 'من تاريخ: البداية'
                              : 'من تاريخ: ${_fmtDate(state.fromDateFilter!)}',
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: state.fromDateFilter ?? DateTime.now(),
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            await cubit.applyDateRangeFilter(
                              fromDate: picked,
                              toDate: state.toDateFilter,
                            );
                          }
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(LucideIcons.calendarCheck, size: 16),
                        label: Text(
                          state.toDateFilter == null
                              ? 'إلى تاريخ: اليوم'
                              : 'إلى تاريخ: ${_fmtDate(state.toDateFilter!)}',
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: state.toDateFilter ?? DateTime.now(),
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            await cubit.applyDateRangeFilter(
                              fromDate: state.fromDateFilter,
                              toDate: picked,
                            );
                          }
                        },
                      ),
                      ChoiceChip(
                        selected: state.sourceFilter == 'ALL',
                        label: const Text('كل الجهات'),
                        onSelected: (_) => cubit.selectSourceFilter('ALL'),
                      ),
                      ChoiceChip(
                        selected: state.sourceFilter == 'production',
                        label: const Text('الإنتاج فقط'),
                        onSelected: (_) =>
                            cubit.selectSourceFilter('production'),
                      ),
                      ChoiceChip(
                        selected: state.sourceFilter == 'quality_inspection',
                        label: const Text('نتيجة فحص الجودة فقط'),
                        onSelected: (_) =>
                            cubit.selectSourceFilter('quality_inspection'),
                      ),
                      if (state.fromDateFilter != null ||
                          state.toDateFilter != null ||
                          state.sourceFilter != 'ALL')
                        TextButton.icon(
                          icon: const Icon(LucideIcons.rotateCcw, size: 16),
                          label: const Text('إعادة ضبط الفترة'),
                          onPressed: () {
                            _searchQueryNotifier.value = '';
                            cubit.selectSourceFilter('ALL');
                            cubit.applyDateRangeFilter(
                              fromDate: null,
                              toDate: null,
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
          ValueListenableBuilder<String>(
            valueListenable: _searchQueryNotifier,
            builder: (context, query, _) {
              final baseList = state.sourceFilteredHistory;
              final filtered = baseList.where((rec) {
                if (query.trim().isEmpty) return true;
                final q = query.trim().toLowerCase();
                return rec.itemName.toLowerCase().contains(q) ||
                    rec.slotCode.toLowerCase().contains(q) ||
                    rec.reason.toLowerCase().contains(q) ||
                    rec.approvedByName.toLowerCase().contains(q);
              }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppActionButton(
                      label:
                          'طباعة سجل الفترة المحددة PDF (${filtered.length} سجل)',
                      icon: LucideIcons.fileText,
                      variant: AppButtonVariant.danger,
                      onPressed: () => _printHistoryPdf(state, filtered),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('لا توجد سجلات إعدام في الفترة المحددة.'),
                      ),
                    )
                  else
                    ..._buildHistoryCardsList(filtered),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHistoryCardsList(
    List<CondemnationHistoryRecordEntity> records,
  ) {
    final List<Widget> widgets = [];
    for (final rec in records) {
      widgets.add(
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.dangerRed.withValues(alpha: 0.12),
              child: const Icon(
                LucideIcons.trash2,
                color: AppColors.dangerRed,
                size: 18,
              ),
            ),
            title: Text(
              '${rec.itemName} — الكمية المعدمة: ${rec.condemnedQuantity} ${rec.unitArLabel}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الراك: [${rec.slotCode}] | الجهة: ${rec.sourceArLabel} | السبب: ${rec.reason}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'الإنتاج: ${_fmtDate(rec.productionDate)} | الانتهاء: ${_fmtDate(rec.expiryDate)} | اعتمد بواسطة: ${rec.approvedByName}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            trailing: Text(
              _fmtDateTime(rec.createdAt),
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
    return widgets;
  }

  void _showApproveCondemnationDialog(
    BuildContext context,
    CondemnationAlertItemEntity item,
  ) {
    final cubit = context.read<CondemnationsCubit>();
    final qtyCtrl = TextEditingController(text: item.quantity.toString());
    final reasonCtrl = TextEditingController(
      text: item.isExpired
          ? 'إعدام لانتهاء الصلاحية'
          : 'إعدام لاقتراب انتهاء الصلاحية (${item.daysUntilExpiry} يوم متبقي)',
    );

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            'اعتماد إعدام الصنف (${item.itemName})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الموقع: [${item.slotCode}] | المتاح حالياً: ${item.quantity} ${item.unitArLabel}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'الكمية المراد إعدامها',
                  prefixIcon: Icon(LucideIcons.hash),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'سبب الإعدام (يظهر في السجل والـ PDF)',
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
              label: 'تأكيد الإعدام النهائي',
              icon: LucideIcons.flame,
              variant: AppButtonVariant.danger,
              onPressed: () async {
                final val = double.tryParse(qtyCtrl.text.trim());
                if (val == null) return;
                Navigator.of(ctx).pop();
                await cubit.approveCondemnation(
                  palletItemId: item.palletItemId,
                  availableQuantity: item.quantity,
                  quantityToCondemn: val,
                  reason: reasonCtrl.text,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

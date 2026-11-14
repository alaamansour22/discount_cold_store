import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/responsive_shimmer.dart';
import '../../domain/entities/condemnations_entities.dart';
import '../cubit/condemnations_cubit.dart';
import '../cubit/condemnations_state.dart';

class CondemnationsPage extends StatefulWidget {
  const CondemnationsPage({super.key});

  @override
  State<CondemnationsPage> createState() => _CondemnationsPageState();
}

class _CondemnationsPageState extends State<CondemnationsPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) => intl.DateFormat('yyyy-MM-dd').format(d);
  String _fmtDateTime(DateTime d) =>
      intl.DateFormat('yyyy-MM-dd HH:mm').format(d);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CondemnationsCubit, CondemnationsState>(
      listener: (context, state) {
        if (!mounted) return;
        final message = state.failure?.message ?? state.successMessage;
        if (message == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: state.failure != null
                ? AppColors.dangerRed
                : AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      builder: (context, state) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 900;
              final wide = constraints.maxWidth >= 1200;
              return Column(
                children: [
                  _buildHeader(state, desktop),
                  Material(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: !desktop,
                      tabAlignment: desktop
                          ? TabAlignment.fill
                          : TabAlignment.start,
                      labelColor: AppColors.dangerRed,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.dangerRed,
                      indicatorWeight: 3,
                      tabs: [
                        Tab(
                          icon: const Icon(LucideIcons.triangleAlert, size: 18),
                          text: 'المستحق للإعدام (${state.alertItems.length})',
                        ),
                        Tab(
                          icon: const Icon(LucideIcons.history, size: 18),
                          text:
                              'سجل الإعدامات (${state.sourceFilteredHistory.length})',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildActiveTab(state, desktop, wide),
                        _buildHistoryTab(state, desktop, wide),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHeader(CondemnationsState state, bool desktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: desktop ? 28 : 16,
        vertical: 16,
      ),
      color: AppColors.scaffoldBackground,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1500),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.dangerRed.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  LucideIcons.flame,
                  color: AppColors.dangerRed,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إدارة الإعدامات',
                      style: TextStyle(
                        fontSize: desktop ? 21 : 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'متابعة الأصناف المستحقة ومراجعة سجل الإعدام المعتمد',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (desktop) _thresholdBadge(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thresholdBadge(CondemnationsState state) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.borderLight),
    ),
    child: Text(
      'حد الثلاجة ${state.globalThresholdDays} أيام  •  التنبيه الشخصي ${state.userCustomAlertDays} أيام',
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.primaryNavy,
      ),
    ),
  );

  Widget _buildActiveTab(CondemnationsState state, bool desktop, bool wide) {
    final cubit = context.read<CondemnationsCubit>();
    return RefreshIndicator(
      onRefresh: () => cubit.loadCondemnationsData(),
      child: LayoutBuilder(
        builder: (context, box) {
          final maxWidth = desktop ? 1450.0 : double.infinity;
          final columns = wide
              ? 3
              : desktop
              ? 2
              : 1;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(desktop ? 24 : 14),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildThresholdPanel(state, desktop),
                      const SizedBox(height: 16),
                      if (state.isLoading)
                        const ResponsiveColdStorageShimmer(
                          mode: ShimmerLayoutMode.dashboardCards,
                          itemCountOverride: 6,
                        )
                      else if (state.alertItems.isEmpty)
                        _emptyState(
                          'لا توجد أصناف مستحقة للإعدام حالياً',
                          'سيظهر هنا أي صنف يدخل ضمن فترة التنبيه أو تنتهي صلاحيته.',
                          LucideIcons.shieldCheck,
                        )
                      else
                        _responsiveCards(
                          state.alertItems.length,
                          columns,
                          (i) => _alertCard(state.alertItems[i]),
                          desktop,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildThresholdPanel(
    CondemnationsState state,
    bool desktop,
  ) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.dangerRed.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.dangerRed.withValues(alpha: .16)),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      spacing: 12,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.clockAlert, color: AppColors.dangerRed),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'مراقبة صلاحية المخزون',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'حد الثلاجة: ${state.globalThresholdDays} يوم  •  تنبيهك الشخصي: ${state.userCustomAlertDays} يوم',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _alertCard(CondemnationAlertItemEntity item) => Card(
    elevation: 1,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: AppColors.dangerRed.withValues(alpha: .18)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.dangerRed.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  LucideIcons.packageX,
                  color: AppColors.dangerRed,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.itemName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ),
              _statusPill(
                item.isExpired ? 'منتهي' : 'قارب الانتهاء',
                item.isExpired,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${item.quantity} ${item.unitArLabel}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: AppColors.dangerRed,
            ),
          ),
          const SizedBox(height: 10),
          _detailLine(LucideIcons.mapPin, 'الموقع', item.slotCode),
          _detailLine(LucideIcons.factory, 'الجهة', item.sourceArLabel),
          _detailLine(LucideIcons.user, 'المستلم', item.receivedByName),
          _detailLine(
            LucideIcons.calendar,
            'الإنتاج / الانتهاء',
            '${_fmtDate(item.productionDate)}  •  ${_fmtDate(item.expiryDate)}',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.dangerRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _showApproveCondemnationDialog(context, item),
              icon: const Icon(LucideIcons.flame, size: 18),
              label: const Text(
                'مراجعة واعتماد الإعدام',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildHistoryTab(CondemnationsState state, bool desktop, bool wide) {
    final cubit = context.read<CondemnationsCubit>();
    final q = _query.trim().toLowerCase();
    final records = state.sourceFilteredHistory
        .where(
          (r) =>
              q.isEmpty ||
              r.itemName.toLowerCase().contains(q) ||
              r.slotCode.toLowerCase().contains(q) ||
              r.reason.toLowerCase().contains(q) ||
              r.approvedByName.toLowerCase().contains(q),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: () => cubit.loadCondemnationsData(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(desktop ? 24 : 14),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: desktop ? 1450 : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _historyFilters(state, desktop),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'العمليات المسجلة',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: desktop ? 19 : 16,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                      ),
                      Text(
                        '${records.length} سجل',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (state.isLoading)
                    const ResponsiveColdStorageShimmer(
                      mode: ShimmerLayoutMode.tableList,
                      itemCountOverride: 7,
                    )
                  else if (records.isEmpty)
                    _emptyState(
                      'لا توجد نتائج مطابقة',
                      'غيّر الفترة أو كلمات البحث أو مصدر العملية.',
                      LucideIcons.searchX,
                    )
                  else
                    _responsiveCards(
                      records.length,
                      wide
                          ? 3
                          : desktop
                          ? 2
                          : 1,
                      (i) => _historyCard(records[i]),
                      desktop,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyFilters(CondemnationsState state, bool desktop) {
    final cubit = context.read<CondemnationsCubit>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'ابحث بالصنف أو الموقع أو السبب أو اسم المعتمد',
              prefixIcon: const Icon(LucideIcons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(LucideIcons.x),
                    ),
              filled: true,
              fillColor: AppColors.scaffoldBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterDateButton(
                'من: ${state.fromDateFilter == null ? 'البداية' : _fmtDate(state.fromDateFilter!)}',
                () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: state.fromDateFilter ?? DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2035),
                  );
                  if (d != null && mounted)
                    await cubit.applyDateRangeFilter(
                      fromDate: d,
                      toDate: state.toDateFilter,
                    );
                },
              ),
              _filterDateButton(
                'إلى: ${state.toDateFilter == null ? 'اليوم' : _fmtDate(state.toDateFilter!)}',
                () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: state.toDateFilter ?? DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2035),
                  );
                  if (d != null && mounted)
                    await cubit.applyDateRangeFilter(
                      fromDate: state.fromDateFilter,
                      toDate: d,
                    );
                },
              ),
              _sourceChip('كل الجهات', 'ALL', state.sourceFilter),
              _sourceChip('الإنتاج', 'production', state.sourceFilter),
              _sourceChip(
                'فحص الجودة',
                'quality_inspection',
                state.sourceFilter,
              ),
              if (state.fromDateFilter != null ||
                  state.toDateFilter != null ||
                  state.sourceFilter != 'ALL' ||
                  _query.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                    cubit.selectSourceFilter('ALL');
                    cubit.applyDateRangeFilter(fromDate: null, toDate: null);
                  },
                  icon: const Icon(LucideIcons.rotateCcw, size: 16),
                  label: const Text('مسح الفلاتر'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterDateButton(String label, VoidCallback onPressed) =>
      OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(LucideIcons.calendarDays, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      );

  Widget _sourceChip(String label, String value, String selected) => ChoiceChip(
    label: Text(label),
    selected: selected == value,
    onSelected: (_) =>
        context.read<CondemnationsCubit>().selectSourceFilter(value),
    selectedColor: AppColors.zoneC2Blue.withValues(alpha: .12),
    labelStyle: TextStyle(
      fontWeight: FontWeight.w700,
      color: selected == value ? AppColors.zoneC2Blue : AppColors.textSecondary,
    ),
  );

  Widget _historyCard(CondemnationHistoryRecordEntity rec) => Card(
    elevation: 1,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.dangerRed.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.trash2,
                  color: AppColors.dangerRed,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  rec.itemName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ),
              Text(
                '${rec.condemnedQuantity} ${rec.unitArLabel}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.dangerRed,
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          _detailLine(LucideIcons.mapPin, 'الموقع', rec.slotCode),
          _detailLine(LucideIcons.building2, 'الجهة', rec.sourceArLabel),
          _detailLine(LucideIcons.fileText, 'السبب', rec.reason),
          _detailLine(
            LucideIcons.userCheck,
            'اعتمد بواسطة',
            rec.approvedByName,
          ),
          _detailLine(
            LucideIcons.calendarClock,
            'التاريخ',
            _fmtDateTime(rec.createdAt),
          ),
        ],
      ),
    ),
  );

  Widget _detailLine(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 7),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.primaryNavy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _statusPill(String label, bool expired) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: (expired ? AppColors.dangerRed : AppColors.warningAmber)
          .withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        color: expired ? AppColors.dangerRed : AppColors.warningAmber,
      ),
    ),
  );

  Widget _responsiveCards(
    int count,
    int columns,
    Widget Function(int) builder,
    bool desktop,
  ) {
    if (columns == 1)
      return Column(
        children: List.generate(
          count,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: builder(i),
          ),
        ),
      );
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 14.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(
            count,
            (i) => SizedBox(width: width, child: builder(i)),
          ),
        );
      },
    );
  }

  Widget _emptyState(String title, String subtitle, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.borderLight),
    ),
    child: Column(
      children: [
        Icon(icon, size: 42, color: AppColors.successGreen),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: AppColors.primaryNavy,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    ),
  );

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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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

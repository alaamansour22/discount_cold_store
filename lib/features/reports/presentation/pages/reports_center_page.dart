import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdf/pdf.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/cold_storage_pdf_service.dart';
import '../../domain/entities/report_entities.dart';
import '../cubit/reports_cubit.dart';
import '../widgets/report_preview_dialog.dart';

const _kRepBg = Color(0xFFF3F6FB);
const _kRepBorder = Color(0xFFE3E8EF);
const _kRepMuted = Color(0xFF64748B);

String _fmtRepDate(DateTime value) =>
    intl.DateFormat('yyyy/MM/dd').format(value);

enum _ReportCategory {
  all('الكل', LucideIcons.layers),
  receiving('الاستلام', LucideIcons.packageCheck),
  dispatch('الصرف', LucideIcons.packageOpen),
  inventory('المخزون والجرد', LucideIcons.warehouse),
  condemnations('الإعدامات', LucideIcons.flame);

  final String label;
  final IconData icon;
  const _ReportCategory(this.label, this.icon);
}

enum _DatePreset {
  today('اليوم'),
  yesterday('أمس'),
  last7Days('آخر 7 أيام'),
  thisMonth('هذا الشهر'),
  lastMonth('الشهر الماضي'),
  custom('فترة مخصصة');

  final String label;
  const _DatePreset(this.label);
}

enum _ReportScopeType { dailyOnly, periodBased, instantSnapshot }

class _ReportCardSpec {
  final ReportKey reportKey;
  final _ReportCategory category;
  final _ReportScopeType scopeType;
  final String baseTitle;
  final String baseSubtitle;
  final String fileName;
  final IconData icon;
  final Color color;
  final PdfColor pdfHeaderColor;

  const _ReportCardSpec({
    required this.reportKey,
    required this.category,
    required this.scopeType,
    required this.baseTitle,
    required this.baseSubtitle,
    required this.fileName,
    required this.icon,
    required this.color,
    required this.pdfHeaderColor,
  });
}

/// مركز التقارير والطباعة الشامل (مرتبط بالكامل بدالة rpc_get_report_paginated)
class ReportsCenterPage extends StatefulWidget {
  const ReportsCenterPage({super.key});

  @override
  State<ReportsCenterPage> createState() => _ReportsCenterPageState();
}

class _ReportsCenterPageState extends State<ReportsCenterPage> {
  late final ReportsCubit _reportsCubit = sl.createReportsCubit();
  final TextEditingController _searchCtrl = TextEditingController();

  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  _DatePreset _selectedPreset = _DatePreset.today;
  _ReportCategory _selectedCategory = _ReportCategory.all;

  bool _busy = false;
  String? _activeKey;
  String? _activeActionType; // 'preview' | 'print'

  static const List<_ReportCardSpec> _reports = [
    _ReportCardSpec(
      reportKey: ReportKey.receivingDaily,
      category: _ReportCategory.receiving,
      scopeType: _ReportScopeType.dailyOnly,
      baseTitle: 'الاستلام اليومي',
      baseSubtitle: 'كافة البالتات والأصناف المستلمة خلال اليوم الحالي',
      fileName: 'daily_receiving_report.pdf',
      icon: LucideIcons.calendarCheck,
      color: AppColors.zoneC2Blue,
      pdfHeaderColor: PdfColors.blue900,
    ),
    _ReportCardSpec(
      reportKey: ReportKey.receivingRange,
      category: _ReportCategory.receiving,
      scopeType: _ReportScopeType.periodBased,
      baseTitle: 'الاستلام',
      baseSubtitle: 'تقرير تفصيلي بجميع الواردات خلال الفترة المحددة',
      fileName: 'range_receiving_report.pdf',
      icon: LucideIcons.packageCheck,
      color: AppColors.zoneC2Blue,
      pdfHeaderColor: PdfColors.blue900,
    ),
    _ReportCardSpec(
      reportKey: ReportKey.dispatchDaily,
      category: _ReportCategory.dispatch,
      scopeType: _ReportScopeType.dailyOnly,
      baseTitle: 'الصرف اليومي',
      baseSubtitle: 'كافة الأصناف المنصرفة إلى منفذ البيع خلال اليوم الحالي',
      fileName: 'daily_dispatch_report.pdf',
      icon: LucideIcons.calendarCheck,
      color: AppColors.successGreen,
      pdfHeaderColor: PdfColors.indigo900,
    ),
    _ReportCardSpec(
      reportKey: ReportKey.dispatchRange,
      category: _ReportCategory.dispatch,
      scopeType: _ReportScopeType.periodBased,
      baseTitle: 'الصرف التفصيلي',
      baseSubtitle: 'تفاصيل كل صنف وبالتة منصرفة خلال الفترة المحددة',
      fileName: 'range_dispatch_report.pdf',
      icon: LucideIcons.packageOpen,
      color: AppColors.successGreen,
      pdfHeaderColor: PdfColors.indigo900,
    ),
    _ReportCardSpec(
      reportKey: ReportKey.dispatchDocuments,
      category: _ReportCategory.dispatch,
      scopeType: _ReportScopeType.periodBased,
      baseTitle: 'ملخص مستندات الصرف',
      baseSubtitle: 'مستندات الصرف المكتملة والمعكوسة وأسباب العكس',
      fileName: 'dispatch_documents_summary.pdf',
      icon: LucideIcons.fileText,
      color: AppColors.secondaryBlue,
      pdfHeaderColor: PdfColors.indigo900,
    ),
    _ReportCardSpec(
      reportKey: ReportKey.currentStock,
      category: _ReportCategory.inventory,
      scopeType: _ReportScopeType.instantSnapshot,
      baseTitle: 'الرصيد الحالي للمخزون',
      baseSubtitle: 'جرد تفصيلي بالكميات وتواريخ الصلاحية ومواقع الراكات',
      fileName: 'current_inventory_balance.pdf',
      icon: LucideIcons.warehouse,
      color: AppColors.zoneC3Teal,
      pdfHeaderColor: PdfColors.blue900,
    ),
    _ReportCardSpec(
      reportKey: ReportKey.itemBalances,
      category: _ReportCategory.inventory,
      scopeType: _ReportScopeType.instantSnapshot,
      baseTitle: 'أرصدة الأصناف المجمعة',
      baseSubtitle: 'إجمالي رصيد كل صنف وعدد البالتات وأقرب تاريخ صلاحية',
      fileName: 'item_balances_report.pdf',
      icon: LucideIcons.chartBar,
      color: AppColors.zoneC3Teal,
      pdfHeaderColor: PdfColors.teal900,
    ),
    _ReportCardSpec(
      reportKey: ReportKey.condemnationAlerts,
      category: _ReportCategory.condemnations,
      scopeType: _ReportScopeType.instantSnapshot,
      baseTitle: 'الأصناف المستحقة للإعدام',
      baseSubtitle: 'الأصناف المنتهية أو التي دخلت نطاق التنبيه بالثلاجة',
      fileName: 'active_condemnation_alerts.pdf',
      icon: LucideIcons.clockAlert,
      color: AppColors.warningAmber,
      pdfHeaderColor: PdfColors.red900,
    ),
    _ReportCardSpec(
      reportKey: ReportKey.condemnationHistory,
      category: _ReportCategory.condemnations,
      scopeType: _ReportScopeType.periodBased,
      baseTitle: 'سجل الإعدامات المعتمد',
      baseSubtitle: 'العمليات المنفذة والمعتمدة خلال الفترة الزمنية المحددة',
      fileName: 'condemnations_history_report.pdf',
      icon: LucideIcons.flame,
      color: AppColors.dangerRed,
      pdfHeaderColor: PdfColors.red900,
    ),
  ];

  @override
  void dispose() {
    _reportsCubit.close();
    _searchCtrl.dispose();
    super.dispose();
  }

  DateTime get _todayDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  int get _selectedDaysCount {
    final start = DateTime(_from.year, _from.month, _from.day);
    final end = DateTime(_to.year, _to.month, _to.day);
    return end.difference(start).inDays + 1;
  }

  bool get _hasActiveFilters =>
      _selectedCategory != _ReportCategory.all ||
      _selectedPreset != _DatePreset.today ||
      _searchCtrl.text.trim().isNotEmpty;

  void _resetAllFilters() {
    final today = _todayDate;
    _searchCtrl.clear();
    setState(() {
      _selectedCategory = _ReportCategory.all;
      _selectedPreset = _DatePreset.today;
      _from = today;
      _to = today;
    });
  }

  void _applyDatePreset(_DatePreset preset) {
    final today = _todayDate;
    setState(() {
      _selectedPreset = preset;
      switch (preset) {
        case _DatePreset.today:
          _from = today;
          _to = today;
          break;
        case _DatePreset.yesterday:
          final yesterday = today.subtract(const Duration(days: 1));
          _from = yesterday;
          _to = yesterday;
          break;
        case _DatePreset.last7Days:
          _from = today.subtract(const Duration(days: 6));
          _to = today;
          break;
        case _DatePreset.thisMonth:
          _from = DateTime(today.year, today.month, 1);
          _to = today;
          break;
        case _DatePreset.lastMonth:
          final lastOfPrevMonth = DateTime(
            today.year,
            today.month,
            1,
          ).subtract(const Duration(days: 1));
          _from = DateTime(lastOfPrevMonth.year, lastOfPrevMonth.month, 1);
          _to = lastOfPrevMonth;
          break;
        case _DatePreset.custom:
          break;
      }
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('ar', 'EG'),
      helpText: isFrom ? 'اختر تاريخ البداية' : 'اختر تاريخ النهاية',
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _selectedPreset = _DatePreset.custom;
      if (isFrom) {
        _from = selected;
        if (_from.isAfter(_to)) {
          _to = selected;
        }
      } else {
        _to = selected;
        if (_to.isBefore(_from)) {
          _from = selected;
        }
      }
    });
  }

  ReportQueryParams _buildQueryParams(
    _ReportCardSpec spec, {
    int pageSize = 25,
  }) {
    final isPeriod = spec.scopeType == _ReportScopeType.periodBased;
    return ReportQueryParams(
      reportKey: spec.reportKey,
      fromDate: isPeriod ? _from : null,
      toDate: isPeriod ? _to : null,
      page: 1,
      pageSize: pageSize,
    );
  }

  String _resolveCardTitle(_ReportCardSpec spec) =>
      spec.scopeType == _ReportScopeType.periodBased
      ? '${spec.baseTitle} (${_selectedPreset.label})'
      : spec.baseTitle;

  String _resolveCardSubtitle(_ReportCardSpec spec) => switch (spec.scopeType) {
    _ReportScopeType.periodBased =>
      'النطاق: من ${_fmtRepDate(_from)} إلى ${_fmtRepDate(_to)} • ${spec.baseSubtitle}',
    _ReportScopeType.dailyOnly =>
      'تاريخ اليوم: ${_fmtRepDate(DateTime.now())} • ${spec.baseSubtitle}',
    _ReportScopeType.instantSnapshot =>
      'حتى لحظة: ${_fmtRepDate(DateTime.now())} • ${spec.baseSubtitle}',
  };

  String _resolveReportSubtitleForPrint(_ReportCardSpec spec) =>
      switch (spec.scopeType) {
        _ReportScopeType.periodBased =>
          'الفترة: من ${_fmtRepDate(_from)} إلى ${_fmtRepDate(_to)}',
        _ReportScopeType.dailyOnly => 'تاريخ اليوم: ${_fmtRepDate(DateTime.now())}',
        _ReportScopeType.instantSnapshot =>
          'جرد لحظي بتاريخ: ${_fmtRepDate(DateTime.now())}',
      };

  String _resolveCardBadge(_ReportCardSpec spec) => switch (spec.scopeType) {
    _ReportScopeType.periodBased =>
      _selectedDaysCount == 1 ? '1 يوم' : '$_selectedDaysCount أيام',
    _ReportScopeType.dailyOnly => 'اليوم فقط',
    _ReportScopeType.instantSnapshot => 'جرد لحظي',
  };

  int _categoryCount(_ReportCategory cat) => cat == _ReportCategory.all
      ? _reports.length
      : _reports.where((r) => r.category == cat).length;

  Future<void> _executeReport({
    required _ReportCardSpec spec,
    required bool previewOnly,
  }) async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
      _activeKey = spec.reportKey.dbValue;
      _activeActionType = previewOnly ? 'preview' : 'print';
    });

    try {
      final title = 'تقرير ${_resolveCardTitle(spec)} — ثلاجة المخفض';
      final subtitle = _resolveReportSubtitleForPrint(spec);

      if (previewOnly) {
        final params = _buildQueryParams(spec, pageSize: 25);
        final firstPage = await _reportsCubit.fetchReportPage(params);
        if (!mounted) {
          return;
        }
        await showDialog<void>(
          context: context,
          builder: (_) => ReportPreviewDialog(
            reportsCubit: _reportsCubit,
            initialParams: params,
            initialData: firstPage,
            title: title,
            subtitle: subtitle,
            fileName: spec.fileName,
            headerColor: spec.pdfHeaderColor,
            accentColor: spec.color,
          ),
        );
      } else {
        final params = _buildQueryParams(spec, pageSize: 5000);
        final fullData = await _reportsCubit.fetchReportForPrint(params);
        if (!mounted) {
          return;
        }
        await ColdStoragePdfService.printCustomTableReport(
          reportTitle: title,
          reportSubtitle:
              '$subtitle | عدد السجلات: ${fullData.page.totalCount}',
          headers: fullData.headers,
          rows: fullData.page.items,
          fileName: spec.fileName,
          headerColor: spec.pdfHeaderColor,
          summaryMetrics: fullData.summaryMetrics,
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('تعذر تجهيز التقرير: $e'),
            backgroundColor: AppColors.dangerRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _activeKey = null;
          _activeActionType = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ColoredBox(
        color: _kRepBg,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            final desktop = maxW >= 920;
            final tablet = maxW >= 620 && !desktop;
            final pad = desktop ? 24.0 : (tablet ? 16.0 : 12.0);

            return CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    pad,
                    desktop ? 18 : 10,
                    pad,
                    desktop ? 14 : 10,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (desktop) ...[
                          _buildDesktopHeader(),
                          const SizedBox(height: 14),
                        ],
                        _buildControlCard(desktop),
                      ],
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchCtrl,
                  builder: (context, searchValue, _) {
                    final query = searchValue.text.trim().toLowerCase();
                    final visibleReports = _reports.where((r) {
                      final matchesCat =
                          _selectedCategory == _ReportCategory.all ||
                          r.category == _selectedCategory;
                      final matchesSearch =
                          query.isEmpty ||
                          _resolveCardTitle(r).toLowerCase().contains(query) ||
                          _resolveCardSubtitle(r).toLowerCase().contains(query);
                      return matchesCat && matchesSearch;
                    }).toList();

                    return SliverMainAxisGroup(
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(pad, 0, pad, 10),
                          sliver: SliverToBoxAdapter(
                            child: _buildFilterSummary(
                              visibleCount: visibleReports.length,
                              hasSearch: query.isNotEmpty,
                            ),
                          ),
                        ),
                        if (visibleReports.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _buildEmptyState(),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(pad, 0, pad, 28),
                            sliver: SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: desktop
                                        ? 3
                                        : tablet
                                        ? 2
                                        : 1,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    mainAxisExtent: desktop ? 182 : 172,
                                  ),
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final spec = visibleReports[index];
                                final key = spec.reportKey.dbValue;
                                final isPreviewLoading =
                                    _busy &&
                                    _activeKey == key &&
                                    _activeActionType == 'preview';
                                final isPrintLoading =
                                    _busy &&
                                    _activeKey == key &&
                                    _activeActionType == 'print';

                                return _ReportCardTile(
                                  spec: spec,
                                  title: _resolveCardTitle(spec),
                                  subtitle: _resolveCardSubtitle(spec),
                                  badgeText: _resolveCardBadge(spec),
                                  busy: _busy,
                                  isPreviewLoading: isPreviewLoading,
                                  isPrintLoading: isPrintLoading,
                                  onPreview: () => _executeReport(
                                    spec: spec,
                                    previewOnly: true,
                                  ),
                                  onPrint: () => _executeReport(
                                    spec: spec,
                                    previewOnly: false,
                                  ),
                                );
                              }, childCount: visibleReports.length),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryNavy, Color(0xFF1E3A5F)],
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              LucideIcons.chartBar,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مركز التقارير والطباعة الشامل',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'معاينة فورية بترقيم صفحات من قاعدة البيانات وطباعة PDF رسمية لكافة الأقسام',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Text(
              '${_fmtRepDate(_from)} ← ${_fmtRepDate(_to)} ($_selectedDaysCount يوم)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlCard(bool desktop) {
    final searchField = ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchCtrl,
      builder: (_, val, _) => TextField(
        controller: _searchCtrl,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'ابحث باسم التقرير...',
          hintStyle: const TextStyle(fontSize: 12.5),
          prefixIcon: const Icon(LucideIcons.search, size: 17),
          suffixIcon: val.text.isEmpty
              ? null
              : IconButton(
                  onPressed: _searchCtrl.clear,
                  icon: const Icon(LucideIcons.x, size: 16),
                ),
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: _kRepBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: _kRepBorder),
          ),
        ),
      ),
    );

    Widget dateBtn(String label, DateTime value, VoidCallback onTap) =>
        OutlinedButton.icon(
          onPressed: _busy ? null : onTap,
          icon: const Icon(
            LucideIcons.calendarDays,
            size: 14,
            color: AppColors.zoneC2Blue,
          ),
          label: Text(
            '$label: ${_fmtRepDate(value)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryNavy,
            ),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFFF8FAFC),
            side: const BorderSide(color: _kRepBorder),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

    final presets = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _DatePreset.values.map((preset) {
        final selected = _selectedPreset == preset;
        return ChoiceChip(
          label: Text(preset.label),
          selected: selected,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          selectedColor: AppColors.zoneC2Blue,
          backgroundColor: const Color(0xFFF8FAFC),
          side: BorderSide(
            color: selected ? AppColors.zoneC2Blue : _kRepBorder,
          ),
          labelStyle: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppColors.primaryNavy,
          ),
          onSelected: _busy ? null : (_) => _applyDatePreset(preset),
        );
      }).toList(),
    );

    final categories = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _ReportCategory.values.map((cat) {
        final selected = _selectedCategory == cat;
        return ChoiceChip(
          avatar: Icon(
            cat.icon,
            size: 14,
            color: selected ? Colors.white : _kRepMuted,
          ),
          label: Text('${cat.label} (${_categoryCount(cat)})'),
          selected: selected,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          selectedColor: AppColors.primaryNavy,
          backgroundColor: const Color(0xFFF8FAFC),
          side: BorderSide(
            color: selected ? AppColors.primaryNavy : _kRepBorder,
          ),
          labelStyle: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppColors.primaryNavy,
          ),
          onSelected: (_) => setState(() => _selectedCategory = cat),
        );
      }).toList(),
    );

    return Container(
      padding: EdgeInsets.all(desktop ? 14 : 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kRepBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (desktop)
            Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 10),
                dateBtn('من', _from, () => _pickDate(isFrom: true)),
                const SizedBox(width: 8),
                dateBtn('إلى', _to, () => _pickDate(isFrom: false)),
              ],
            )
          else ...[
            searchField,
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: dateBtn('من', _from, () => _pickDate(isFrom: true)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: dateBtn('إلى', _to, () => _pickDate(isFrom: false)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          presets,
          const Divider(height: 18, color: Color(0xFFEDF1F5)),
          categories,
        ],
      ),
    );
  }

  Widget _buildFilterSummary({
    required int visibleCount,
    required bool hasSearch,
  }) {
    final showReset = _hasActiveFilters || hasSearch;
    return Row(
      children: [
        Text(
          'التقارير المتاحة ($visibleCount من ${_reports.length})',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryNavy,
          ),
        ),
        const Spacer(),
        if (showReset)
          TextButton.icon(
            onPressed: _resetAllFilters,
            icon: const Icon(LucideIcons.rotateCcw, size: 14),
            label: const Text(
              'إعادة ضبط',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF0F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.searchX,
              size: 26,
              color: _kRepMuted,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'لا توجد تقارير مطابقة للبحث',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _resetAllFilters,
            icon: const Icon(LucideIcons.rotateCcw, size: 15),
            label: const Text('عرض كل التقارير'),
          ),
        ],
      ),
    ),
  );
}

class _ReportCardTile extends StatelessWidget {
  final _ReportCardSpec spec;
  final String title;
  final String subtitle;
  final String badgeText;
  final bool busy;
  final bool isPreviewLoading;
  final bool isPrintLoading;
  final VoidCallback onPreview;
  final VoidCallback onPrint;

  const _ReportCardTile({
    required this.spec,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.busy,
    required this.isPreviewLoading,
    required this.isPrintLoading,
    required this.onPreview,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kRepBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: spec.color.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(spec.icon, color: spec.color, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: spec.color.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: spec.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: _kRepMuted,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onPreview,
                    icon: isPreviewLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.eye, size: 15),
                    label: const Text(
                      'معاينة',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryNavy,
                      side: const BorderSide(color: _kRepBorder),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onPrint,
                    icon: isPrintLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(LucideIcons.printer, size: 15),
                    label: const Text(
                      'طباعة PDF',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: spec.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
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
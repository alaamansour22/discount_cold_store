import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdf/pdf.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/cold_storage_pdf_service.dart';
import '../../../condemnations/data/models/condemnations_models.dart';
import '../../domain/entities/report_entities.dart';
import '../cubit/reports_cubit.dart';

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

class _PreparedReportPayload {
  final String title;
  final String subtitle;
  final List<String> headers;
  final List<List<String>> rows;
  final String fileName;
  final PdfColor headerColor;
  final Color accentColor;
  final Map<String, String> summaryMetrics;

  const _PreparedReportPayload({
    required this.title,
    required this.subtitle,
    required this.headers,
    required this.rows,
    required this.fileName,
    required this.headerColor,
    required this.accentColor,
    this.summaryMetrics = const {},
  });
}

class ReportsCenterPage extends StatefulWidget {
  const ReportsCenterPage({super.key});

  @override
  State<ReportsCenterPage> createState() => _ReportsCenterPageState();
}

class _ReportsCenterPageState extends State<ReportsCenterPage> {
  late final ReportsCubit _reportsCubit = sl.createReportsCubit();
  late final List<_ReportCardSpec> _reports = _buildReportSpecs();
  final TextEditingController _searchCtrl = TextEditingController();

  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  _DatePreset _selectedPreset = _DatePreset.today;
  _ReportCategory _selectedCategory = _ReportCategory.all;

  bool _busy = false;
  String? _activeKey;
  String? _activeActionType; // 'preview' | 'print'

  @override
  void dispose() {
    _reportsCubit.close();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _date(DateTime value) => intl.DateFormat('yyyy/MM/dd').format(value);

  String _fmtNum(num value) =>
      value.toStringAsFixed(value % 1 == 0 ? 0 : 2);

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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _searchCtrl.clear();
    setState(() {
      _selectedCategory = _ReportCategory.all;
      _selectedPreset = _DatePreset.today;
      _from = today;
      _to = today;
    });
  }

  void _applyDatePreset(_DatePreset preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
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
          final firstOfThisMonth = DateTime(today.year, today.month, 1);
          final lastOfPrevMonth = firstOfThisMonth.subtract(
            const Duration(days: 1),
          );
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
    if (selected == null) return;
    setState(() {
      _selectedPreset = _DatePreset.custom;
      if (isFrom) {
        _from = selected;
        if (_from.isAfter(_to)) _to = selected;
      } else {
        _to = selected;
        if (_to.isBefore(_from)) _from = selected;
      }
    });
  }

  // ==================== Report Builders ====================

  Future<_PreparedReportPayload> _buildMovementReport({
    required bool dispatch,
    required bool daily,
  }) async {
    final now = DateTime.now();
    final start = daily ? DateTime(now.year, now.month, now.day) : _from;
    final end = daily ? DateTime(now.year, now.month, now.day) : _to;
    final range = ReportDateRange(start: start, end: end);

    final records = dispatch
        ? await _reportsCubit.getDispatchItems(range)
        : await _reportsCubit.getReceipts(range);
    final dateColumn = dispatch ? 'dispatched_at' : 'received_at';

    double totalQty = 0;
    final distinctItems = <String>{};

    final rows = records.map((record) {
      final dateValue = record[dateColumn];
      final date = dateValue == null
          ? null
          : DateTime.parse(dateValue.toString()).toLocal();
      final quantity =
          (dispatch
                  ? record['quantity_dispatched']
                  : record['received_quantity'])
              as num? ??
          0;
      totalQty += quantity.toDouble();

      final itemName = (record['item_name'] ?? '—').toString();
      distinctItems.add(itemName);

      final unit = _unitLabel((record['unit'] ?? '').toString());
      final source = dispatch
          ? 'منفذ البيع'
          : _sourceLabel((record['source_entity'] ?? '').toString());
      final slot =
          (dispatch ? record['original_slot_code'] : record['slot_code']) ??
          '—';
      final palletRef = (record['pallet_reference'] ?? '—').toString();
      final user =
          (dispatch ? record['created_by_name'] : record['received_by_name']) ??
          'مستخدم النظام';
      final note = dispatch
          ? 'طريقة الصرف: ${_dispatchMethodLabel((record['dispatch_method'] ?? '').toString())}'
          : (record['notes'] ?? '—').toString();

      return <String>[
        note,
        source,
        slot.toString(),
        '${_fmtNum(quantity)} $unit',
        itemName,
        palletRef,
        user.toString(),
        date == null ? '—' : intl.DateFormat('yyyy/MM/dd  HH:mm').format(date),
      ];
    }).toList();

    return _PreparedReportPayload(
      title: dispatch
          ? (daily
                ? 'تقرير الصرف اليومي'
                : 'تقرير الصرف المخزني (${_selectedPreset.label})')
          : (daily
                ? 'تقرير الاستلام اليومي'
                : 'تقرير الاستلامات المخزنية (${_selectedPreset.label})'),
      subtitle:
          '${daily ? 'التقرير اليومي' : _selectedPreset.label} | من ${_date(start)} إلى ${_date(end)}',
      headers: const [
        'ملاحظات / طريقة الصرف',
        'جهة الحركة',
        'الموقع',
        'الكمية',
        'الصنف',
        'رقم البالتة',
        'المستخدم',
        'التاريخ والوقت',
      ],
      rows: rows,
      fileName:
          '${dispatch ? 'dispatch' : 'receiving'}_${daily ? 'daily' : 'period'}_report.pdf',
      headerColor: dispatch ? PdfColors.indigo900 : PdfColors.blue900,
      accentColor: dispatch ? AppColors.successGreen : AppColors.zoneC2Blue,
      summaryMetrics: {
        'عدد السجلات': '${rows.length}',
        'عدد الأصناف': '${distinctItems.length}',
        'إجمالي الوحدات': _fmtNum(totalQty),
      },
    );
  }

  Future<_PreparedReportPayload> _buildDispatchDocumentsReport() async {
    final range = ReportDateRange(start: _from, end: _to);
    final records = await _reportsCubit.getDispatchDocuments(range);

    int completedCount = 0;
    int reversedCount = 0;
    double totalDispatched = 0;

    final rows = records.map((record) {
      final status = (record['document_status'] ?? 'completed').toString();
      final isReversed = status == 'reversed';
      if (isReversed) {
        reversedCount++;
      } else {
        completedCount++;
        totalDispatched +=
            (record['total_dispatched_quantity'] as num?)?.toDouble() ?? 0;
      }

      final createdAt = record['created_at'] == null
          ? null
          : DateTime.parse(record['created_at'].toString()).toLocal();
      final qty = (record['total_dispatched_quantity'] as num?) ?? 0;

      return <String>[
        isReversed ? (record['reversal_reason'] ?? '—').toString() : '—',
        isReversed ? 'معكوس' : 'مكتمل',
        _fmtNum(qty),
        '${record['item_line_count'] ?? 0}',
        '${record['pallet_count'] ?? 0}',
        (record['created_by_name'] ?? 'مستخدم النظام').toString(),
        createdAt == null
            ? '—'
            : intl.DateFormat('yyyy/MM/dd  HH:mm').format(createdAt),
        (record['document_number'] ?? '—').toString(),
      ];
    }).toList();

    return _PreparedReportPayload(
      title: 'ملخص مستندات الصرف (${_selectedPreset.label})',
      subtitle: 'من ${_date(_from)} إلى ${_date(_to)}',
      headers: const [
        'سبب العكس',
        'حالة المستند',
        'إجمالي الكمية',
        'عدد البنود',
        'عدد البالتات',
        'منشئ المستند',
        'تاريخ الإنشاء',
        'رقم المستند',
      ],
      rows: rows,
      fileName: 'dispatch_documents_summary.pdf',
      headerColor: PdfColors.indigo900,
      accentColor: AppColors.secondaryBlue,
      summaryMetrics: {
        'إجمالي المستندات': '${rows.length}',
        'مكتملة': '$completedCount',
        'معكوسة': '$reversedCount',
        'صافي الكمية المنصرفة': _fmtNum(totalDispatched),
      },
    );
  }

  Future<_PreparedReportPayload> _buildCurrentStockReport() async {
    final records = await _reportsCubit.getCurrentInventory();
    final items = records
        .map(
          (row) => CondemnationModelMapper.alertFromViewJson(
            CondemnJsonMap.from(row),
          ),
        )
        .toList();

    int expiredCount = 0;
    int nearExpiryCount = 0;

    final rows = items.map((item) {
      if (item.isExpired) {
        expiredCount++;
      } else if (item.daysUntilExpiry <= item.globalThresholdDays) {
        nearExpiryCount++;
      }
      final status = item.isExpired
          ? 'منتهي الصلاحية'
          : 'متبقي ${item.daysUntilExpiry} يوم';
      return <String>[
        item.slotCode,
        item.palletReference,
        status,
        item.daysUntilExpiry <= 0 ? '0' : item.daysUntilExpiry.toString(),
        _date(item.expiryDate),
        _date(item.productionDate),
        '${_fmtNum(item.quantity)} ${item.unitArLabel}',
        item.itemName,
      ];
    }).toList();

    return _PreparedReportPayload(
      title: 'تقرير الرصيد الحالي للمخزون',
      subtitle: 'جرد لحظي حتى تاريخ ${_date(DateTime.now())}',
      headers: const [
        'الموقع',
        'رقم البالتة',
        'الحالة',
        'الأيام المتبقية',
        'تاريخ الانتهاء',
        'تاريخ الإنتاج',
        'الرصيد المتاح',
        'الصنف',
      ],
      rows: rows,
      fileName: 'current_inventory_balance.pdf',
      headerColor: PdfColors.blue900,
      accentColor: AppColors.successGreen,
      summaryMetrics: {
        'إجمالي السطور النشطة': '${rows.length}',
        'سليم': '${rows.length - expiredCount - nearExpiryCount}',
        'قريب الانتهاء': '$nearExpiryCount',
        'منتهي الصلاحية': '$expiredCount',
      },
    );
  }

  Future<_PreparedReportPayload> _buildItemBalancesReport() async {
    final records = await _reportsCubit.getItemBalances();
    int totalPallets = 0;

    final rows = records.map((record) {
      final quantity = (record['total_quantity'] as num?) ?? 0;
      final pallets = (record['pallet_count'] as num?)?.toInt() ?? 0;
      totalPallets += pallets;
      final nearestExpiry = record['nearest_expiry_date'];
      return <String>[
        nearestExpiry == null
            ? '—'
            : _date(DateTime.parse(nearestExpiry.toString())),
        '$pallets',
        '${record['active_item_lines'] ?? 0}',
        '${_fmtNum(quantity)} ${_unitLabel((record['unit'] ?? '').toString())}',
        (record['item_name'] ?? '—').toString(),
      ];
    }).toList();

    return _PreparedReportPayload(
      title: 'تقرير أرصدة الأصناف المجمعة',
      subtitle: 'إجمالي الرصيد المتاح حسب الصنف والوحدة حتى ${_date(DateTime.now())}',
      headers: const [
        'أقرب تاريخ انتهاء',
        'عدد البالتات',
        'عدد سجلات الأصناف',
        'إجمالي الرصيد',
        'الصنف',
      ],
      rows: rows,
      fileName: 'item_balances_report.pdf',
      headerColor: PdfColors.teal900,
      accentColor: AppColors.zoneC3Teal,
      summaryMetrics: {
        'عدد الأصناف': '${rows.length}',
        'مجموع البالتات': '$totalPallets',
      },
    );
  }

  Future<_PreparedReportPayload> _buildCondemnationReport({
    required bool history,
  }) async {
    if (history) {
      final records = await _reportsCubit.getCondemnationHistory(
        ReportDateRange(start: _from, end: _to),
      );
      double totalCondemned = 0;

      final rows = records.map((rec) {
        final date = DateTime.parse(rec['condemned_at'].toString()).toLocal();
        final quantity = (rec['condemned_quantity'] as num?) ?? 0;
        totalCondemned += quantity.toDouble();
        final unit = _unitLabel((rec['unit'] ?? '').toString());
        return <String>[
          intl.DateFormat('yyyy/MM/dd HH:mm').format(date),
          (rec['approved_by_name'] ?? '—').toString(),
          (rec['reason'] ?? '—').toString(),
          _date(DateTime.parse(rec['expiry_date'].toString())),
          _date(DateTime.parse(rec['production_date'].toString())),
          _sourceLabel((rec['source_entity'] ?? '').toString()),
          '${_fmtNum(quantity)} $unit',
          (rec['item_name'] ?? '—').toString(),
          (rec['slot_code'] ?? '—').toString(),
        ];
      }).toList();

      return _PreparedReportPayload(
        title: 'سجل الإعدامات المعتمد (${_selectedPreset.label})',
        subtitle: 'من ${_date(_from)} إلى ${_date(_to)}',
        headers: const [
          'تاريخ الإعدام',
          'المعتمد',
          'سبب الإعدام',
          'تاريخ الانتهاء',
          'تاريخ الإنتاج',
          'جهة الاستلام',
          'الكمية المعدمة',
          'الصنف',
          'الموقع',
        ],
        rows: rows,
        fileName: 'condemnations_history_report.pdf',
        headerColor: PdfColors.red900,
        accentColor: AppColors.dangerRed,
        summaryMetrics: {
          'عدد عمليات الإعدام': '${rows.length}',
          'إجمالي الكميات المعدمة': _fmtNum(totalCondemned),
        },
      );
    } else {
      final threshold = await _reportsCubit.getCondemnationThreshold();
      final records = await _reportsCubit.getCondemnationAlerts(threshold);
      final items = records
          .map(
            (row) => CondemnationModelMapper.alertFromViewJson(
              CondemnJsonMap.from(row),
            ),
          )
          .toList();

      int expiredCount = 0;
      for (final item in items) {
        if (item.isExpired) expiredCount++;
      }

      final rows = items
          .map(
            (item) => <String>[
              item.isExpired ? 'منتهي الصلاحية' : 'مستحق للمراجعة',
              item.daysUntilExpiry.toString(),
              _date(item.expiryDate),
              _date(item.productionDate),
              item.sourceArLabel,
              '${_fmtNum(item.quantity)} ${item.unitArLabel}',
              item.itemName,
              item.slotCode,
            ],
          )
          .toList();

      return _PreparedReportPayload(
        title: 'تقرير الأصناف المستحقة للإعدام',
        subtitle: 'حد التنبيه المعتمد: $threshold أيام | تاريخ ${_date(DateTime.now())}',
        headers: const [
          'الحالة',
          'المتبقي (يوم)',
          'تاريخ الانتهاء',
          'تاريخ الإنتاج',
          'جهة الاستلام',
          'الكمية',
          'الصنف',
          'الموقع',
        ],
        rows: rows,
        fileName: 'active_condemnation_alerts.pdf',
        headerColor: PdfColors.red900,
        accentColor: AppColors.warningAmber,
        summaryMetrics: {
          'إجمالي التنبيهات': '${rows.length}',
          'منتهي الصلاحية': '$expiredCount',
          'مستحق للمراجعة': '${rows.length - expiredCount}',
        },
      );
    }
  }

  Future<void> _executeReport({
    required String key,
    required bool previewOnly,
    required Future<_PreparedReportPayload> Function() builder,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _activeKey = key;
      _activeActionType = previewOnly ? 'preview' : 'print';
    });

    try {
      final payload = await builder();
      if (!mounted) return;

      if (previewOnly) {
        await _showPreviewDialog(payload);
      } else {
        await _printPayload(payload);
      }
    } catch (e) {
      _showReportError(e);
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

  Future<void> _printPayload(_PreparedReportPayload payload) {
    return ColdStoragePdfService.printCustomTableReport(
      reportTitle: payload.title,
      reportSubtitle: '${payload.subtitle} | عدد السجلات: ${payload.rows.length}',
      headers: payload.headers,
      rows: payload.rows,
      fileName: payload.fileName,
      headerColor: payload.headerColor,
      summaryMetrics: payload.summaryMetrics,
    );
  }

  Future<void> _showPreviewDialog(_PreparedReportPayload payload) async {
    final dialogSearchCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final isNarrow = MediaQuery.sizeOf(ctx).width < 640;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            insetPadding: EdgeInsets.all(isNarrow ? 12 : 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1140,
                maxHeight: 760,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      isNarrow ? 14 : 20,
                      16,
                      isNarrow ? 14 : 20,
                      14,
                    ),
                    decoration: BoxDecoration(
                      color: payload.accentColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.fileText,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                payload.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isNarrow ? 15 : 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                payload.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(
                            LucideIcons.x,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isNarrow ? 14 : 20,
                      12,
                      isNarrow ? 14 : 20,
                      10,
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: payload.summaryMetrics.entries
                              .map(
                                (e) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: payload.accentColor.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: payload.accentColor.withValues(
                                        alpha: 0.25,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    '${e.key}: ${e.value}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5,
                                      color: payload.accentColor,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        SizedBox(
                          width: isNarrow ? double.infinity : 260,
                          child: TextField(
                            controller: dialogSearchCtrl,
                            decoration: const InputDecoration(
                              hintText: 'تصفية سريعة داخل المعاينة...',
                              prefixIcon: Icon(LucideIcons.search, size: 17),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: dialogSearchCtrl,
                      builder: (context, searchVal, _) {
                        final q = searchVal.text.trim().toLowerCase();
                        final filteredRows = q.isEmpty
                            ? payload.rows
                            : payload.rows
                                  .where(
                                    (row) => row.any(
                                      (cell) => cell.toLowerCase().contains(q),
                                    ),
                                  )
                                  .toList();

                        if (filteredRows.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.circleAlert,
                                  size: 40,
                                  color: AppColors.textSecondary,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'لا توجد بيانات مطابقة في هذا التقرير.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isNarrow ? 14 : 20,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SingleChildScrollView(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStatePropertyAll(
                                    AppColors.primaryNavy,
                                  ),
                                  headingTextStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                  dataTextStyle: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 12,
                                  ),
                                  columns: payload.headers.reversed
                                      .map((h) => DataColumn(label: Text(h)))
                                      .toList(),
                                  rows: filteredRows
                                      .take(150)
                                      .map(
                                        (r) => DataRow(
                                          cells: r.reversed
                                              .map(
                                                (cell) => DataCell(Text(cell)),
                                              )
                                              .toList(),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      isNarrow ? 14 : 20,
                      12,
                      isNarrow ? 14 : 20,
                      14,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.borderLight),
                      ),
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          payload.rows.length > 150
                              ? 'يُعرض أول 150 سطر من أصل ${payload.rows.length} (الطباعة تشمل الكل)'
                              : 'إجمالي السجلات: ${payload.rows.length}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('إغلاق'),
                            ),
                            const SizedBox(width: 10),
                            FilledButton.icon(
                              onPressed: () async {
                                Navigator.of(ctx).pop();
                                await _printPayload(payload);
                              },
                              icon: const Icon(LucideIcons.printer, size: 17),
                              label: const Text('طباعة PDF الآن'),
                              style: FilledButton.styleFrom(
                                backgroundColor: payload.accentColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    dialogSearchCtrl.dispose();
  }

  void _showReportError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تعذر تجهيز التقرير: $error'),
        backgroundColor: AppColors.dangerRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _unitLabel(String value) => switch (value) {
    'carton' => 'كرتونة',
    'shrink' => 'شرنك',
    'gallon' => 'جالون',
    _ => value,
  };

  String _sourceLabel(String value) => switch (value) {
    'production' => 'الإنتاج',
    'quality_inspection' => 'فحص الجودة',
    _ => value,
  };

  String _dispatchMethodLabel(String value) => switch (value) {
    'full_pallet' => 'بالتة كاملة',
    'custom_quantity' => 'صرف جزئي',
    _ => value.isEmpty ? '—' : value,
  };

  List<_ReportCardSpec> _buildReportSpecs() => [
    _ReportCardSpec(
      keyName: 'receiving_daily',
      category: _ReportCategory.receiving,
      scopeType: _ReportScopeType.dailyOnly,
      baseTitle: 'الاستلام اليومي',
      baseSubtitle: 'كافة البالتات والأصناف المستلمة خلال اليوم الحالي',
      icon: LucideIcons.calendarCheck,
      color: AppColors.zoneC2Blue,
      builder: () => _buildMovementReport(dispatch: false, daily: true),
    ),
    _ReportCardSpec(
      keyName: 'receiving_range',
      category: _ReportCategory.receiving,
      scopeType: _ReportScopeType.periodBased,
      baseTitle: 'الاستلام',
      baseSubtitle: 'تقرير تفصيلي بجميع الواردات خلال الفترة المحددة',
      icon: LucideIcons.packageCheck,
      color: AppColors.zoneC2Blue,
      builder: () => _buildMovementReport(dispatch: false, daily: false),
    ),
    _ReportCardSpec(
      keyName: 'dispatch_daily',
      category: _ReportCategory.dispatch,
      scopeType: _ReportScopeType.dailyOnly,
      baseTitle: 'الصرف اليومي',
      baseSubtitle: 'كافة الأصناف المنصرفة إلى منفذ البيع خلال اليوم الحالي',
      icon: LucideIcons.calendarCheck,
      color: AppColors.successGreen,
      builder: () => _buildMovementReport(dispatch: true, daily: true),
    ),
    _ReportCardSpec(
      keyName: 'dispatch_range',
      category: _ReportCategory.dispatch,
      scopeType: _ReportScopeType.periodBased,
      baseTitle: 'الصرف التفصيلي',
      baseSubtitle: 'تفاصيل كل صنف وبالتة منصرفة خلال الفترة المحددة',
      icon: LucideIcons.packageOpen,
      color: AppColors.successGreen,
      builder: () => _buildMovementReport(dispatch: true, daily: false),
    ),
    _ReportCardSpec(
      keyName: 'dispatch_documents',
      category: _ReportCategory.dispatch,
      scopeType: _ReportScopeType.periodBased,
      baseTitle: 'ملخص مستندات الصرف',
      baseSubtitle: 'مستندات الصرف المكتملة والمعكوسة وأسباب العكس',
      icon: LucideIcons.fileText,
      color: AppColors.secondaryBlue,
      builder: _buildDispatchDocumentsReport,
    ),
    _ReportCardSpec(
      keyName: 'current_stock',
      category: _ReportCategory.inventory,
      scopeType: _ReportScopeType.instantSnapshot,
      baseTitle: 'الرصيد الحالي للمخزون',
      baseSubtitle: 'جرد تفصيلي بالكميات وتواريخ الصلاحية ومواقع الراكات',
      icon: LucideIcons.warehouse,
      color: AppColors.zoneC3Teal,
      builder: _buildCurrentStockReport,
    ),
    _ReportCardSpec(
      keyName: 'item_balances',
      category: _ReportCategory.inventory,
      scopeType: _ReportScopeType.instantSnapshot,
      baseTitle: 'أرصدة الأصناف المجمعة',
      baseSubtitle: 'إجمالي رصيد كل صنف وعدد البالتات وأقرب تاريخ صلاحية',
      icon: LucideIcons.chartBar,
      color: AppColors.zoneC3Teal,
      builder: _buildItemBalancesReport,
    ),
    _ReportCardSpec(
      keyName: 'condemnation_alerts',
      category: _ReportCategory.condemnations,
      scopeType: _ReportScopeType.instantSnapshot,
      baseTitle: 'الأصناف المستحقة للإعدام',
      baseSubtitle: 'الأصناف المنتهية أو التي دخلت نطاق التنبيه بالثلاجة',
      icon: LucideIcons.clockAlert,
      color: AppColors.warningAmber,
      builder: () => _buildCondemnationReport(history: false),
    ),
    _ReportCardSpec(
      keyName: 'condemnation_history',
      category: _ReportCategory.condemnations,
      scopeType: _ReportScopeType.periodBased,
      baseTitle: 'سجل الإعدامات المعتمد',
      baseSubtitle: 'العمليات المنفذة والمعتمدة خلال الفترة الزمنية المحددة',
      icon: LucideIcons.flame,
      color: AppColors.dangerRed,
      builder: () => _buildCondemnationReport(history: true),
    ),
  ];

  /// Dynamic title reflecting active date filter
  String _resolveCardTitle(_ReportCardSpec spec) {
    if (spec.scopeType == _ReportScopeType.periodBased) {
      return '${spec.baseTitle} (${_selectedPreset.label})';
    }
    return spec.baseTitle;
  }

  /// Dynamic subtitle reflecting active date filter
  String _resolveCardSubtitle(_ReportCardSpec spec) {
    return switch (spec.scopeType) {
      _ReportScopeType.periodBased =>
        'النطاق: من ${_date(_from)} إلى ${_date(_to)} • ${spec.baseSubtitle}',
      _ReportScopeType.dailyOnly =>
        'تاريخ اليوم: ${_date(DateTime.now())} • ${spec.baseSubtitle}',
      _ReportScopeType.instantSnapshot =>
        'حتى لحظة: ${_date(DateTime.now())} • ${spec.baseSubtitle}',
    };
  }

  /// Dynamic badge reflecting active date filter
  String _resolveCardBadge(_ReportCardSpec spec) {
    return switch (spec.scopeType) {
      _ReportScopeType.periodBased =>
        _selectedDaysCount == 1 ? '1 يوم' : '$_selectedDaysCount أيام',
      _ReportScopeType.dailyOnly => 'اليوم فقط',
      _ReportScopeType.instantSnapshot => 'جرد لحظي',
    };
  }

  int _categoryCount(_ReportCategory cat) {
    if (cat == _ReportCategory.all) return _reports.length;
    return _reports.where((r) => r.category == cat).length;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 1040;
    final tablet = width >= 680 && !desktop;
    final horizontal = desktop
        ? 32.0
        : tablet
        ? 20.0
        : 14.0;
    final contentWidth = (width - (horizontal * 2)).clamp(280.0, 1380.0);
    final sidePadding = ((width - contentWidth) / 2).clamp(
      horizontal,
      double.infinity,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: AppColors.scaffoldBackground,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                sidePadding,
                desktop ? 24 : 14,
                sidePadding,
                desktop ? 18 : 12,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RepaintBoundary(child: _buildHeroHeader(desktop)),
                    SizedBox(height: desktop ? 18 : 12),
                    RepaintBoundary(child: _buildUnifiedControlBar(desktop)),
                  ],
                ),
              ),
            ),

            // Search & Filter Reactive Cards Grid
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchCtrl,
              builder: (context, searchValue, _) {
                final query = searchValue.text.trim().toLowerCase();
                final visibleReports = _reports.where((r) {
                  final matchesCat =
                      _selectedCategory == _ReportCategory.all ||
                      r.category == _selectedCategory;
                  final resolvedTitle = _resolveCardTitle(r).toLowerCase();
                  final resolvedSub = _resolveCardSubtitle(r).toLowerCase();
                  final matchesSearch =
                      query.isEmpty ||
                      resolvedTitle.contains(query) ||
                      resolvedSub.contains(query);
                  return matchesCat && matchesSearch;
                }).toList();

                return SliverMainAxisGroup(
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        sidePadding,
                        0,
                        sidePadding,
                        10,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _buildActiveFilterSummary(
                          visibleCount: visibleReports.length,
                          hasSearch: query.isNotEmpty,
                        ),
                      ),
                    ),
                    if (visibleReports.isEmpty)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          sidePadding,
                          0,
                          sidePadding,
                          32,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: _buildEmptySearchState(),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          sidePadding,
                          0,
                          sidePadding,
                          32,
                        ),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: desktop
                                    ? 3
                                    : tablet
                                    ? 2
                                    : 1,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                mainAxisExtent: desktop ? 186 : 174,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final spec = visibleReports[index];
                            return _ReportCardTile(
                              spec: spec,
                              title: _resolveCardTitle(spec),
                              subtitle: _resolveCardSubtitle(spec),
                              badgeText: _resolveCardBadge(spec),
                              busy: _busy,
                              activeKey: _activeKey,
                              activeActionType: _activeActionType,
                              onPreview: () => _executeReport(
                                key: spec.keyName,
                                previewOnly: true,
                                builder: spec.builder,
                              ),
                              onPrint: () => _executeReport(
                                key: spec.keyName,
                                previewOnly: false,
                                builder: spec.builder,
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
        ),
      ),
    );
  }

  Widget _buildActiveFilterSummary({
    required int visibleCount,
    required bool hasSearch,
  }) {
    final showReset = _hasActiveFilters || hasSearch;
    return Row(
      children: [
        Expanded(
          child: Text(
            'التقارير المتاحة ($visibleCount) • التصنيف: ${_selectedCategory.label} • الفترة: ${_selectedPreset.label}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        if (showReset)
          TextButton.icon(
            onPressed: _resetAllFilters,
            icon: const Icon(LucideIcons.rotateCcw, size: 14),
            label: const Text(
              'إعادة ضبط',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.zoneC2Blue,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
      ],
    );
  }

  Widget _buildHeroHeader(bool desktop) {
    final titleBlock = Row(
      children: [
        Container(
          width: desktop ? 54 : 44,
          height: desktop ? 54 : 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Icon(
            LucideIcons.chartNoAxesCombined,
            color: Colors.white,
            size: desktop ? 26 : 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مركز التقارير والطباعة',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: desktop ? 23 : 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'معاينة فورية وتصدير PDF عربي منسّق بترويسة وتذييل ثابتين',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: desktop ? 13 : 11.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final activeRangePill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: desktop ? 14 : 11,
        vertical: desktop ? 10 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: desktop ? MainAxisSize.min : MainAxisSize.max,
        children: [
          const Icon(
            LucideIcons.calendarRange,
            color: Colors.white,
            size: 15,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'النطاق النشط: ${_date(_from)} — ${_date(_to)} ($_selectedDaysCount يوم)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: desktop ? 12.5 : 11.5,
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: EdgeInsets.all(desktop ? 22 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.primaryNavy, AppColors.zoneC2Blue],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryNavy.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: desktop
          ? Row(
              children: [
                Expanded(child: titleBlock),
                const SizedBox(width: 16),
                activeRangePill,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleBlock,
                const SizedBox(height: 12),
                activeRangePill,
              ],
            ),
    );
  }

  Widget _buildUnifiedControlBar(bool desktop) {
    final presets = _DatePreset.values
        .where((p) => p != _DatePreset.custom)
        .toList();

    Widget buildPresetChips() {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: presets.map((preset) {
            final selected = _selectedPreset == preset;
            return Padding(
              padding: const EdgeInsets.only(left: 7),
              child: ChoiceChip(
                selected: selected,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                selectedColor: AppColors.primaryNavy,
                backgroundColor: AppColors.scaffoldBackground,
                side: BorderSide(
                  color: selected
                      ? AppColors.primaryNavy
                      : AppColors.borderLight,
                ),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                label: Text(preset.label),
                onSelected: _busy ? null : (_) => _applyDatePreset(preset),
              ),
            );
          }).toList(),
        ),
      );
    }

    Widget buildCategoryChips() {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _ReportCategory.values.map((cat) {
            final isSelected = _selectedCategory == cat;
            final count = _categoryCount(cat);
            return Padding(
              padding: const EdgeInsets.only(left: 7),
              child: FilterChip(
                selected: isSelected,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  cat.icon,
                  size: 15,
                  color: isSelected ? Colors.white : AppColors.primaryNavy,
                ),
                selectedColor: AppColors.zoneC2Blue,
                backgroundColor: AppColors.scaffoldBackground,
                side: BorderSide(
                  color: isSelected
                      ? AppColors.zoneC2Blue
                      : AppColors.borderLight,
                ),
                label: Text(
                  '${cat.label} ($count)',
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.primaryNavy,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                onSelected: (_) => setState(() => _selectedCategory = cat),
              ),
            );
          }).toList(),
        ),
      );
    }

    Widget buildSearchField() {
      return ValueListenableBuilder<TextEditingValue>(
        valueListenable: _searchCtrl,
        builder: (context, value, _) {
          return TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'ابحث باسم التقرير...',
              hintStyle: const TextStyle(fontSize: 12.5),
              prefixIcon: const Icon(LucideIcons.search, size: 17),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              filled: true,
              fillColor: AppColors.scaffoldBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              suffixIcon: value.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, size: 15),
                      onPressed: _searchCtrl.clear,
                    )
                  : null,
            ),
          );
        },
      );
    }

    return Container(
      padding: EdgeInsets.all(desktop ? 18 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: desktop
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.zoneC2Blue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.calendarDays,
                        color: AppColors.zoneC2Blue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'فترة التقارير:',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryNavy,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: buildPresetChips()),
                    const SizedBox(width: 12),
                    _dateButton('من', _from, () => _pickDate(isFrom: true)),
                    const SizedBox(width: 8),
                    _dateButton('إلى', _to, () => _pickDate(isFrom: false)),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: AppColors.borderLight),
                ),
                Row(
                  children: [
                    Expanded(child: buildCategoryChips()),
                    const SizedBox(width: 16),
                    SizedBox(width: 300, child: buildSearchField()),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.calendarDays,
                      color: AppColors.zoneC2Blue,
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'النطاق الزمني',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryNavy,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _selectedPreset.label,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.zoneC2Blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                buildPresetChips(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _dateButton(
                        'من',
                        _from,
                        () => _pickDate(isFrom: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _dateButton(
                        'إلى',
                        _to,
                        () => _pickDate(isFrom: false),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: AppColors.borderLight),
                ),
                buildCategoryChips(),
                const SizedBox(height: 10),
                buildSearchField(),
              ],
            ),
    );
  }

  Widget _dateButton(String label, DateTime value, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: _busy ? null : onTap,
        icon: const Icon(LucideIcons.calendarRange, size: 15),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$label: ${_date(value)}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryNavy,
          backgroundColor: AppColors.scaffoldBackground,
          side: const BorderSide(color: AppColors.borderLight),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

  Widget _buildEmptySearchState() => Container(
    padding: const EdgeInsets.all(36),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.borderLight),
    ),
    child: Column(
      children: [
        const Icon(
          LucideIcons.search,
          size: 38,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 10),
        const Text(
          'لا يوجد تقرير مطابق لعبارة البحث أو التصنيف المختار',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.primaryNavy,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _resetAllFilters,
          child: const Text('عرض جميع التقارير'),
        ),
      ],
    ),
  );
}

enum _ReportScopeType { dailyOnly, periodBased, instantSnapshot }

class _ReportCardTile extends StatefulWidget {
  final _ReportCardSpec spec;
  final String title;
  final String subtitle;
  final String badgeText;
  final bool busy;
  final String? activeKey;
  final String? activeActionType;
  final VoidCallback onPreview;
  final VoidCallback onPrint;

  const _ReportCardTile({
    required this.spec,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.busy,
    required this.activeKey,
    required this.activeActionType,
    required this.onPreview,
    required this.onPrint,
  });

  @override
  State<_ReportCardTile> createState() => _ReportCardTileState();
}

class _ReportCardTileState extends State<_ReportCardTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final isThisBusy = widget.busy && widget.activeKey == spec.keyName;
    final isPreviewBusy = isThisBusy && widget.activeActionType == 'preview';
    final isPrintBusy = isThisBusy && widget.activeActionType == 'print';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered
                ? spec.color.withValues(alpha: 0.55)
                : AppColors.borderLight,
            width: _hovered ? 1.4 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x07000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: spec.color.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(spec.icon, color: spec.color, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: spec.color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.badgeText,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: spec.color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Expanded(
                child: Text(
                  widget.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.busy ? null : widget.onPreview,
                      icon: isPreviewBusy
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: spec.color,
                              ),
                            )
                          : Icon(LucideIcons.eye, size: 15, color: spec.color),
                      label: Text(
                        isPreviewBusy ? 'تحميل...' : 'معاينة',
                        style: TextStyle(
                          color: spec.color,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: spec.color.withValues(alpha: 0.45),
                        ),
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
                      onPressed: widget.busy ? null : widget.onPrint,
                      icon: isPrintBusy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(LucideIcons.printer, size: 15),
                      label: Text(
                        isPrintBusy ? 'تجهيز...' : 'طباعة PDF',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
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
      ),
    );
  }
}

class _ReportCardSpec {
  final String keyName;
  final _ReportCategory category;
  final _ReportScopeType scopeType;
  final String baseTitle;
  final String baseSubtitle;
  final IconData icon;
  final Color color;
  final Future<_PreparedReportPayload> Function() builder;

  const _ReportCardSpec({
    required this.keyName,
    required this.category,
    required this.scopeType,
    required this.baseTitle,
    required this.baseSubtitle,
    required this.icon,
    required this.color,
    required this.builder,
  });
}
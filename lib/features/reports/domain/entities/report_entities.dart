import 'package:equatable/equatable.dart';

import '../../../../core/pagination/paged_result.dart';

typedef ReportJsonMap = Map<String, dynamic>;
typedef ReportCellsRow = List<String>;
typedef ReportSummaryMetrics = Map<String, String>;

/// مفاتيح التقارير الـ 9 المدعومة في دالة PostgreSQL: rpc_get_report_paginated
enum ReportKey {
  receivingDaily('receiving_daily'),
  receivingRange('receiving_range'),
  dispatchDaily('dispatch_daily'),
  dispatchRange('dispatch_range'),
  dispatchDocuments('dispatch_documents'),
  currentStock('current_stock'),
  itemBalances('item_balances'),
  condemnationAlerts('condemnation_alerts'),
  condemnationHistory('condemnation_history');

  final String dbValue;
  const ReportKey(this.dbValue);
}

class ReportQueryParams extends Equatable {
  final ReportKey reportKey;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String search;
  final int page;
  final int pageSize;

  const ReportQueryParams({
    required this.reportKey,
    this.fromDate,
    this.toDate,
    this.search = '',
    this.page = 1,
    this.pageSize = 25,
  });

  ReportQueryParams copyWith({
    ReportKey? reportKey,
    DateTime? fromDate,
    bool clearFromDate = false,
    DateTime? toDate,
    bool clearToDate = false,
    String? search,
    int? page,
    int? pageSize,
  }) {
    return ReportQueryParams(
      reportKey: reportKey ?? this.reportKey,
      fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
      search: search ?? this.search,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  @override
  List<Object?> get props => [
    reportKey,
    fromDate,
    toDate,
    search,
    page,
    pageSize,
  ];
}

class ReportPageEntity extends Equatable {
  final String reportKey;
  final List<String> headers;
  final PagedResult<ReportCellsRow> page;
  final ReportSummaryMetrics summaryMetrics;
  final int thresholdDays;

  const ReportPageEntity({
    required this.reportKey,
    required this.headers,
    required this.page,
    required this.summaryMetrics,
    this.thresholdDays = 7,
  });

  const ReportPageEntity.empty({this.reportKey = ''})
    : headers = const [],
      page = const PagedResult.empty(pageSize: 25),
      summaryMetrics = const {},
      thresholdDays = 7;

  factory ReportPageEntity.fromRpcJson(ReportJsonMap json) {
    final rawHeaders = json['headers'] as List? ?? const [];
    final headers = [for (final h in rawHeaders) h.toString()];

    final rawRows = json['rows'] as List? ?? const [];
    final parsedRows = <ReportCellsRow>[];
    for (final row in rawRows) {
      if (row is List) {
        parsedRows.add([for (final cell in row) cell?.toString() ?? '—']);
      }
    }

    final rawSummary = json['summary_metrics'];
    final summary = <String, String>{};
    if (rawSummary is Map) {
      for (final entry in rawSummary.entries) {
        summary[entry.key.toString()] = entry.value?.toString() ?? '0';
      }
    }

    final pageNum = (json['page'] as num?)?.toInt() ?? 1;
    final pageSize = (json['page_size'] as num?)?.toInt() ?? 25;
    final totalCount =
        (json['total_count'] as num?)?.toInt() ?? parsedRows.length;
    final totalPages = (json['total_pages'] as num?)?.toInt() ?? 1;

    final paged = PagedResult<ReportCellsRow>(
      items: parsedRows,
      page: pageNum,
      pageSize: pageSize,
      totalCount: totalCount,
      totalPages: totalPages < 1 ? 1 : totalPages,
      hasPrev: json['has_prev'] as bool? ?? (pageNum > 1),
      hasNext: json['has_next'] as bool? ?? (pageNum < totalPages),
    );

    return ReportPageEntity(
      reportKey: json['report_key']?.toString() ?? '',
      headers: headers,
      page: paged,
      summaryMetrics: summary,
      thresholdDays: (json['threshold_days'] as num?)?.toInt() ?? 7,
    );
  }

  @override
  List<Object?> get props => [
    reportKey,
    headers,
    page,
    summaryMetrics,
    thresholdDays,
  ];
}
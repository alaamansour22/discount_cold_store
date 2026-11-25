import 'package:equatable/equatable.dart';

import '../../../../core/pagination/paged_result.dart';

/// كيان الصنف النشط المستحق أو المقترب من الإعدام (من rpc_get_condemnation_alerts_paginated / v_active_pallet_items)
class CondemnationAlertItemEntity extends Equatable {
  final String palletItemId;
  final String palletId;
  final String palletReference;
  final String itemName;
  final double quantity;
  final String unitDb;
  final String unitArLabel;
  final DateTime productionDate;
  final DateTime expiryDate;
  final String sourceDb;
  final String sourceArLabel;
  final String slotCode;
  final String receivedByName;
  final int daysUntilExpiry;
  final int globalThresholdDays;
  final String healthStatus; // 'expired' | 'due_for_condemnation' | 'healthy'

  const CondemnationAlertItemEntity({
    required this.palletItemId,
    required this.palletId,
    required this.palletReference,
    required this.itemName,
    required this.quantity,
    required this.unitDb,
    required this.unitArLabel,
    required this.productionDate,
    required this.expiryDate,
    required this.sourceDb,
    required this.sourceArLabel,
    required this.slotCode,
    required this.receivedByName,
    required this.daysUntilExpiry,
    required this.globalThresholdDays,
    required this.healthStatus,
  });

  bool get isExpired => daysUntilExpiry <= 0 || healthStatus == 'expired';

  @override
  List<Object?> get props => [
    palletItemId,
    palletId,
    palletReference,
    itemName,
    quantity,
    expiryDate,
    slotCode,
    daysUntilExpiry,
    healthStatus,
  ];
}

class CondemnationAlertsFilter extends Equatable {
  final int page;
  final int pageSize;
  final String search;
  final String? status; // 'expired' | 'due_soon' | null

  const CondemnationAlertsFilter({
    this.page = 1,
    this.pageSize = 20,
    this.search = '',
    this.status,
  });

  bool get hasActiveFilters => search.trim().isNotEmpty || status != null;

  CondemnationAlertsFilter copyWith({
    int? page,
    int? pageSize,
    String? search,
    String? status,
    bool clearStatus = false,
  }) {
    return CondemnationAlertsFilter(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      search: search ?? this.search,
      status: clearStatus ? null : (status ?? this.status),
    );
  }

  @override
  List<Object?> get props => [page, pageSize, search, status];
}

class CondemnationAlertsSummaryEntity extends Equatable {
  final int globalThresholdDays;
  final int userCustomAlertDays;
  final int totalAlerts;
  final int expiredCount;
  final int dueSoonCount;

  const CondemnationAlertsSummaryEntity({
    this.globalThresholdDays = 7,
    this.userCustomAlertDays = 7,
    this.totalAlerts = 0,
    this.expiredCount = 0,
    this.dueSoonCount = 0,
  });

  @override
  List<Object?> get props => [
    globalThresholdDays,
    userCustomAlertDays,
    totalAlerts,
    expiredCount,
    dueSoonCount,
  ];
}

class CondemnationAlertsPageEntity extends Equatable {
  final PagedResult<CondemnationAlertItemEntity> page;
  final CondemnationAlertsSummaryEntity summary;

  const CondemnationAlertsPageEntity({
    required this.page,
    required this.summary,
  });

  const CondemnationAlertsPageEntity.empty()
    : page = const PagedResult.empty(),
      summary = const CondemnationAlertsSummaryEntity();

  @override
  List<Object?> get props => [page, summary];
}

/// كيان سجل الإعدام الفعلي المعتمد (من rpc_get_condemnation_history_paginated)
class CondemnationHistoryRecordEntity extends Equatable {
  final String id;
  final String palletId;
  final String? palletItemId;
  final String palletReference;
  final String itemName;
  final double condemnedQuantity;
  final String unitDb;
  final String unitArLabel;
  final DateTime productionDate;
  final DateTime expiryDate;
  final String sourceDb;
  final String sourceArLabel;
  final String slotCode;
  final int daysRemainingAtCondemnation;
  final int thresholdAppliedDays;
  final String reason;
  final String approvedByName;
  final DateTime createdAt;

  const CondemnationHistoryRecordEntity({
    required this.id,
    required this.palletId,
    this.palletItemId,
    this.palletReference = '—',
    required this.itemName,
    required this.condemnedQuantity,
    required this.unitDb,
    required this.unitArLabel,
    required this.productionDate,
    required this.expiryDate,
    required this.sourceDb,
    required this.sourceArLabel,
    required this.slotCode,
    required this.daysRemainingAtCondemnation,
    required this.thresholdAppliedDays,
    required this.reason,
    required this.approvedByName,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    palletId,
    palletReference,
    itemName,
    condemnedQuantity,
    slotCode,
    createdAt,
  ];
}

class CondemnationHistoryFilter extends Equatable {
  final int page;
  final int pageSize;
  final String search;
  final String? source; // 'production' | 'quality_inspection' | null
  final DateTime? fromDate;
  final DateTime? toDate;

  const CondemnationHistoryFilter({
    this.page = 1,
    this.pageSize = 20,
    this.search = '',
    this.source,
    this.fromDate,
    this.toDate,
  });

  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      source != null ||
      fromDate != null ||
      toDate != null;

  CondemnationHistoryFilter copyWith({
    int? page,
    int? pageSize,
    String? search,
    String? source,
    bool clearSource = false,
    DateTime? fromDate,
    bool clearFromDate = false,
    DateTime? toDate,
    bool clearToDate = false,
  }) {
    return CondemnationHistoryFilter(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      search: search ?? this.search,
      source: clearSource ? null : (source ?? this.source),
      fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
    );
  }

  @override
  List<Object?> get props => [page, pageSize, search, source, fromDate, toDate];
}

class CondemnationHistorySummaryEntity extends Equatable {
  final int totalRecords;
  final double totalQuantity;
  final String totalsByUnitSummary;

  const CondemnationHistorySummaryEntity({
    this.totalRecords = 0,
    this.totalQuantity = 0,
    this.totalsByUnitSummary = '0',
  });

  @override
  List<Object?> get props => [totalRecords, totalQuantity, totalsByUnitSummary];
}

class CondemnationHistoryPageEntity extends Equatable {
  final PagedResult<CondemnationHistoryRecordEntity> page;
  final CondemnationHistorySummaryEntity summary;

  const CondemnationHistoryPageEntity({
    required this.page,
    required this.summary,
  });

  const CondemnationHistoryPageEntity.empty()
    : page = const PagedResult.empty(),
      summary = const CondemnationHistorySummaryEntity();

  @override
  List<Object?> get props => [page, summary];
}
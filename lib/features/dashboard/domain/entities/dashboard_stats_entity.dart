import 'package:equatable/equatable.dart';

import '../../../../core/pagination/paged_result.dart';

typedef DashboardJsonMap = Map<String, dynamic>;

class DashboardNotificationEntity extends Equatable {
  final String id;
  final String notificationType;
  final String title;
  final String body;
  final String? slotCode;
  final int? daysRemaining;
  final int? userThresholdDays;
  final bool isRead;
  final DateTime createdAt;

  const DashboardNotificationEntity({
    required this.id,
    required this.notificationType,
    required this.title,
    required this.body,
    this.slotCode,
    this.daysRemaining,
    this.userThresholdDays,
    required this.isRead,
    required this.createdAt,
  });

  factory DashboardNotificationEntity.fromJson(DashboardJsonMap json) {
    return DashboardNotificationEntity(
      id: json['id']?.toString() ?? '',
      notificationType: json['notification_type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      slotCode: json['slot_code'] as String?,
      daysRemaining: (json['days_remaining'] as num?)?.toInt(),
      userThresholdDays: (json['user_threshold_days'] as num?)?.toInt(),
      isRead: json['is_read'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, isRead, createdAt];
}

class DashboardNotificationsFilter extends Equatable {
  final int page;
  final int pageSize;
  final bool unreadOnly;

  const DashboardNotificationsFilter({
    this.page = 1,
    this.pageSize = 20,
    this.unreadOnly = false,
  });

  DashboardNotificationsFilter copyWith({
    int? page,
    int? pageSize,
    bool? unreadOnly,
  }) {
    return DashboardNotificationsFilter(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      unreadOnly: unreadOnly ?? this.unreadOnly,
    );
  }

  @override
  List<Object?> get props => [page, pageSize, unreadOnly];
}

class DashboardNotificationsSummaryEntity extends Equatable {
  final int totalNotifications;
  final int unreadCount;

  const DashboardNotificationsSummaryEntity({
    this.totalNotifications = 0,
    this.unreadCount = 0,
  });

  @override
  List<Object?> get props => [totalNotifications, unreadCount];
}

class DashboardNotificationsPageEntity extends Equatable {
  final PagedResult<DashboardNotificationEntity> page;
  final DashboardNotificationsSummaryEntity summary;

  const DashboardNotificationsPageEntity({
    required this.page,
    required this.summary,
  });

  const DashboardNotificationsPageEntity.empty()
    : page = const PagedResult.empty(),
      summary = const DashboardNotificationsSummaryEntity();

  @override
  List<Object?> get props => [page, summary];
}

class DashboardCriticalItemEntity extends Equatable {
  final String palletItemId;
  final String itemName;
  final String slotCode;
  final double quantity;
  final String unit;
  final int daysUntilExpiry;
  final String healthStatus;

  const DashboardCriticalItemEntity({
    required this.palletItemId,
    required this.itemName,
    required this.slotCode,
    required this.quantity,
    required this.unit,
    required this.daysUntilExpiry,
    required this.healthStatus,
  });

  factory DashboardCriticalItemEntity.fromJson(DashboardJsonMap json) {
    return DashboardCriticalItemEntity(
      palletItemId: json['pallet_item_id']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      slotCode: json['slot_code']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: json['unit']?.toString() ?? 'carton',
      daysUntilExpiry: (json['days_until_expiry'] as num?)?.toInt() ?? 0,
      healthStatus:
          json['condemnation_health_status']?.toString() ?? 'healthy',
    );
  }

  bool get isExpired => daysUntilExpiry <= 0 || healthStatus == 'expired';

  @override
  List<Object?> get props => [
    palletItemId,
    itemName,
    slotCode,
    quantity,
    unit,
    daysUntilExpiry,
    healthStatus,
  ];
}

class DashboardRecentMovementEntity extends Equatable {
  final String id;
  final String movementType;
  final String itemName;
  final double quantityChanged;
  final String unit;
  final String? fromSlotCode;
  final String? toSlotCode;
  final DateTime createdAt;

  const DashboardRecentMovementEntity({
    required this.id,
    required this.movementType,
    required this.itemName,
    required this.quantityChanged,
    required this.unit,
    this.fromSlotCode,
    this.toSlotCode,
    required this.createdAt,
  });

  factory DashboardRecentMovementEntity.fromJson(DashboardJsonMap json) {
    return DashboardRecentMovementEntity(
      id: json['id']?.toString() ?? '',
      movementType: json['movement_type']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      quantityChanged: (json['quantity_changed'] as num?)?.toDouble() ?? 0,
      unit: json['unit']?.toString() ?? 'carton',
      fromSlotCode: json['from_slot_code'] as String?,
      toSlotCode: json['to_slot_code'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    movementType,
    itemName,
    quantityChanged,
    unit,
    fromSlotCode,
    toSlotCode,
    createdAt,
  ];
}

class DashboardStatsEntity extends Equatable {
  final int totalSlots;
  final int occupiedSlots;
  final int emptySlots;
  final int zoneC2Total;
  final int zoneC2Occupied;
  final int zoneC3Total;
  final int zoneC3Occupied;
  final int mixedPalletsCount;
  final int activeItemsCount;
  final int nearExpiryAlertsCount;
  final int expiredItemsCount;
  final int totalCondemnedRecordsCount;
  final int todayMovementsCount;
  final int userAlertDays;
  final int unreadNotificationsCount;
  final List<DashboardCriticalItemEntity> criticalItems;
  final List<DashboardRecentMovementEntity> recentMovements;

  const DashboardStatsEntity({
    this.totalSlots = 320,
    this.occupiedSlots = 0,
    this.emptySlots = 320,
    this.zoneC2Total = 208,
    this.zoneC2Occupied = 0,
    this.zoneC3Total = 112,
    this.zoneC3Occupied = 0,
    this.mixedPalletsCount = 0,
    this.activeItemsCount = 0,
    this.nearExpiryAlertsCount = 0,
    this.expiredItemsCount = 0,
    this.totalCondemnedRecordsCount = 0,
    this.todayMovementsCount = 0,
    this.userAlertDays = 7,
    this.unreadNotificationsCount = 0,
    this.criticalItems = const [],
    this.recentMovements = const [],
  });

  double get zoneC2OccupancyRate =>
      zoneC2Total == 0 ? 0 : zoneC2Occupied / zoneC2Total;

  double get zoneC3OccupancyRate =>
      zoneC3Total == 0 ? 0 : zoneC3Occupied / zoneC3Total;

  double get overallOccupancyRate =>
      totalSlots == 0 ? 0 : occupiedSlots / totalSlots;

  int get dueSoonOnlyCount =>
      (nearExpiryAlertsCount - expiredItemsCount).clamp(0, activeItemsCount);

  int get healthyItemsCount =>
      (activeItemsCount - nearExpiryAlertsCount).clamp(0, activeItemsCount);

  @override
  List<Object?> get props => [
    totalSlots,
    occupiedSlots,
    emptySlots,
    zoneC2Total,
    zoneC2Occupied,
    zoneC3Total,
    zoneC3Occupied,
    mixedPalletsCount,
    activeItemsCount,
    nearExpiryAlertsCount,
    expiredItemsCount,
    totalCondemnedRecordsCount,
    todayMovementsCount,
    userAlertDays,
    unreadNotificationsCount,
    criticalItems,
    recentMovements,
  ];
}
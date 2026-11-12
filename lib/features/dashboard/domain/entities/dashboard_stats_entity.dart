import 'package:equatable/equatable.dart';

class DashboardNotificationEntity extends Equatable {
  final String id;
  final String notificationType;
  final String title;
  final String body;
  final String? slotCode;
  final bool isRead;
  final DateTime createdAt;

  const DashboardNotificationEntity({
    required this.id,
    required this.notificationType,
    required this.title,
    required this.body,
    this.slotCode,
    required this.isRead,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, isRead, createdAt];
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
  });

  double get zoneC2OccupancyRate =>
      zoneC2Total == 0 ? 0 : zoneC2Occupied / zoneC2Total;

  double get zoneC3OccupancyRate =>
      zoneC3Total == 0 ? 0 : zoneC3Occupied / zoneC3Total;

  double get overallOccupancyRate =>
      totalSlots == 0 ? 0 : occupiedSlots / totalSlots;

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
      ];
}
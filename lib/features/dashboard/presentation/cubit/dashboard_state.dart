import 'package:equatable/equatable.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/entities/dashboard_stats_entity.dart';

class DashboardState extends Equatable {
  final bool isLoading;
  final bool isRefreshing;
  final DashboardStatsEntity stats;

  // إشعارات المستخدم (Server-Side Pagination + فلتر غير المقروءة)
  final bool isNotificationsLoading;
  final bool notificationsInitialized;
  final DashboardNotificationsPageEntity notificationsData;
  final DashboardNotificationsFilter notificationsFilter;

  final DateTime? lastUpdated;
  final AppFailure? failure;

  const DashboardState({
    this.isLoading = true,
    this.isRefreshing = false,
    this.stats = const DashboardStatsEntity(),
    this.isNotificationsLoading = false,
    this.notificationsInitialized = false,
    this.notificationsData = const DashboardNotificationsPageEntity.empty(),
    this.notificationsFilter = const DashboardNotificationsFilter(),
    this.lastUpdated,
    this.failure,
  });

  int get unreadNotificationsCount => notificationsInitialized
      ? notificationsData.summary.unreadCount
      : stats.unreadNotificationsCount;

  List<DashboardNotificationEntity> get notifications =>
      notificationsData.page.items;

  DashboardState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    DashboardStatsEntity? stats,
    bool? isNotificationsLoading,
    bool? notificationsInitialized,
    DashboardNotificationsPageEntity? notificationsData,
    DashboardNotificationsFilter? notificationsFilter,
    DateTime? lastUpdated,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      stats: stats ?? this.stats,
      isNotificationsLoading:
          isNotificationsLoading ?? this.isNotificationsLoading,
      notificationsInitialized:
          notificationsInitialized ?? this.notificationsInitialized,
      notificationsData: notificationsData ?? this.notificationsData,
      notificationsFilter: notificationsFilter ?? this.notificationsFilter,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isRefreshing,
    stats,
    isNotificationsLoading,
    notificationsInitialized,
    notificationsData,
    notificationsFilter,
    lastUpdated,
    failure,
  ];
}
import 'package:equatable/equatable.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/entities/dashboard_stats_entity.dart';

class DashboardState extends Equatable {
  final bool isLoading;
  final bool isRefreshing;
  final DashboardStatsEntity stats;
  final List<DashboardNotificationEntity> notifications;
  final DateTime? lastUpdated;
  final AppFailure? failure;

  const DashboardState({
    this.isLoading = true,
    this.isRefreshing = false,
    this.stats = const DashboardStatsEntity(),
    this.notifications = const [],
    this.lastUpdated,
    this.failure,
  });

  int get unreadNotificationsCount =>
      notifications.where((n) => !n.isRead).length;

  DashboardState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    DashboardStatsEntity? stats,
    List<DashboardNotificationEntity>? notifications,
    DateTime? lastUpdated,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      stats: stats ?? this.stats,
      notifications: notifications ?? this.notifications,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isRefreshing,
    stats,
    notifications,
    lastUpdated,
    failure,
  ];
}
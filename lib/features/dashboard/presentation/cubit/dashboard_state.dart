import 'package:equatable/equatable.dart';
import '../../../../core/error/error_handler.dart';
import '../../domain/entities/dashboard_stats_entity.dart';

class DashboardState extends Equatable {
  final bool isLoading;
  final DashboardStatsEntity stats;
  final List<DashboardNotificationEntity> notifications;
  final AppFailure? failure;

  const DashboardState({
    this.isLoading = true,
    this.stats = const DashboardStatsEntity(),
    this.notifications = const [],
    this.failure,
  });

  int get unreadNotificationsCount =>
      notifications.where((n) => !n.isRead).length;

  DashboardState copyWith({
    bool? isLoading,
    DashboardStatsEntity? stats,
    List<DashboardNotificationEntity>? notifications,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      stats: stats ?? this.stats,
      notifications: notifications ?? this.notifications,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [isLoading, stats, notifications, failure];
}
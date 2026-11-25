import '../entities/dashboard_stats_entity.dart';

abstract class IDashboardRepository {
  Future<DashboardStatsEntity> getDashboardStatistics();

  Future<DashboardNotificationsPageEntity> getUserNotificationsPaginated(
    DashboardNotificationsFilter filter,
  );

  Future<void> markAllNotificationsAsRead();

  Stream<void> watchRealtimeDashboardChanges();
}
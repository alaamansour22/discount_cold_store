import '../entities/dashboard_stats_entity.dart';

abstract class IDashboardRepository {
  Future<DashboardStatsEntity> getDashboardStatistics();
  Future<List<DashboardNotificationEntity>> getUserNotifications();
  Future<void> markAllNotificationsAsRead();
  Stream<void> watchRealtimeDashboardChanges();
}
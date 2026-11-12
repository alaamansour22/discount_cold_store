import '../../../../core/error/error_handler.dart';
import '../../domain/entities/dashboard_stats_entity.dart';
import '../../domain/repositories/i_dashboard_repository.dart';
import '../datasources/dashboard_remote_data_source.dart';

class DashboardRepositoryImpl implements IDashboardRepository {
  final IDashboardRemoteDataSource _remoteDataSource;

  DashboardRepositoryImpl(this._remoteDataSource);

  @override
  Future<DashboardStatsEntity> getDashboardStatistics() async {
    try {
      return await _remoteDataSource.fetchStats();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<DashboardNotificationEntity>> getUserNotifications() async {
    try {
      return await _remoteDataSource.fetchNotifications();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> markAllNotificationsAsRead() async {
    try {
      await _remoteDataSource.markAllNotificationsRead();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Stream<void> watchRealtimeDashboardChanges() =>
      _remoteDataSource.subscribeToChanges();
}
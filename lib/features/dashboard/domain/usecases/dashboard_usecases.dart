import '../entities/dashboard_stats_entity.dart';
import '../repositories/i_dashboard_repository.dart';

class GetDashboardStatisticsUseCase {
  final IDashboardRepository _repository;
  const GetDashboardStatisticsUseCase(this._repository);

  Future<DashboardStatsEntity> call() => _repository.getDashboardStatistics();
}

class GetDashboardNotificationsUseCase {
  final IDashboardRepository _repository;
  const GetDashboardNotificationsUseCase(this._repository);

  Future<List<DashboardNotificationEntity>> call() =>
      _repository.getUserNotifications();
}

class MarkAllDashboardNotificationsReadUseCase {
  final IDashboardRepository _repository;
  const MarkAllDashboardNotificationsReadUseCase(this._repository);

  Future<void> call() => _repository.markAllNotificationsAsRead();
}

class WatchRealtimeDashboardChangesUseCase {
  final IDashboardRepository _repository;
  const WatchRealtimeDashboardChangesUseCase(this._repository);

  Stream<void> call() => _repository.watchRealtimeDashboardChanges();
}

/// حزمة UseCases مجمعة لموديول Dashboard
class DashboardUseCases {
  final GetDashboardStatisticsUseCase getStats;
  final GetDashboardNotificationsUseCase getNotifications;
  final MarkAllDashboardNotificationsReadUseCase markAllNotificationsRead;
  final WatchRealtimeDashboardChangesUseCase watchRealtimeChanges;

  DashboardUseCases(IDashboardRepository repository)
    : getStats = GetDashboardStatisticsUseCase(repository),
      getNotifications = GetDashboardNotificationsUseCase(repository),
      markAllNotificationsRead = MarkAllDashboardNotificationsReadUseCase(
        repository,
      ),
      watchRealtimeChanges = WatchRealtimeDashboardChangesUseCase(repository);
}
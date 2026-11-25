import '../entities/dashboard_stats_entity.dart';
import '../repositories/i_dashboard_repository.dart';

class GetDashboardStatisticsUseCase {
  final IDashboardRepository _repository;
  const GetDashboardStatisticsUseCase(this._repository);

  Future<DashboardStatsEntity> call() => _repository.getDashboardStatistics();
}

class GetDashboardNotificationsPaginatedUseCase {
  final IDashboardRepository _repository;
  const GetDashboardNotificationsPaginatedUseCase(this._repository);

  Future<DashboardNotificationsPageEntity> call(
    DashboardNotificationsFilter filter,
  ) {
    final normalized = filter.copyWith(
      page: filter.page < 1 ? 1 : filter.page,
      pageSize: filter.pageSize.clamp(1, 100),
    );
    return _repository.getUserNotificationsPaginated(normalized);
  }
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
  final GetDashboardNotificationsPaginatedUseCase getNotifications;
  final MarkAllDashboardNotificationsReadUseCase markAllNotificationsRead;
  final WatchRealtimeDashboardChangesUseCase watchRealtimeChanges;

  DashboardUseCases(IDashboardRepository repository)
    : getStats = GetDashboardStatisticsUseCase(repository),
      getNotifications = GetDashboardNotificationsPaginatedUseCase(repository),
      markAllNotificationsRead = MarkAllDashboardNotificationsReadUseCase(
        repository,
      ),
      watchRealtimeChanges = WatchRealtimeDashboardChangesUseCase(repository);
}
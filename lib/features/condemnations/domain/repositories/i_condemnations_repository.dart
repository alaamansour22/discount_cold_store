import '../entities/condemnations_entities.dart';

abstract class ICondemnationsRepository {
  Future<CondemnationAlertsPageEntity> getActiveAlertsPaginated(
    CondemnationAlertsFilter filter,
  );

  Future<CondemnationHistoryPageEntity> getCondemnationHistoryPaginated(
    CondemnationHistoryFilter filter,
  );

  Future<void> approveItemCondemnation({
    required String palletItemId,
    required double quantityToCondemn,
    required String reason,
  });

  Stream<void> watchRealtimeCondemnationChanges();
}
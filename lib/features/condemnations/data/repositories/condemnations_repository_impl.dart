import '../../../../core/error/error_handler.dart';
import '../../domain/entities/condemnations_entities.dart';
import '../../domain/repositories/i_condemnations_repository.dart';
import '../datasources/condemnations_remote_data_source.dart';

class CondemnationsRepositoryImpl implements ICondemnationsRepository {
  final ICondemnationsRemoteDataSource _remoteDataSource;

  CondemnationsRepositoryImpl(this._remoteDataSource);

  @override
  Future<
    ({
      List<CondemnationAlertItemEntity> alertItems,
      int globalThresholdDays,
      int userCustomAlertDays,
    })
  >
  getActiveCondemnationAlerts() async {
    try {
      final dto = await _remoteDataSource.fetchActiveAlertsAndThresholds();
      return (
        alertItems: dto.alertItems,
        globalThresholdDays: dto.globalThresholdDays,
        userCustomAlertDays: dto.userCustomAlertDays,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<CondemnationHistoryRecordEntity>> getCondemnationRecords({
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 300,
  }) async {
    try {
      return await _remoteDataSource.fetchCondemnationHistory(
        fromDate: fromDate,
        toDate: toDate,
        limit: limit,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> approveItemCondemnation({
    required String palletItemId,
    required double quantityToCondemn,
    required String reason,
  }) async {
    try {
      await _remoteDataSource.rpcCondemnItem(
        palletItemId: palletItemId,
        quantityToCondemn: quantityToCondemn,
        reason: reason,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Stream<void> watchRealtimeCondemnationChanges() =>
      _remoteDataSource.subscribeToCondemnationChanges();
}

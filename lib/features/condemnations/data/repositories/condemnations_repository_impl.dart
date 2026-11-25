import '../../../../core/error/error_handler.dart';
import '../../domain/entities/condemnations_entities.dart';
import '../../domain/repositories/i_condemnations_repository.dart';
import '../datasources/condemnations_remote_data_source.dart';

class CondemnationsRepositoryImpl implements ICondemnationsRepository {
  final ICondemnationsRemoteDataSource _remoteDataSource;

  CondemnationsRepositoryImpl(this._remoteDataSource);

  @override
  Future<CondemnationAlertsPageEntity> getActiveAlertsPaginated(
    CondemnationAlertsFilter filter,
  ) async {
    try {
      return await _remoteDataSource.fetchAlertsPaginated(filter);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<CondemnationHistoryPageEntity> getCondemnationHistoryPaginated(
    CondemnationHistoryFilter filter,
  ) async {
    try {
      return await _remoteDataSource.fetchHistoryPaginated(filter);
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
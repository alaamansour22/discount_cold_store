import 'package:discount_cold_store/features/movements_log/domain/entities/movements_log_entities.dart';
import 'package:discount_cold_store/features/movements_log/domain/repositories/i_movements_log_repository.dart';
import 'package:discount_cold_store/features/receiving_dispatch/domain/entities/receiving_dispatch_entities.dart';

import '../../../../core/error/error_handler.dart';

import '../datasources/movements_log_remote_data_source.dart';

class MovementsLogRepositoryImpl implements IMovementsLogRepository {
  final IMovementsLogRemoteDataSource _remoteDataSource;

  MovementsLogRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<SystemMovementEntity>> getAllMovements({
    DateTime? fromDate,
    DateTime? toDate,
    MovementActionType? movementTypeFilter,
    ReceivingSource? sourceFilter,
    int limit = 400,
  }) async {
    try {
      return await _remoteDataSource.fetchMovements(
        fromDate: fromDate,
        toDate: toDate,
        movementTypeFilter: movementTypeFilter,
        sourceFilter: sourceFilter,
        limit: limit,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Stream<void> watchRealtimeMovements() =>
      _remoteDataSource.subscribeToMovements();
}

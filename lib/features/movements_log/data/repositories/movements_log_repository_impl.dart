import '../../../../core/error/error_handler.dart';
import '../../domain/entities/deleted_record_entity.dart';
import '../../domain/entities/movements_log_entities.dart';
import '../../domain/repositories/i_movements_log_repository.dart';
import '../datasources/movements_log_remote_data_source.dart';

class MovementsLogRepositoryImpl implements IMovementsLogRepository {
  final IMovementsLogRemoteDataSource _remoteDataSource;

  MovementsLogRepositoryImpl(this._remoteDataSource);

  @override
  Future<MovementsLogPageEntity> getMovementsPaginated(
    MovementsLogFilter filter,
  ) async {
    try {
      return await _remoteDataSource.fetchMovementsPaginated(filter);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Stream<void> watchRealtimeMovements() =>
      _remoteDataSource.subscribeToMovements();

  @override
  Future<DeletedRecordsPageEntity> getDeletedRecordsPaginated(
    DeletedRecordsFilter filter,
  ) async {
    try {
      return await _remoteDataSource.fetchDeletedRecordsPaginated(filter);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Stream<void> watchRealtimeDeletedRecords() =>
      _remoteDataSource.subscribeToDeletedRecords();
}
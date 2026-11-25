import '../../../../core/error/error_handler.dart';
import '../entities/deleted_record_entity.dart';
import '../entities/movements_log_entities.dart';
import '../repositories/i_movements_log_repository.dart';

class GetSystemMovementsPaginatedUseCase {
  final IMovementsLogRepository _repository;
  const GetSystemMovementsPaginatedUseCase(this._repository);

  Future<MovementsLogPageEntity> call(MovementsLogFilter filter) async {
    if (filter.fromDate != null &&
        filter.toDate != null &&
        filter.toDate!.isBefore(filter.fromDate!)) {
      throw const AppFailure(
        message: 'تاريخ النهاية يجب أن يكون بعد أو يساوي تاريخ البداية.',
        type: FailureType.validationError,
      );
    }

    final normalized = filter.copyWith(
      page: filter.page < 1 ? 1 : filter.page,
      pageSize: filter.pageSize.clamp(1, 1000),
      search: filter.search.trim(),
    );

    return _repository.getMovementsPaginated(normalized);
  }
}

class WatchRealtimeMovementsUseCase {
  final IMovementsLogRepository _repository;
  const WatchRealtimeMovementsUseCase(this._repository);

  Stream<void> call() => _repository.watchRealtimeMovements();
}

class GetDeletedRecordsPaginatedUseCase {
  final IMovementsLogRepository _repository;
  const GetDeletedRecordsPaginatedUseCase(this._repository);

  Future<DeletedRecordsPageEntity> call(DeletedRecordsFilter filter) async {
    if (filter.fromDate != null &&
        filter.toDate != null &&
        filter.toDate!.isBefore(filter.fromDate!)) {
      throw const AppFailure(
        message: 'تاريخ النهاية يجب أن يكون بعد أو يساوي تاريخ البداية.',
        type: FailureType.validationError,
      );
    }

    final normalized = filter.copyWith(
      page: filter.page < 1 ? 1 : filter.page,
      pageSize: filter.pageSize.clamp(1, 500),
      search: filter.search.trim(),
    );

    return _repository.getDeletedRecordsPaginated(normalized);
  }
}

class WatchRealtimeDeletedRecordsUseCase {
  final IMovementsLogRepository _repository;
  const WatchRealtimeDeletedRecordsUseCase(this._repository);

  Stream<void> call() => _repository.watchRealtimeDeletedRecords();
}

class MovementsLogUseCases {
  final GetSystemMovementsPaginatedUseCase getMovements;
  final WatchRealtimeMovementsUseCase watchRealtime;
  final GetDeletedRecordsPaginatedUseCase getDeletedRecords;
  final WatchRealtimeDeletedRecordsUseCase watchRealtimeDeletedRecords;

  MovementsLogUseCases(IMovementsLogRepository repository)
    : getMovements = GetSystemMovementsPaginatedUseCase(repository),
      watchRealtime = WatchRealtimeMovementsUseCase(repository),
      getDeletedRecords = GetDeletedRecordsPaginatedUseCase(repository),
      watchRealtimeDeletedRecords = WatchRealtimeDeletedRecordsUseCase(
        repository,
      );
}
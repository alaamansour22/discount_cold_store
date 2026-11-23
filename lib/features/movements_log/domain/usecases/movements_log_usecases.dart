import 'package:discount_cold_store/features/receiving/domain/entities/receiving_entities.dart';

import '../../../../core/error/error_handler.dart';
import '../entities/deleted_record_entity.dart';
import '../entities/movements_log_entities.dart';
import '../repositories/i_movements_log_repository.dart';

class GetSystemMovementsUseCase {
  final IMovementsLogRepository _repository;
  const GetSystemMovementsUseCase(this._repository);

  Future<List<SystemMovementEntity>> call({
    DateTime? fromDate,
    DateTime? toDate,
    MovementActionType? movementTypeFilter,
    ReceivingSource? sourceFilter,
    int limit = 400,
  }) async {
    if (fromDate != null && toDate != null && toDate.isBefore(fromDate)) {
      throw const AppFailure(
        message: 'تاريخ النهاية يجب أن يكون بعد أو يساوي تاريخ البداية.',
        type: FailureType.validationError,
      );
    }
    return _repository.getAllMovements(
      fromDate: fromDate,
      toDate: toDate,
      movementTypeFilter: movementTypeFilter,
      sourceFilter: sourceFilter,
      limit: limit,
    );
  }
}

class WatchRealtimeMovementsUseCase {
  final IMovementsLogRepository _repository;
  const WatchRealtimeMovementsUseCase(this._repository);

  Stream<void> call() => _repository.watchRealtimeMovements();
}

class GetDeletedRecordsUseCase {
  final IMovementsLogRepository _repository;
  const GetDeletedRecordsUseCase(this._repository);

  Future<List<DeletedRecordEntity>> call({
    DateTime? fromDate,
    DateTime? toDate,
    DeletedActionKind? kindFilter,
    int limit = 300,
  }) async {
    if (fromDate != null && toDate != null && toDate.isBefore(fromDate)) {
      throw const AppFailure(
        message: 'تاريخ النهاية يجب أن يكون بعد أو يساوي تاريخ البداية.',
        type: FailureType.validationError,
      );
    }
    return _repository.getDeletedRecords(
      fromDate: fromDate,
      toDate: toDate,
      kindFilter: kindFilter,
      limit: limit,
    );
  }
}

class WatchRealtimeDeletedRecordsUseCase {
  final IMovementsLogRepository _repository;
  const WatchRealtimeDeletedRecordsUseCase(this._repository);

  Stream<void> call() => _repository.watchRealtimeDeletedRecords();
}

class MovementsLogUseCases {
  final GetSystemMovementsUseCase getMovements;
  final WatchRealtimeMovementsUseCase watchRealtime;
  final GetDeletedRecordsUseCase getDeletedRecords;
  final WatchRealtimeDeletedRecordsUseCase watchRealtimeDeletedRecords;

  MovementsLogUseCases(IMovementsLogRepository repository)
    : getMovements = GetSystemMovementsUseCase(repository),
      watchRealtime = WatchRealtimeMovementsUseCase(repository),
      getDeletedRecords = GetDeletedRecordsUseCase(repository),
      watchRealtimeDeletedRecords = WatchRealtimeDeletedRecordsUseCase(
        repository,
      );
}
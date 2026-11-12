import 'package:discount_cold_store/features/receiving_dispatch/domain/entities/receiving_dispatch_entities.dart';

import '../../../../core/error/error_handler.dart';
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

class MovementsLogUseCases {
  final GetSystemMovementsUseCase getMovements;
  final WatchRealtimeMovementsUseCase watchRealtime;

  MovementsLogUseCases(IMovementsLogRepository repository)
      : getMovements = GetSystemMovementsUseCase(repository),
        watchRealtime = WatchRealtimeMovementsUseCase(repository);
}

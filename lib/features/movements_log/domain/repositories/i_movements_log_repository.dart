import 'package:discount_cold_store/features/receiving/domain/entities/receiving_entities.dart';

import '../entities/movements_log_entities.dart';

abstract class IMovementsLogRepository {
  Future<List<SystemMovementEntity>> getAllMovements({
    DateTime? fromDate,
    DateTime? toDate,
    MovementActionType? movementTypeFilter,
    ReceivingSource? sourceFilter,
    int limit = 400,
  });

  Stream<void> watchRealtimeMovements();
}

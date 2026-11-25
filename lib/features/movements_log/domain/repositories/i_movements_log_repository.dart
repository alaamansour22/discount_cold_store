import '../entities/deleted_record_entity.dart';
import '../entities/movements_log_entities.dart';

abstract class IMovementsLogRepository {
  Future<MovementsLogPageEntity> getMovementsPaginated(
    MovementsLogFilter filter,
  );

  Stream<void> watchRealtimeMovements();

  Future<DeletedRecordsPageEntity> getDeletedRecordsPaginated(
    DeletedRecordsFilter filter,
  );

  Stream<void> watchRealtimeDeletedRecords();
}
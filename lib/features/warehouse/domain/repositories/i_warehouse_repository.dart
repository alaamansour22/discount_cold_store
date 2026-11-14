import '../../../receiving/domain/entities/receiving_entities.dart';

/// Shared warehouse read model used by receiving, dispatch and rack-map screens.
abstract class IWarehouseRepository {
  Future<List<ReceivingRackSlotEntity>> getRackSlotsWithPallets();
  Stream<void> watchRackUpdates();
}

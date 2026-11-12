import '../entities/receiving_dispatch_entities.dart';

abstract class IReceivingDispatchRepository {
  Future<List<ReceivingRackSlotEntity>> getRackSlotsWithPallets();

  Future<List<ReceivingMovementEntity>> getMovementsLog({int limit = 250});

  Future<void> receiveNewPallet({
    required ReceivingSource sourceEntity,
    required String slotId,
    required List<PalletItemDraft> items,
  });

  Future<void> addItemsToExistingPallet({
    required String palletId,
    required ReceivingSource sourceEntity,
    required List<PalletItemDraft> items,
  });

  Future<void> adjustOrReleaseItem({
    required String palletItemId,
    required MovementActionType action,
    required double targetQuantity,
    String notes = '',
  });

  Stream<void> watchRealtimeRackUpdates();
}

import '../entities/rack_transfer_entities.dart';

abstract class IRackTransferRepository {
  Future<List<TransferSlotEntity>> getAllSlotsForTransfer();

  Future<List<RackTransferHistoryEntity>> getRelocationHistory({int limit = 150});

  Future<void> relocatePallet({
    required String palletId,
    required String targetSlotId,
    required String notes,
  });

  Stream<void> watchRealtimeTransferChanges();
}
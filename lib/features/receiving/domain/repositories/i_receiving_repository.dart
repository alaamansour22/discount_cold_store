import '../entities/receiving_entities.dart';

abstract class IReceivingRepository {
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

  Future<void> deleteMistakenPallet({
    required String palletId,
    required String reason,
  });

  /// ترجع true إذا تم إخلاء موقع الراك أيضاً (عندما يكون المحذوف آخر صنف على البالتة)
  Future<bool> deleteMistakenPalletItem({
    required String palletItemId,
    required String reason,
  });
}
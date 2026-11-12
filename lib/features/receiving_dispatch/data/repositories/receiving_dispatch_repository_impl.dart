import '../../../../core/error/error_handler.dart';
import '../../domain/entities/receiving_dispatch_entities.dart';
import '../../domain/repositories/i_receiving_dispatch_repository.dart';
import '../datasources/receiving_dispatch_remote_data_source.dart';
import '../models/receiving_dispatch_models.dart';

class ReceivingDispatchRepositoryImpl implements IReceivingDispatchRepository {
  final IReceivingDispatchRemoteDataSource _remoteDataSource;

  ReceivingDispatchRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<ReceivingRackSlotEntity>> getRackSlotsWithPallets() async {
    try {
      final rawSlots = await _remoteDataSource.fetchRawRackSlots();
      final activeItems = await _remoteDataSource.fetchActivePalletItems();

      final Map<String, List<ReceivingPalletItemModel>> itemsBySlotId = {};
      for (final item in activeItems) {
        if (item.slotId.isNotEmpty) {
          itemsBySlotId.putIfAbsent(item.slotId, () => []).add(item);
        }
      }

      return rawSlots.map((map) {
        final slotId = map['id'] as String;
        final slotCode = map['slot_code'] as String;
        final slotItems = itemsBySlotId[slotId] ?? [];

        ReceivingPalletEntity? pallet;
        if (slotItems.isNotEmpty) {
          pallet = ReceivingPalletEntity(
            id: slotItems.first.palletId,
            palletReference: slotItems.first.palletReference,
            slotId: slotId,
            slotCode: slotCode,
            items: slotItems,
          );
        }

        return ReceivingRackSlotEntity(
          id: slotId,
          zoneCode: map['zone_code'] as String,
          rackLetter: map['rack_letter'] as String,
          floorNumber: (map['floor_number'] as num).toInt(),
          binNumber: (map['bin_number'] as num).toInt(),
          slotCode: slotCode,
          isOccupied: (map['is_occupied'] as bool? ?? false) && pallet != null,
          occupiedPallet: pallet,
        );
      }).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<ReceivingMovementEntity>> getMovementsLog({int limit = 250}) async {
    try {
      return await _remoteDataSource.fetchMovements(limit: limit);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> receiveNewPallet({
    required ReceivingSource sourceEntity,
    required String slotId,
    required List<PalletItemDraft> items,
  }) async {
    try {
      await _remoteDataSource.rpcReceivePallet(
        sourceEntity: sourceEntity,
        slotId: slotId,
        items: items,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> addItemsToExistingPallet({
    required String palletId,
    required ReceivingSource sourceEntity,
    required List<PalletItemDraft> items,
  }) async {
    try {
      await _remoteDataSource.rpcAddItemsToExistingPallet(
        palletId: palletId,
        sourceEntity: sourceEntity,
        items: items,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> adjustOrReleaseItem({
    required String palletItemId,
    required MovementActionType action,
    required double targetQuantity,
    String notes = '',
  }) async {
    try {
      await _remoteDataSource.rpcAdjustOrReleaseItem(
        palletItemId: palletItemId,
        action: action,
        targetQuantity: targetQuantity,
        notes: notes,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Stream<void> watchRealtimeRackUpdates() =>
      _remoteDataSource.subscribeToRackChanges();
}

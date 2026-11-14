import '../../../../core/error/error_handler.dart';
import '../../domain/entities/rack_transfer_entities.dart';
import '../../domain/repositories/i_rack_transfer_repository.dart';
import '../datasources/rack_transfer_remote_data_source.dart';
import '../models/rack_transfer_models.dart';

class RackTransferRepositoryImpl implements IRackTransferRepository {
  final IRackTransferRemoteDataSource _remoteDataSource;

  RackTransferRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<TransferSlotEntity>> getAllSlotsForTransfer() async {
    try {
      final rawSlots = await _remoteDataSource.fetchRawSlots();
      final activeItemsRows = await _remoteDataSource.fetchActiveItems();

      final Map<String, List<TransferPalletItemSummary>> itemsBySlotId = {};
      final Map<String, String> palletIdBySlotId = {};
      final Map<String, String> palletRefBySlotId = {};

      for (final row in activeItemsRows) {
        final slotId = row['slot_id'] as String? ?? '';
        if (slotId.isEmpty) continue;
        palletIdBySlotId[slotId] = row['pallet_id'] as String? ?? '';
        palletRefBySlotId[slotId] = row['pallet_reference'] as String? ?? '';
        itemsBySlotId
            .putIfAbsent(slotId, () => [])
            .add(TransferModelMapper.itemFromViewJson(row));
      }

      return rawSlots.map((map) {
        final slotId = map['id'] as String;
        final slotItems = itemsBySlotId[slotId] ?? [];
        final pId = palletIdBySlotId[slotId];

        return TransferSlotEntity(
          slotId: slotId,
          zoneCode: map['zone_code'] as String,
          rackLetter: map['rack_letter'] as String,
          floorNumber: (map['floor_number'] as num).toInt(),
          binNumber: (map['bin_number'] as num).toInt(),
          slotCode: map['slot_code'] as String,
          isOccupied:
              (map['is_occupied'] as bool? ?? false) &&
              pId != null &&
              slotItems.isNotEmpty,
          palletId: pId,
          palletReference: palletRefBySlotId[slotId],
          items: slotItems,
        );
      }).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<RackTransferHistoryEntity>> getRelocationHistory({
    int limit = 150,
  }) async {
    try {
      return await _remoteDataSource.fetchRelocationMovements(limit: limit);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> relocatePallet({
    required String palletId,
    required String targetSlotId,
    required String notes,
  }) async {
    try {
      await _remoteDataSource.rpcRelocatePallet(
        palletId: palletId,
        targetSlotId: targetSlotId,
        notes: notes,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Stream<void> watchRealtimeTransferChanges() =>
      _remoteDataSource.subscribeToRackTransferChanges();
}

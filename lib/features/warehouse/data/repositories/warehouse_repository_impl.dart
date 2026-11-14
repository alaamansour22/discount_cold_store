import '../../../../core/error/error_handler.dart';
import '../../../receiving/domain/entities/receiving_entities.dart';
import '../../../receiving/data/models/receiving_models.dart';
import '../../domain/repositories/i_warehouse_repository.dart';
import '../datasources/warehouse_remote_data_source.dart';

class WarehouseRepositoryImpl implements IWarehouseRepository {
  final IWarehouseRemoteDataSource remote;
  WarehouseRepositoryImpl(this.remote);

  @override
  Future<List<ReceivingRackSlotEntity>> getRackSlotsWithPallets() async {
    try {
      final rawSlots = await remote.fetchRawRackSlots();
      final activeItems = await remote.fetchActivePalletItems();
      final itemsBySlot = <String, List<ReceivingPalletItemModel>>{};
      for (final item in activeItems) {
        if (item.slotId.isNotEmpty)
          itemsBySlot.putIfAbsent(item.slotId, () => []).add(item);
      }
      return rawSlots.map((map) {
        final id = map['id'] as String;
        final code = map['slot_code'] as String;
        final items = itemsBySlot[id] ?? <ReceivingPalletItemModel>[];
        final pallet = items.isEmpty
            ? null
            : ReceivingPalletEntity(
                id: items.first.palletId,
                palletReference: items.first.palletReference,
                slotId: id,
                slotCode: code,
                items: items,
              );
        return ReceivingRackSlotEntity(
          id: id,
          zoneCode: map['zone_code'] as String,
          rackLetter: map['rack_letter'] as String,
          floorNumber: (map['floor_number'] as num).toInt(),
          binNumber: (map['bin_number'] as num).toInt(),
          slotCode: code,
          isOccupied: (map['is_occupied'] as bool? ?? false) && pallet != null,
          occupiedPallet: pallet,
        );
      }).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Stream<void> watchRackUpdates() => remote.subscribeToRackChanges();
}

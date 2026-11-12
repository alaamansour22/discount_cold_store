import 'package:equatable/equatable.dart';

class TransferPalletItemSummary extends Equatable {
  final String itemName;
  final double quantity;
  final String unitArLabel;
  final String sourceArLabel;
  final int daysUntilExpiry;

  const TransferPalletItemSummary({
    required this.itemName,
    required this.quantity,
    required this.unitArLabel,
    required this.sourceArLabel,
    required this.daysUntilExpiry,
  });

  @override
  List<Object?> get props => [
        itemName,
        quantity,
        unitArLabel,
        sourceArLabel,
        daysUntilExpiry,
      ];
}

class TransferSlotEntity extends Equatable {
  final String slotId;
  final String zoneCode; // 'C2' or 'C3'
  final String rackLetter; // 'A' .. 'T'
  final int floorNumber; // 1 .. 4
  final int binNumber; // 1 .. 4
  final String slotCode; // 'C2 - A02 - 4'
  final bool isOccupied;
  final String? palletId;
  final String? palletReference;
  final List<TransferPalletItemSummary> items;

  const TransferSlotEntity({
    required this.slotId,
    required this.zoneCode,
    required this.rackLetter,
    required this.floorNumber,
    required this.binNumber,
    required this.slotCode,
    required this.isOccupied,
    this.palletId,
    this.palletReference,
    this.items = const [],
  });

  bool get isMixed => items.length > 1;

  String get itemsPreviewText =>
      items.isEmpty ? 'فارغ' : items.map((e) => '${e.itemName} (${e.quantity} ${e.unitArLabel})').join(' + ');

  @override
  List<Object?> get props => [
        slotId,
        zoneCode,
        rackLetter,
        floorNumber,
        binNumber,
        slotCode,
        isOccupied,
        palletId,
        palletReference,
        items,
      ];
}

class RackTransferHistoryEntity extends Equatable {
  final String id;
  final String palletId;
  final String itemName;
  final double quantity;
  final String unitArLabel;
  final String fromSlotCode;
  final String toSlotCode;
  final String notes;
  final String performedByName;
  final DateTime createdAt;

  const RackTransferHistoryEntity({
    required this.id,
    required this.palletId,
    required this.itemName,
    required this.quantity,
    required this.unitArLabel,
    required this.fromSlotCode,
    required this.toSlotCode,
    required this.notes,
    required this.performedByName,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        palletId,
        itemName,
        fromSlotCode,
        toSlotCode,
        createdAt,
      ];
}

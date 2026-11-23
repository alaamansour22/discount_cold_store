import 'package:equatable/equatable.dart';

import '../../../receiving/domain/entities/receiving_entities.dart';

enum DeletedActionKind {
  fullPallet('DELETE_MISTAKEN_PALLET', 'حذف بالتة كاملة'),
  singleItem('DELETE_MISTAKEN_PALLET_ITEM', 'حذف صنف محدد');

  final String dbValue;
  final String arLabel;
  const DeletedActionKind(this.dbValue, this.arLabel);

  static DeletedActionKind fromDb(String val) =>
      DeletedActionKind.values.firstWhere(
        (e) => e.dbValue == val,
        orElse: () => DeletedActionKind.singleItem,
      );
}

class DeletedItemSnapshot extends Equatable {
  final String itemName;
  final double quantity;
  final PackageUnit unit;
  final DateTime? productionDate;
  final DateTime? expiryDate;

  const DeletedItemSnapshot({
    required this.itemName,
    required this.quantity,
    required this.unit,
    this.productionDate,
    this.expiryDate,
  });

  @override
  List<Object?> get props => [
    itemName,
    quantity,
    unit,
    productionDate,
    expiryDate,
  ];
}

class DeletedRecordEntity extends Equatable {
  final String id;
  final DeletedActionKind actionKind;
  final String palletReference;
  final String slotCode;
  final ReceivingSource? sourceEntity;
  final String reason;
  final String deletedByName;
  final DateTime deletedAt;
  final bool slotFreed;
  final List<DeletedItemSnapshot> items;

  const DeletedRecordEntity({
    required this.id,
    required this.actionKind,
    required this.palletReference,
    required this.slotCode,
    this.sourceEntity,
    required this.reason,
    required this.deletedByName,
    required this.deletedAt,
    required this.slotFreed,
    required this.items,
  });

  bool get isFullPallet => actionKind == DeletedActionKind.fullPallet;

  @override
  List<Object?> get props => [
    id,
    actionKind,
    palletReference,
    slotCode,
    reason,
    deletedByName,
    deletedAt,
    slotFreed,
    items,
  ];
}
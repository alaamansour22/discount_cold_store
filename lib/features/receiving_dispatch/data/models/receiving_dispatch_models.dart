import '../../domain/entities/receiving_dispatch_entities.dart';

typedef ReceivingJsonMap = Map<String, dynamic>;

class ReceivingPalletItemModel extends ReceivingPalletItemEntity {
  const ReceivingPalletItemModel({
    required super.palletItemId,
    required super.palletId,
    required super.palletReference,
    required super.itemName,
    required super.quantity,
    required super.unit,
    required super.productionDate,
    required super.expiryDate,
    required super.sourceEntity,
    required super.slotId,
    required super.slotCode,
    required super.receivedByName,
    required super.receivedAt,
    required super.daysUntilExpiry,
    required super.healthStatus,
  });

  factory ReceivingPalletItemModel.fromJson(ReceivingJsonMap json) {
    return ReceivingPalletItemModel(
      palletItemId: json['pallet_item_id'] as String,
      palletId: json['pallet_id'] as String,
      palletReference: json['pallet_reference'] as String? ?? '',
      itemName: json['item_name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: PackageUnit.fromDb(json['unit'] as String),
      productionDate: DateTime.parse(json['production_date'] as String),
      expiryDate: DateTime.parse(json['expiry_date'] as String),
      sourceEntity: ReceivingSource.fromDb(json['source_entity'] as String),
      slotId: json['slot_id'] as String? ?? '',
      slotCode: json['slot_code'] as String,
      receivedByName: json['received_by_name'] as String? ?? 'مستخدم النظام',
      receivedAt: DateTime.parse(json['received_at'] as String).toLocal(),
      daysUntilExpiry: (json['days_until_expiry'] as num?)?.toInt() ?? 0,
      healthStatus: json['condemnation_health_status'] as String? ?? 'healthy',
    );
  }
}

class ReceivingMovementModel extends ReceivingMovementEntity {
  const ReceivingMovementModel({
    required super.id,
    required super.palletId,
    required super.movementType,
    required super.itemName,
    required super.previousQuantity,
    required super.quantityChanged,
    required super.newQuantity,
    required super.unit,
    required super.sourceEntity,
    super.fromSlotCode,
    super.toSlotCode,
    super.notes,
    required super.performedByName,
    required super.createdAt,
  });

  factory ReceivingMovementModel.fromJson(ReceivingJsonMap json) {
    final profile = json['profiles'] != null
        ? ReceivingJsonMap.from(json['profiles'] as Map)
        : null;
    return ReceivingMovementModel(
      id: json['id'] as String,
      palletId: json['pallet_id'] as String,
      movementType: MovementActionType.fromDb(json['movement_type'] as String),
      itemName: json['item_name'] as String,
      previousQuantity: (json['previous_quantity'] as num?)?.toDouble() ?? 0.0,
      quantityChanged: (json['quantity_changed'] as num).toDouble(),
      newQuantity: (json['new_quantity'] as num?)?.toDouble() ?? 0.0,
      unit: PackageUnit.fromDb(json['unit'] as String),
      sourceEntity: ReceivingSource.fromDb(json['source_entity'] as String),
      fromSlotCode: json['from_slot_code'] as String?,
      toSlotCode: json['to_slot_code'] as String?,
      notes: json['notes'] as String?,
      performedByName: profile?['full_name'] as String? ?? 'مستخدم النظام',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

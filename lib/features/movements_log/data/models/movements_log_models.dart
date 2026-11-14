import 'package:discount_cold_store/features/movements_log/domain/entities/movements_log_entities.dart';
import 'package:discount_cold_store/features/receiving/domain/entities/receiving_entities.dart';

typedef MoveJsonMap = Map<String, dynamic>;

class SystemMovementModel extends SystemMovementEntity {
  const SystemMovementModel({
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

  factory SystemMovementModel.fromJson(MoveJsonMap json) {
    final profile = json['profiles'] != null
        ? MoveJsonMap.from(json['profiles'] as Map)
        : null;
    return SystemMovementModel(
      id: json['id'] as String,
      palletId: json['pallet_id'] as String,
      movementType: MovementActionType.fromDb(json['movement_type'] as String),
      itemName: json['item_name'] as String? ?? '',
      previousQuantity: (json['previous_quantity'] as num?)?.toDouble() ?? 0.0,
      quantityChanged: (json['quantity_changed'] as num?)?.toDouble() ?? 0.0,
      newQuantity: (json['new_quantity'] as num?)?.toDouble() ?? 0.0,
      unit: PackageUnit.fromDb(json['unit'] as String? ?? 'carton'),
      sourceEntity: ReceivingSource.fromDb(
        json['source_entity'] as String? ?? 'production',
      ),
      fromSlotCode: json['from_slot_code'] as String?,
      toSlotCode: json['to_slot_code'] as String?,
      notes: json['notes'] as String?,
      performedByName: profile?['full_name'] as String? ?? 'مستخدم النظام',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

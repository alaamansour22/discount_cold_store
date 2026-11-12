import 'package:discount_cold_store/features/receiving_dispatch/domain/entities/receiving_dispatch_entities.dart';
import 'package:equatable/equatable.dart';

class SystemMovementEntity extends Equatable {
  final String id;
  final String palletId;
  final MovementActionType movementType;
  final String itemName;
  final double previousQuantity;
  final double quantityChanged;
  final double newQuantity;
  final PackageUnit unit;
  final ReceivingSource sourceEntity;
  final String? fromSlotCode;
  final String? toSlotCode;
  final String? notes;
  final String performedByName;
  final DateTime createdAt;

  const SystemMovementEntity({
    required this.id,
    required this.palletId,
    required this.movementType,
    required this.itemName,
    required this.previousQuantity,
    required this.quantityChanged,
    required this.newQuantity,
    required this.unit,
    required this.sourceEntity,
    this.fromSlotCode,
    this.toSlotCode,
    this.notes,
    required this.performedByName,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        palletId,
        movementType,
        itemName,
        quantityChanged,
        createdAt,
      ];
}

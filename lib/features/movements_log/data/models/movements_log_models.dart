import '../../../../core/pagination/paged_result.dart';
import '../../../receiving/domain/entities/receiving_entities.dart';
import '../../domain/entities/movements_log_entities.dart';

typedef MoveJsonMap = Map<String, dynamic>;

class SystemMovementModel extends SystemMovementEntity {
  const SystemMovementModel({
    required super.id,
    required super.palletId,
    super.palletReference,
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
    final profile = json['profiles'] is Map
        ? MoveJsonMap.from(json['profiles'] as Map)
        : null;
    final actorName =
        json['performed_by_name']?.toString() ??
        profile?['full_name']?.toString() ??
        'مستخدم النظام';

    return SystemMovementModel(
      id: json['id']?.toString() ?? '',
      palletId: json['pallet_id']?.toString() ?? '',
      palletReference: json['pallet_reference']?.toString() ?? '—',
      movementType: MovementActionType.fromDb(
        json['movement_type']?.toString() ?? 'receive_new',
      ),
      itemName: json['item_name']?.toString() ?? '',
      previousQuantity: (json['previous_quantity'] as num?)?.toDouble() ?? 0.0,
      quantityChanged: (json['quantity_changed'] as num?)?.toDouble() ?? 0.0,
      newQuantity: (json['new_quantity'] as num?)?.toDouble() ?? 0.0,
      unit: PackageUnit.fromDb(json['unit']?.toString() ?? 'carton'),
      sourceEntity: ReceivingSource.fromDb(
        json['source_entity']?.toString() ?? 'production',
      ),
      fromSlotCode: json['from_slot_code'] as String?,
      toSlotCode: json['to_slot_code'] as String?,
      notes: json['notes'] as String?,
      performedByName: actorName,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

class MovementsLogPageMapper {
  const MovementsLogPageMapper._();

  static MovementsLogPageEntity fromRpcJson(MoveJsonMap json) {
    final paged = PagedResult<SystemMovementEntity>.fromRpcJson(
      json,
      SystemMovementModel.fromJson,
    );

    final summaryMap = json['summary'] is Map
        ? MoveJsonMap.from(json['summary'] as Map)
        : const <String, dynamic>{};

    final summary = MovementsLogSummaryEntity(
      totalMovements:
          (summaryMap['total_movements'] as num?)?.toInt() ?? paged.totalCount,
      todayMovements: (summaryMap['today_movements'] as num?)?.toInt() ?? 0,
    );

    return MovementsLogPageEntity(page: paged, summary: summary);
  }
}
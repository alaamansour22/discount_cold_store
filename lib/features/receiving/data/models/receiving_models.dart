import '../../domain/entities/receiving_entities.dart';
import '../../../../core/pagination/paged_result.dart';
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

  factory ReceivingMovementModel.fromJson(ReceivingJsonMap json) {
    final profile = json['profiles'] is Map
        ? ReceivingJsonMap.from(json['profiles'] as Map)
        : null;
    final pallet = json['pallets'] is Map
        ? ReceivingJsonMap.from(json['pallets'] as Map)
        : null;
    return ReceivingMovementModel(
      id: json['id'] as String,
      palletId: json['pallet_id'] as String,
      palletReference: pallet?['pallet_reference'] as String?,
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

class ReceiptsHistoryModelMapper {
  const ReceiptsHistoryModelMapper._();

  static ReceiptsHistoryPageEntity pageFromRpcJson(ReceivingJsonMap json) {
    final paged = PagedResult<ReceiptOperationEntity>.fromRpcJson(
      json,
      _operationFromJson,
    );

    final summaryMap = json['summary'] is Map
        ? ReceivingJsonMap.from(json['summary'] as Map)
        : const <String, dynamic>{};

    final summary = ReceiptsHistorySummaryEntity(
      totalOperations: (summaryMap['total_operations'] as num?)?.toInt() ?? 0,
      singleCount: (summaryMap['single_count'] as num?)?.toInt() ?? 0,
      mixedCount: (summaryMap['mixed_count'] as num?)?.toInt() ?? 0,
      addItemCount: (summaryMap['add_item_count'] as num?)?.toInt() ?? 0,
      totalItemLines: (summaryMap['total_item_lines'] as num?)?.toInt() ?? 0,
      totalsByUnitSummary:
          (summaryMap['totals_by_unit_summary'] as String?) ?? '0',
    );

    return ReceiptsHistoryPageEntity(page: paged, summary: summary);
  }

  static ReceiptOperationEntity _operationFromJson(ReceivingJsonMap map) {
    final rawItems = (map['items'] as List?) ?? const [];
    final items = rawItems.map((raw) {
      final itemMap = ReceivingJsonMap.from(raw as Map);
      return ReceiptOperationItemEntity(
        id: itemMap['id']?.toString() ?? '',
        itemName: itemMap['item_name']?.toString() ?? '',
        quantity: (itemMap['quantity'] as num?)?.toDouble() ?? 0.0,
        unit: PackageUnit.fromDb(itemMap['unit']?.toString() ?? 'carton'),
        sourceEntity: ReceivingSource.fromDb(
          itemMap['source_entity']?.toString() ?? 'production',
        ),
        notes: itemMap['notes'] as String?,
      );
    }).toList();

    return ReceiptOperationEntity(
      operationKey: map['operation_key']?.toString() ?? '',
      palletId: map['pallet_id']?.toString() ?? '',
      palletReference: map['pallet_reference']?.toString() ?? '—',
      movementType: MovementActionType.fromDb(
        map['movement_type']?.toString() ?? 'receive_new',
      ),
      operationKind: ReceiptOperationKind.fromDb(
        map['operation_kind']?.toString(),
      ),
      itemsCount: (map['items_count'] as num?)?.toInt() ?? items.length,
      totalSummary: map['total_summary']?.toString() ?? '0',
      slotCode: map['slot_code']?.toString() ?? '—',
      sourceEntity: ReceivingSource.fromDb(
        map['source_entity']?.toString() ?? 'production',
      ),
      performedByName: map['performed_by_name']?.toString() ?? 'مستخدم النظام',
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      items: items,
    );
  }
}
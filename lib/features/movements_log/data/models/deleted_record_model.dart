import '../../../receiving/domain/entities/receiving_entities.dart';
import '../../domain/entities/deleted_record_entity.dart';

class DeletedRecordModel extends DeletedRecordEntity {
  const DeletedRecordModel({
    required super.id,
    required super.actionKind,
    required super.palletReference,
    required super.slotCode,
    super.sourceEntity,
    required super.reason,
    required super.deletedByName,
    required super.deletedAt,
    required super.slotFreed,
    required super.items,
  });

  factory DeletedRecordModel.fromJson(Map<String, dynamic> json) {
    final actionType = json['action_type']?.toString() ?? '';
    final kind = DeletedActionKind.fromDb(actionType);
    final details = json['details'] is Map
        ? Map<String, dynamic>.from(json['details'] as Map)
        : <String, dynamic>{};
    final profile = json['profiles'] is Map
        ? Map<String, dynamic>.from(json['profiles'] as Map)
        : null;

    final items = <DeletedItemSnapshot>[];
    if (kind == DeletedActionKind.fullPallet) {
      final rawItems = details['deleted_items'];
      if (rawItems is List) {
        for (final entry in rawItems) {
          if (entry is Map) {
            final map = Map<String, dynamic>.from(entry);
            items.add(_parseSnapshot(map));
          }
        }
      }
    } else if (details['item_name'] != null) {
      items.add(_parseSnapshot(details));
    }

    final rawSource = json['source_entity']?.toString();
    final source = rawSource != null && rawSource.isNotEmpty
        ? ReceivingSource.fromDb(rawSource)
        : null;

    return DeletedRecordModel(
      id: json['id']?.toString() ?? '',
      actionKind: kind,
      palletReference: details['pallet_reference']?.toString() ?? '—',
      slotCode:
          (json['slot_code']?.toString() ?? details['slot_code']?.toString()) ??
          '—',
      sourceEntity: source,
      reason: details['reason']?.toString() ?? '—',
      deletedByName: profile?['full_name']?.toString() ?? 'مستخدم النظام',
      deletedAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      slotFreed: kind == DeletedActionKind.fullPallet
          ? true
          : (details['slot_freed'] as bool? ?? false),
      items: items,
    );
  }

  static DeletedItemSnapshot _parseSnapshot(Map<String, dynamic> map) {
    return DeletedItemSnapshot(
      itemName: map['item_name']?.toString() ?? 'صنف غير مسمى',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      unit: PackageUnit.fromDb(map['unit']?.toString() ?? 'carton'),
      productionDate: DateTime.tryParse(
        map['production_date']?.toString() ?? '',
      ),
      expiryDate: DateTime.tryParse(map['expiry_date']?.toString() ?? ''),
    );
  }
}
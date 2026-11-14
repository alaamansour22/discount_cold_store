import '../../domain/entities/condemnations_entities.dart';

typedef CondemnJsonMap = Map<String, dynamic>;

class CondemnationModelMapper {
  const CondemnationModelMapper._();

  static String unitToArabic(String dbUnit) {
    switch (dbUnit) {
      case 'shrink':
        return 'شرنك';
      case 'gallon':
        return 'جالون';
      default:
        return 'كرتونة';
    }
  }

  static String sourceToArabic(String dbSource) {
    if (dbSource == 'quality_inspection') return 'نتيجة فحص الجودة';
    return 'الإنتاج';
  }

  static CondemnationAlertItemEntity alertFromViewJson(CondemnJsonMap json) {
    final unitDb = json['unit'] as String? ?? 'carton';
    final sourceDb = json['source_entity'] as String? ?? 'production';
    return CondemnationAlertItemEntity(
      palletItemId: json['pallet_item_id'] as String,
      palletId: json['pallet_id'] as String,
      palletReference: json['pallet_reference'] as String? ?? '',
      itemName: json['item_name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unitDb: unitDb,
      unitArLabel: unitToArabic(unitDb),
      productionDate: DateTime.parse(json['production_date'] as String),
      expiryDate: DateTime.parse(json['expiry_date'] as String),
      sourceDb: sourceDb,
      sourceArLabel: sourceToArabic(sourceDb),
      slotCode: json['slot_code'] as String? ?? '-',
      receivedByName: json['received_by_name'] as String? ?? 'مستخدم النظام',
      daysUntilExpiry: (json['days_until_expiry'] as num?)?.toInt() ?? 0,
      globalThresholdDays:
          (json['condemnation_threshold_days'] as num?)?.toInt() ?? 7,
      healthStatus: json['condemnation_health_status'] as String? ?? 'healthy',
    );
  }

  static CondemnationHistoryRecordEntity historyFromJson(CondemnJsonMap json) {
    final profile = json['profiles'] != null
        ? CondemnJsonMap.from(json['profiles'] as Map)
        : null;
    final unitDb = json['unit'] as String? ?? 'carton';
    final sourceDb = json['source_entity'] as String? ?? 'production';
    return CondemnationHistoryRecordEntity(
      id: json['id'] as String,
      palletId: json['pallet_id'] as String,
      palletItemId: json['pallet_item_id'] as String?,
      itemName: json['item_name'] as String? ?? '',
      condemnedQuantity:
          (json['condemned_quantity'] as num?)?.toDouble() ?? 0.0,
      unitDb: unitDb,
      unitArLabel: unitToArabic(unitDb),
      productionDate: DateTime.parse(json['production_date'] as String),
      expiryDate: DateTime.parse(json['expiry_date'] as String),
      sourceDb: sourceDb,
      sourceArLabel: sourceToArabic(sourceDb),
      slotCode: json['slot_code'] as String? ?? '-',
      daysRemainingAtCondemnation:
          (json['days_remaining_at_condemnation'] as num?)?.toInt() ?? 0,
      thresholdAppliedDays:
          (json['threshold_applied_days'] as num?)?.toInt() ?? 7,
      reason: json['reason'] as String? ?? 'إعدام صلاحية',
      approvedByName: profile?['full_name'] as String? ?? 'مستخدم النظام',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

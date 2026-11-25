import '../../../../core/pagination/paged_result.dart';
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
    if (dbSource == 'quality_inspection') {
      return 'نتيجة فحص الجودة';
    }
    return 'الإنتاج';
  }

  static CondemnationAlertItemEntity alertFromViewJson(CondemnJsonMap json) {
    final unitDb = json['unit']?.toString() ?? 'carton';
    final sourceDb = json['source_entity']?.toString() ?? 'production';
    return CondemnationAlertItemEntity(
      palletItemId: json['pallet_item_id']?.toString() ?? '',
      palletId: json['pallet_id']?.toString() ?? '',
      palletReference: json['pallet_reference']?.toString() ?? '—',
      itemName: json['item_name']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unitDb: unitDb,
      unitArLabel: unitToArabic(unitDb),
      productionDate:
          DateTime.tryParse(json['production_date']?.toString() ?? '') ??
          DateTime.now(),
      expiryDate:
          DateTime.tryParse(json['expiry_date']?.toString() ?? '') ??
          DateTime.now(),
      sourceDb: sourceDb,
      sourceArLabel: sourceToArabic(sourceDb),
      slotCode: json['slot_code']?.toString() ?? '—',
      receivedByName: json['received_by_name']?.toString() ?? 'مستخدم النظام',
      daysUntilExpiry: (json['days_until_expiry'] as num?)?.toInt() ?? 0,
      globalThresholdDays:
          (json['condemnation_threshold_days'] as num?)?.toInt() ?? 7,
      healthStatus:
          json['condemnation_health_status']?.toString() ?? 'healthy',
    );
  }

  static CondemnationHistoryRecordEntity historyFromJson(CondemnJsonMap json) {
    final profile = json['profiles'] is Map
        ? CondemnJsonMap.from(json['profiles'] as Map)
        : null;
    final unitDb = json['unit']?.toString() ?? 'carton';
    final sourceDb = json['source_entity']?.toString() ?? 'production';
    final approverName =
        json['approved_by_name']?.toString() ??
        profile?['full_name']?.toString() ??
        'مستخدم النظام';

    return CondemnationHistoryRecordEntity(
      id: json['id']?.toString() ?? '',
      palletId: json['pallet_id']?.toString() ?? '',
      palletItemId: json['pallet_item_id'] as String?,
      palletReference: json['pallet_reference']?.toString() ?? '—',
      itemName: json['item_name']?.toString() ?? '',
      condemnedQuantity:
          (json['condemned_quantity'] as num?)?.toDouble() ?? 0.0,
      unitDb: unitDb,
      unitArLabel: unitToArabic(unitDb),
      productionDate:
          DateTime.tryParse(json['production_date']?.toString() ?? '') ??
          DateTime.now(),
      expiryDate:
          DateTime.tryParse(json['expiry_date']?.toString() ?? '') ??
          DateTime.now(),
      sourceDb: sourceDb,
      sourceArLabel: sourceToArabic(sourceDb),
      slotCode: json['slot_code']?.toString() ?? '—',
      daysRemainingAtCondemnation:
          (json['days_remaining_at_condemnation'] as num?)?.toInt() ?? 0,
      thresholdAppliedDays:
          (json['threshold_applied_days'] as num?)?.toInt() ?? 7,
      reason: json['reason']?.toString() ?? 'إعدام صلاحية',
      approvedByName: approverName,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  static CondemnationAlertsPageEntity alertsPageFromRpcJson(
    CondemnJsonMap json,
  ) {
    final paged = PagedResult<CondemnationAlertItemEntity>.fromRpcJson(
      json,
      alertFromViewJson,
    );

    final summaryMap = json['summary'] is Map
        ? CondemnJsonMap.from(json['summary'] as Map)
        : const <String, dynamic>{};

    final summary = CondemnationAlertsSummaryEntity(
      globalThresholdDays:
          (summaryMap['global_threshold_days'] as num?)?.toInt() ?? 7,
      userCustomAlertDays:
          (summaryMap['user_custom_alert_days'] as num?)?.toInt() ?? 7,
      totalAlerts:
          (summaryMap['total_alerts'] as num?)?.toInt() ?? paged.totalCount,
      expiredCount: (summaryMap['expired_count'] as num?)?.toInt() ?? 0,
      dueSoonCount: (summaryMap['due_soon_count'] as num?)?.toInt() ?? 0,
    );

    return CondemnationAlertsPageEntity(page: paged, summary: summary);
  }

  static CondemnationHistoryPageEntity historyPageFromRpcJson(
    CondemnJsonMap json,
  ) {
    final paged = PagedResult<CondemnationHistoryRecordEntity>.fromRpcJson(
      json,
      historyFromJson,
    );

    final summaryMap = json['summary'] is Map
        ? CondemnJsonMap.from(json['summary'] as Map)
        : const <String, dynamic>{};

    final summary = CondemnationHistorySummaryEntity(
      totalRecords:
          (summaryMap['total_records'] as num?)?.toInt() ?? paged.totalCount,
      totalQuantity:
          (summaryMap['total_quantity'] as num?)?.toDouble() ?? 0.0,
      totalsByUnitSummary:
          summaryMap['totals_by_unit_summary']?.toString() ?? '0',
    );

    return CondemnationHistoryPageEntity(page: paged, summary: summary);
  }
}
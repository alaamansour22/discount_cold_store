import '../../../../core/pagination/paged_result.dart';
import '../../domain/entities/rack_transfer_entities.dart';

typedef TransferJsonMap = Map<String, dynamic>;

class TransferModelMapper {
  const TransferModelMapper._();

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

  static TransferPalletItemSummary itemFromViewJson(TransferJsonMap json) {
    return TransferPalletItemSummary(
      itemName: json['item_name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unitArLabel: unitToArabic(json['unit'] as String? ?? 'carton'),
      sourceArLabel: sourceToArabic(
        json['source_entity'] as String? ?? 'production',
      ),
      daysUntilExpiry: (json['days_until_expiry'] as num?)?.toInt() ?? 0,
    );
  }

  static RackTransferHistoryEntity historyFromJson(TransferJsonMap json) {
    final profile = json['profiles'] is Map
        ? TransferJsonMap.from(json['profiles'] as Map)
        : null;
    final actorName =
        json['performed_by_name']?.toString() ??
        profile?['full_name']?.toString() ??
        'مستخدم النظام';
    final rawQty = json['quantity'] ?? json['new_quantity'];

    return RackTransferHistoryEntity(
      id: json['id']?.toString() ?? '',
      palletId: json['pallet_id']?.toString() ?? '',
      palletReference: json['pallet_reference']?.toString() ?? '—',
      itemName: json['item_name']?.toString() ?? '',
      quantity: (rawQty as num?)?.toDouble() ?? 0.0,
      unitArLabel: unitToArabic(json['unit']?.toString() ?? 'carton'),
      fromSlotCode: json['from_slot_code']?.toString() ?? '—',
      toSlotCode: json['to_slot_code']?.toString() ?? '—',
      notes: json['notes']?.toString() ?? 'تحويل بين الراكات',
      performedByName: actorName,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  static RackTransferHistoryPageEntity historyPageFromRpcJson(
    TransferJsonMap json,
  ) {
    final paged = PagedResult<RackTransferHistoryEntity>.fromRpcJson(
      json,
      historyFromJson,
    );

    final summaryMap = json['summary'] is Map
        ? TransferJsonMap.from(json['summary'] as Map)
        : const <String, dynamic>{};

    final summary = RackTransferHistorySummaryEntity(
      totalTransfers:
          (summaryMap['total_transfers'] as num?)?.toInt() ?? paged.totalCount,
    );

    return RackTransferHistoryPageEntity(page: paged, summary: summary);
  }
}
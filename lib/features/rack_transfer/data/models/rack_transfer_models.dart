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
    if (dbSource == 'quality_inspection') return 'نتيجة فحص الجودة';
    return 'الإنتاج';
  }

  static TransferPalletItemSummary itemFromViewJson(TransferJsonMap json) {
    return TransferPalletItemSummary(
      itemName: json['item_name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unitArLabel: unitToArabic(json['unit'] as String? ?? 'carton'),
      sourceArLabel: sourceToArabic(json['source_entity'] as String? ?? 'production'),
      daysUntilExpiry: (json['days_until_expiry'] as num?)?.toInt() ?? 0,
    );
  }

  static RackTransferHistoryEntity historyFromJson(TransferJsonMap json) {
    final profile = json['profiles'] != null
        ? TransferJsonMap.from(json['profiles'] as Map)
        : null;
    return RackTransferHistoryEntity(
      id: json['id'] as String,
      palletId: json['pallet_id'] as String,
      itemName: json['item_name'] as String? ?? '',
      quantity: (json['new_quantity'] as num?)?.toDouble() ?? 0.0,
      unitArLabel: unitToArabic(json['unit'] as String? ?? 'carton'),
      fromSlotCode: json['from_slot_code'] as String? ?? '-',
      toSlotCode: json['to_slot_code'] as String? ?? '-',
      notes: json['notes'] as String? ?? 'تحويل بين الراكات',
      performedByName: profile?['full_name'] as String? ?? 'مستخدم النظام',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
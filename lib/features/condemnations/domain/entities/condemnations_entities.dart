import 'package:equatable/equatable.dart';

/// كيان الصنف النشط المستحق أو المقترب من الإعدام (من View: v_active_pallet_items)
class CondemnationAlertItemEntity extends Equatable {
  final String palletItemId;
  final String palletId;
  final String palletReference;
  final String itemName;
  final double quantity;
  final String unitDb;
  final String unitArLabel;
  final DateTime productionDate;
  final DateTime expiryDate;
  final String sourceDb;
  final String sourceArLabel;
  final String slotCode;
  final String receivedByName;
  final int daysUntilExpiry;
  final int globalThresholdDays;
  final String healthStatus; // 'expired' | 'due_for_condemnation' | 'healthy'

  const CondemnationAlertItemEntity({
    required this.palletItemId,
    required this.palletId,
    required this.palletReference,
    required this.itemName,
    required this.quantity,
    required this.unitDb,
    required this.unitArLabel,
    required this.productionDate,
    required this.expiryDate,
    required this.sourceDb,
    required this.sourceArLabel,
    required this.slotCode,
    required this.receivedByName,
    required this.daysUntilExpiry,
    required this.globalThresholdDays,
    required this.healthStatus,
  });

  bool get isExpired => daysUntilExpiry <= 0 || healthStatus == 'expired';

  @override
  List<Object?> get props => [
    palletItemId,
    palletId,
    itemName,
    quantity,
    expiryDate,
    slotCode,
    daysUntilExpiry,
    healthStatus,
  ];
}

/// كيان سجل الإعدام الفعلي المعتمد (من جدول: condemnation_records)
class CondemnationHistoryRecordEntity extends Equatable {
  final String id;
  final String palletId;
  final String? palletItemId;
  final String itemName;
  final double condemnedQuantity;
  final String unitDb;
  final String unitArLabel;
  final DateTime productionDate;
  final DateTime expiryDate;
  final String sourceDb;
  final String sourceArLabel;
  final String slotCode;
  final int daysRemainingAtCondemnation;
  final int thresholdAppliedDays;
  final String reason;
  final String approvedByName;
  final DateTime createdAt;

  const CondemnationHistoryRecordEntity({
    required this.id,
    required this.palletId,
    this.palletItemId,
    required this.itemName,
    required this.condemnedQuantity,
    required this.unitDb,
    required this.unitArLabel,
    required this.productionDate,
    required this.expiryDate,
    required this.sourceDb,
    required this.sourceArLabel,
    required this.slotCode,
    required this.daysRemainingAtCondemnation,
    required this.thresholdAppliedDays,
    required this.reason,
    required this.approvedByName,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    palletId,
    itemName,
    condemnedQuantity,
    slotCode,
    createdAt,
  ];
}

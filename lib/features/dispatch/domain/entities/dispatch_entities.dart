import 'package:equatable/equatable.dart';

import '../../../receiving/domain/entities/receiving_entities.dart';

class DispatchDraftLine extends Equatable {
  final ReceivingPalletItemEntity item;
  final double quantity;
  final String method;
  const DispatchDraftLine({
    required this.item,
    required this.quantity,
    required this.method,
  });
  Map<String, dynamic> toJson() => {
    'pallet_id': item.palletId,
    'pallet_item_id': item.palletItemId,
    'quantity': quantity,
    'dispatch_method': method,
  };
  @override
  List<Object?> get props => [item, quantity, method];
}

class DispatchDocumentEntity extends Equatable {
  final String id, number, status, destination;
  final List<String> palletReferences;
  final DateTime createdAt;
  final String? reversalReason;
  const DispatchDocumentEntity({
    required this.id,
    required this.number,
    required this.status,
    required this.destination,
    required this.createdAt,
    this.reversalReason,
    this.palletReferences = const [],
  });
  factory DispatchDocumentEntity.fromJson(Map<String, dynamic> j) =>
      DispatchDocumentEntity(
        id: j['id'] as String,
        number: j['document_number'] as String? ?? '',
        status: j['status'] as String? ?? '',
        destination: j['destination'] as String? ?? 'employee_sales_outlet',
        createdAt:
            DateTime.tryParse(j['created_at']?.toString() ?? '')?.toLocal() ??
            DateTime.now(),
        reversalReason: j['reversal_reason'] as String?,
        palletReferences: (j['pallet_references'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
  @override
  List<Object?> get props => [
    id,
    number,
    palletReferences,
    status,
    destination,
    createdAt,
    reversalReason,
  ];
}

class DispatchDocumentLineEntity extends Equatable {
  final String palletReference, slotCode, itemName, unit, method;
  final double quantity;
  const DispatchDocumentLineEntity({
    required this.palletReference,
    required this.slotCode,
    required this.itemName,
    required this.unit,
    required this.method,
    required this.quantity,
  });
  @override
  List<Object?> get props => [
    palletReference,
    slotCode,
    itemName,
    unit,
    method,
    quantity,
  ];
}

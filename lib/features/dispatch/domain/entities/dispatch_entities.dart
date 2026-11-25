import 'package:equatable/equatable.dart';

import '../../../../core/pagination/paged_result.dart';
import '../../../receiving/domain/entities/receiving_entities.dart';


typedef DispatchJsonMap = Map<String, dynamic>;
typedef DispatchSlotAssignment = Map<String, String>;

/// بند مسودة صرف قبل اعتماد المستند
class DispatchDraftLine extends Equatable {
  final ReceivingPalletItemEntity item;
  final double quantity;
  final String method; // 'full_pallet' | 'custom_quantity'
  final bool palletFullySelected;

  const DispatchDraftLine({
    required this.item,
    required this.quantity,
    required this.method,
    this.palletFullySelected = false,
  });

  Map<String, dynamic> toJson() => {
    'pallet_id': item.palletId,
    'pallet_item_id': item.palletItemId,
    'quantity': quantity,
    'dispatch_method': method,
  };

  @override
  List<Object?> get props => [item, quantity, method, palletFullySelected];
}

/// بالتة متاحة للصرف (مجمّعة ومحسوبة إجمالياتها بالكامل داخل PostgreSQL)
class DispatchAvailablePalletEntity extends Equatable {
  final String palletId;
  final String palletReference;
  final String slotId;
  final String slotCode;
  final String zoneCode;
  final bool isMixed;
  final int itemsCount;
  final int minDaysUntilExpiry;
  final bool hasCondemnationAlert;
  final String totalSummary;
  final List<ReceivingPalletItemEntity> items;

  const DispatchAvailablePalletEntity({
    required this.palletId,
    required this.palletReference,
    required this.slotId,
    required this.slotCode,
    required this.zoneCode,
    required this.isMixed,
    required this.itemsCount,
    required this.minDaysUntilExpiry,
    required this.hasCondemnationAlert,
    required this.totalSummary,
    required this.items,
  });

  @override
  List<Object?> get props => [
    palletId,
    palletReference,
    slotId,
    slotCode,
    zoneCode,
    isMixed,
    itemsCount,
    minDaysUntilExpiry,
    hasCondemnationAlert,
    totalSummary,
    items,
  ];
}

class DispatchAvailablePalletsFilter extends Equatable {
  final int page;
  final int pageSize;
  final String search;
  final String? zone; // 'C2' | 'C3' | null
  final String? palletKind; // 'single' | 'mixed' | null

  const DispatchAvailablePalletsFilter({
    this.page = 1,
    this.pageSize = 20,
    this.search = '',
    this.zone,
    this.palletKind,
  });

  bool get hasActiveFilters =>
      search.trim().isNotEmpty || zone != null || palletKind != null;

  DispatchAvailablePalletsFilter copyWith({
    int? page,
    int? pageSize,
    String? search,
    String? zone,
    bool clearZone = false,
    String? palletKind,
    bool clearPalletKind = false,
  }) {
    return DispatchAvailablePalletsFilter(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      search: search ?? this.search,
      zone: clearZone ? null : (zone ?? this.zone),
      palletKind: clearPalletKind ? null : (palletKind ?? this.palletKind),
    );
  }

  @override
  List<Object?> get props => [page, pageSize, search, zone, palletKind];
}

class DispatchAvailablePalletsSummaryEntity extends Equatable {
  final int totalPallets;
  final int singleCount;
  final int mixedCount;
  final int totalItemLines;
  final String totalsByUnitSummary;

  const DispatchAvailablePalletsSummaryEntity({
    this.totalPallets = 0,
    this.singleCount = 0,
    this.mixedCount = 0,
    this.totalItemLines = 0,
    this.totalsByUnitSummary = '0',
  });

  @override
  List<Object?> get props => [
    totalPallets,
    singleCount,
    mixedCount,
    totalItemLines,
    totalsByUnitSummary,
  ];
}

class DispatchAvailablePalletsPageEntity extends Equatable {
  final PagedResult<DispatchAvailablePalletEntity> page;
  final DispatchAvailablePalletsSummaryEntity summary;

  const DispatchAvailablePalletsPageEntity({
    required this.page,
    required this.summary,
  });

  const DispatchAvailablePalletsPageEntity.empty()
    : page = const PagedResult.empty(),
      summary = const DispatchAvailablePalletsSummaryEntity();

  @override
  List<Object?> get props => [page, summary];
}

/// كيان مستند الصرف في السجل (مُثرى من PostgreSQL بالبالتات والإجماليات)
class DispatchDocumentEntity extends Equatable {
  final String id;
  final String number;
  final String status; // 'completed' | 'reversed'
  final String destination;
  final DateTime createdAt;
  final String createdByName;
  final DateTime? reversedAt;
  final String? reversedByName;
  final String? reversalReason;
  final int palletCount;
  final int itemLineCount;
  final double totalDispatchedQuantity;
  final String totalsByUnitSummary;
  final List<String> palletReferences;

  const DispatchDocumentEntity({
    required this.id,
    required this.number,
    required this.status,
    required this.destination,
    required this.createdAt,
    this.createdByName = 'مستخدم النظام',
    this.reversedAt,
    this.reversedByName,
    this.reversalReason,
    this.palletCount = 0,
    this.itemLineCount = 0,
    this.totalDispatchedQuantity = 0,
    this.totalsByUnitSummary = '0',
    this.palletReferences = const [],
  });

  bool get isReversed => status == 'reversed';

  factory DispatchDocumentEntity.fromJson(Map<String, dynamic> j) =>
      DispatchDocumentEntity(
        id: j['id']?.toString() ?? '',
        number: j['document_number']?.toString() ?? '',
        status: j['status']?.toString() ?? 'completed',
        destination: j['destination']?.toString() ?? 'employee_sales_outlet',
        createdAt:
            DateTime.tryParse(j['created_at']?.toString() ?? '')?.toLocal() ??
            DateTime.now(),
        createdByName: j['created_by_name']?.toString() ?? 'مستخدم النظام',
        reversedAt: DateTime.tryParse(
          j['reversed_at']?.toString() ?? '',
        )?.toLocal(),
        reversedByName: j['reversed_by_name'] as String?,
        reversalReason: j['reversal_reason'] as String?,
        palletCount: (j['pallet_count'] as num?)?.toInt() ?? 0,
        itemLineCount: (j['item_line_count'] as num?)?.toInt() ?? 0,
        totalDispatchedQuantity:
            (j['total_dispatched_quantity'] as num?)?.toDouble() ?? 0,
        totalsByUnitSummary: j['totals_by_unit_summary']?.toString() ?? '0',
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
    createdByName,
    reversedAt,
    reversedByName,
    reversalReason,
    palletCount,
    itemLineCount,
    totalDispatchedQuantity,
    totalsByUnitSummary,
  ];
}

class DispatchDocumentsFilter extends Equatable {
  final int page;
  final int pageSize;
  final String search;
  final String? status; // 'completed' | 'reversed' | null
  final DateTime? fromDate;
  final DateTime? toDate;

  const DispatchDocumentsFilter({
    this.page = 1,
    this.pageSize = 20,
    this.search = '',
    this.status,
    this.fromDate,
    this.toDate,
  });

  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      status != null ||
      fromDate != null ||
      toDate != null;

  DispatchDocumentsFilter copyWith({
    int? page,
    int? pageSize,
    String? search,
    String? status,
    bool clearStatus = false,
    DateTime? fromDate,
    bool clearFromDate = false,
    DateTime? toDate,
    bool clearToDate = false,
  }) {
    return DispatchDocumentsFilter(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      search: search ?? this.search,
      status: clearStatus ? null : (status ?? this.status),
      fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
    );
  }

  @override
  List<Object?> get props => [page, pageSize, search, status, fromDate, toDate];
}

class DispatchDocumentsSummaryEntity extends Equatable {
  final int totalDocuments;
  final int completedCount;
  final int reversedCount;
  final double netDispatchedQuantity;
  final bool currentUserCanReverse;

  const DispatchDocumentsSummaryEntity({
    this.totalDocuments = 0,
    this.completedCount = 0,
    this.reversedCount = 0,
    this.netDispatchedQuantity = 0,
    this.currentUserCanReverse = false,
  });

  @override
  List<Object?> get props => [
    totalDocuments,
    completedCount,
    reversedCount,
    netDispatchedQuantity,
    currentUserCanReverse,
  ];
}

class DispatchDocumentsPageEntity extends Equatable {
  final PagedResult<DispatchDocumentEntity> page;
  final DispatchDocumentsSummaryEntity summary;

  const DispatchDocumentsPageEntity({
    required this.page,
    required this.summary,
  });

  const DispatchDocumentsPageEntity.empty()
    : page = const PagedResult.empty(),
      summary = const DispatchDocumentsSummaryEntity();

  @override
  List<Object?> get props => [page, summary];
}

class DispatchDocumentLineEntity extends Equatable {
  final String documentItemId;
  final String palletId;
  final String palletReference;
  final String slotCode;
  final String? returnedSlotCode;
  final String itemName;
  final String unit;
  final String method;
  final double quantity;

  const DispatchDocumentLineEntity({
    this.documentItemId = '',
    this.palletId = '',
    required this.palletReference,
    required this.slotCode,
    this.returnedSlotCode,
    required this.itemName,
    required this.unit,
    required this.method,
    required this.quantity,
  });

  factory DispatchDocumentLineEntity.fromRpcJson(Map<String, dynamic> j) =>
      DispatchDocumentLineEntity(
        documentItemId: j['document_item_id']?.toString() ?? '',
        palletId: j['pallet_id']?.toString() ?? '',
        palletReference: j['pallet_reference']?.toString() ?? '—',
        slotCode: j['slot_code']?.toString() ?? '—',
        returnedSlotCode: j['returned_slot_code'] as String?,
        itemName: j['item_name']?.toString() ?? '',
        unit: j['unit']?.toString() ?? 'carton',
        method: j['dispatch_method']?.toString() ?? 'custom_quantity',
        quantity: (j['quantity_dispatched'] as num?)?.toDouble() ?? 0,
      );

  @override
  List<Object?> get props => [
    documentItemId,
    palletId,
    palletReference,
    slotCode,
    returnedSlotCode,
    itemName,
    unit,
    method,
    quantity,
  ];
}

/// بيانات البالتة التي تحتاج لموقع بديل عند عكس مستند صرف
class ReversalPalletSlotNeedEntity extends Equatable {
  final String palletId;
  final String palletReference;
  final String originalSlotCode;

  const ReversalPalletSlotNeedEntity({
    required this.palletId,
    required this.palletReference,
    required this.originalSlotCode,
  });

  factory ReversalPalletSlotNeedEntity.fromJson(Map<String, dynamic> j) =>
      ReversalPalletSlotNeedEntity(
        palletId: j['pallet_id']?.toString() ?? '',
        palletReference: j['pallet_reference']?.toString() ?? '—',
        originalSlotCode: j['original_slot_code']?.toString() ?? '—',
      );

  @override
  List<Object?> get props => [palletId, palletReference, originalSlotCode];
}

class ReversalEmptySlotOptionEntity extends Equatable {
  final String slotId;
  final String slotCode;
  final String zoneCode;

  const ReversalEmptySlotOptionEntity({
    required this.slotId,
    required this.slotCode,
    required this.zoneCode,
  });

  factory ReversalEmptySlotOptionEntity.fromJson(Map<String, dynamic> j) =>
      ReversalEmptySlotOptionEntity(
        slotId: j['slot_id']?.toString() ?? '',
        slotCode: j['slot_code']?.toString() ?? '',
        zoneCode: j['zone_code']?.toString() ?? '',
      );

  @override
  List<Object?> get props => [slotId, slotCode, zoneCode];
}

class DispatchReversalReadinessEntity extends Equatable {
  final bool canReverse;
  final String documentId;
  final String documentNumber;
  final String documentStatus;
  final bool requiresAlternativeSlots;
  final List<ReversalPalletSlotNeedEntity> palletsNeedingAlternativeSlot;
  final List<ReversalEmptySlotOptionEntity> availableEmptySlots;

  const DispatchReversalReadinessEntity({
    required this.canReverse,
    required this.documentId,
    required this.documentNumber,
    required this.documentStatus,
    required this.requiresAlternativeSlots,
    required this.palletsNeedingAlternativeSlot,
    required this.availableEmptySlots,
  });

  factory DispatchReversalReadinessEntity.fromJson(Map<String, dynamic> j) {
    final rawNeeds = j['pallets_needing_alternative_slot'] as List? ?? const [];
    final rawSlots = j['available_empty_slots'] as List? ?? const [];
    return DispatchReversalReadinessEntity(
      canReverse: j['can_reverse'] as bool? ?? false,
      documentId: j['document_id']?.toString() ?? '',
      documentNumber: j['document_number']?.toString() ?? '',
      documentStatus: j['document_status']?.toString() ?? '',
      requiresAlternativeSlots:
          j['requires_alternative_slots'] as bool? ?? false,
      palletsNeedingAlternativeSlot: rawNeeds
          .whereType()
          .map(
            (e) => ReversalPalletSlotNeedEntity.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
      availableEmptySlots: rawSlots
          .whereType()
          .map(
            (e) => ReversalEmptySlotOptionEntity.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
    canReverse,
    documentId,
    documentNumber,
    documentStatus,
    requiresAlternativeSlots,
    palletsNeedingAlternativeSlot,
    availableEmptySlots,
  ];
}
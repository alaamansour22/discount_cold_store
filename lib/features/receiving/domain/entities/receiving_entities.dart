import 'package:equatable/equatable.dart';
import '../../../../core/pagination/paged_result.dart';
/// وحدات القياس المعتمدة في ثلاجة مخفض (C)
enum PackageUnit {
  carton('carton', 'كرتونة'),
  shrink('shrink', 'شرنك'),
  gallon('gallon', 'جالون');

  final String dbValue;
  final String arLabel;
  const PackageUnit(this.dbValue, this.arLabel);

  static PackageUnit fromDb(String val) => PackageUnit.values.firstWhere(
    (e) => e.dbValue == val,
    orElse: () => PackageUnit.carton,
  );
}

/// جهات الاستلام المعتمدة (الإنتاج / نتيجة فحص الجودة)
enum ReceivingSource {
  production('production', 'الإنتاج'),
  qualityInspection('quality_inspection', 'نتيجة فحص الجودة');

  final String dbValue;
  final String arLabel;
  const ReceivingSource(this.dbValue, this.arLabel);

  static ReceivingSource fromDb(String val) =>
      ReceivingSource.values.firstWhere(
        (e) => e.dbValue == val,
        orElse: () => ReceivingSource.production,
      );
}

enum MovementActionType {
  receiveNew('receive_new', 'استلام بالتة جديدة'),
  addItemToPallet('add_item_to_pallet', 'تزويد صنف على بالتة'),
  adjustQuantity('adjust_quantity', 'تعديل كمية جرد'),
  dispatch('dispatch', 'صرف من الثلاجة'),
  dispatchReversal('dispatch_reversal', 'عكس مستند صرف'),
  condemn('condemn', 'إعدام'),
  relocate('relocate', 'تحويل بين الراكات');

  final String dbValue;
  final String arLabel;
  const MovementActionType(this.dbValue, this.arLabel);

  static MovementActionType fromDb(String val) =>
      MovementActionType.values.firstWhere(
        (e) => e.dbValue == val,
        orElse: () => MovementActionType.receiveNew,
      );
}

/// مسودة إدخال صنف (تُستخدم عند استلام بالتة موحدة أو ميكس، أو تزويد صنف على بالتة قائمة)
class PalletItemDraft {
  String itemName;
  double quantity;
  PackageUnit unit;
  DateTime productionDate;
  DateTime expiryDate;

  PalletItemDraft({
    this.itemName = '',
    this.quantity = 1,
    this.unit = PackageUnit.carton,
    DateTime? productionDate,
    DateTime? expiryDate,
  }) : productionDate = productionDate ?? DateTime.now(),
       expiryDate = expiryDate ?? DateTime.now().add(const Duration(days: 90));

  bool get isValid =>
      itemName.trim().isNotEmpty &&
      quantity > 0 &&
      expiryDate.isAfter(productionDate);

  Map<String, dynamic> toRpcJson() => {
    'item_name': itemName.trim(),
    'quantity': quantity,
    'unit': unit.dbValue,
    'production_date': productionDate.toIso8601String().split('T').first,
    'expiry_date': expiryDate.toIso8601String().split('T').first,
  };
}

/// كيان الصنف الفردي داخل البالتة (Detail Line)
class ReceivingPalletItemEntity extends Equatable {
  final String palletItemId;
  final String palletId;
  final String palletReference;
  final String itemName;
  final double quantity;
  final PackageUnit unit;
  final DateTime productionDate;
  final DateTime expiryDate;
  final ReceivingSource sourceEntity;
  final String slotId;
  final String slotCode;
  final String receivedByName;
  final DateTime receivedAt;
  final int daysUntilExpiry;
  final String healthStatus; // 'healthy' | 'due_for_condemnation' | 'expired'

  const ReceivingPalletItemEntity({
    required this.palletItemId,
    required this.palletId,
    required this.palletReference,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.productionDate,
    required this.expiryDate,
    required this.sourceEntity,
    required this.slotId,
    required this.slotCode,
    required this.receivedByName,
    required this.receivedAt,
    required this.daysUntilExpiry,
    required this.healthStatus,
  });

  bool get isExpired => healthStatus == 'expired' || daysUntilExpiry <= 0;
  bool get isDueForCondemnation =>
      healthStatus == 'due_for_condemnation' || isExpired;

  @override
  List<Object?> get props => [
    palletItemId,
    palletId,
    itemName,
    quantity,
    unit,
    expiryDate,
    slotCode,
    daysUntilExpiry,
    healthStatus,
  ];
}

/// كيان رأس البالتة (Master Pallet)
class ReceivingPalletEntity extends Equatable {
  final String id;
  final String palletReference;
  final String slotId;
  final String slotCode;
  final List<ReceivingPalletItemEntity> items;

  const ReceivingPalletEntity({
    required this.id,
    required this.palletReference,
    required this.slotId,
    required this.slotCode,
    required this.items,
  });

  bool get isMixed => items.length > 1;
  bool get hasCondemnationAlert => items.any((i) => i.isDueForCondemnation);

  int get minDaysUntilExpiry => items.isEmpty
      ? 0
      : items.map((e) => e.daysUntilExpiry).reduce((a, b) => a < b ? a : b);

  @override
  List<Object?> get props => [id, palletReference, slotId, slotCode, items];
}

/// كيان البنة في الراك (320 بنة مقسمة على 20 راك)
class ReceivingRackSlotEntity extends Equatable {
  final String id;
  final String zoneCode; // 'C2' or 'C3'
  final String rackLetter; // 'A' .. 'T'
  final int floorNumber; // 1 .. 4
  final int binNumber; // 1 .. 4
  final String slotCode; // 'C2 - A02 - 4'
  final bool isOccupied;
  final ReceivingPalletEntity? occupiedPallet;

  const ReceivingRackSlotEntity({
    required this.id,
    required this.zoneCode,
    required this.rackLetter,
    required this.floorNumber,
    required this.binNumber,
    required this.slotCode,
    required this.isOccupied,
    this.occupiedPallet,
  });

  @override
  List<Object?> get props => [
    id,
    zoneCode,
    rackLetter,
    floorNumber,
    binNumber,
    slotCode,
    isOccupied,
    occupiedPallet,
  ];
}

/// كيان سجل الاستلامات (مع رقم البالتة الحقيقي من جدول pallets)
class ReceivingMovementEntity extends Equatable {
  final String id;
  final String palletId;
  final String? palletReference;
  final MovementActionType movementType;
  final String itemName;
  final double previousQuantity;
  final double quantityChanged;
  final double newQuantity;
  final PackageUnit unit;
  final ReceivingSource sourceEntity;
  final String? fromSlotCode;
  final String? toSlotCode;
  final String? notes;
  final String performedByName;
  final DateTime createdAt;

  const ReceivingMovementEntity({
    required this.id,
    required this.palletId,
    this.palletReference,
    required this.movementType,
    required this.itemName,
    required this.previousQuantity,
    required this.quantityChanged,
    required this.newQuantity,
    required this.unit,
    required this.sourceEntity,
    this.fromSlotCode,
    this.toSlotCode,
    this.notes,
    required this.performedByName,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    palletId,
    palletReference,
    movementType,
    itemName,
    quantityChanged,
    createdAt,
  ];
}


/// نوع عملية الاستلام المجمّعة القادمة من PostgreSQL
enum ReceiptOperationKind {
  all('all', 'كل الأنواع'),
  single('single', 'بالتة موحدة'),
  mixed('mixed', 'بالتة ميكس'),
  addItem('add_item', 'تزويد صنف');

  final String dbValue;
  final String arLabel;
  const ReceiptOperationKind(this.dbValue, this.arLabel);

  static ReceiptOperationKind fromDb(String? val) => switch (val) {
    'mixed' => ReceiptOperationKind.mixed,
    'add_item' => ReceiptOperationKind.addItem,
    _ => ReceiptOperationKind.single,
  };
}

/// فلاتر ومعاملات الباجينيشن لسجل الاستلامات (تُرسل مباشرة لقاعدة البيانات)
class ReceiptsHistoryFilter extends Equatable {
  final int page;
  final int pageSize;
  final String search;
  final ReceivingSource? source;
  final ReceiptOperationKind kind;
  final DateTime? fromDate;
  final DateTime? toDate;

  const ReceiptsHistoryFilter({
    this.page = 1,
    this.pageSize = 20,
    this.search = '',
    this.source,
    this.kind = ReceiptOperationKind.all,
    this.fromDate,
    this.toDate,
  });

  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      source != null ||
      kind != ReceiptOperationKind.all ||
      fromDate != null ||
      toDate != null;

  ReceiptsHistoryFilter copyWith({
    int? page,
    int? pageSize,
    String? search,
    ReceivingSource? source,
    bool clearSource = false,
    ReceiptOperationKind? kind,
    DateTime? fromDate,
    bool clearFromDate = false,
    DateTime? toDate,
    bool clearToDate = false,
  }) {
    return ReceiptsHistoryFilter(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      search: search ?? this.search,
      source: clearSource ? null : (source ?? this.source),
      kind: kind ?? this.kind,
      fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
    );
  }

  @override
  List<Object?> get props => [
    page,
    pageSize,
    search,
    source,
    kind,
    fromDate,
    toDate,
  ];
}

class ReceiptOperationItemEntity extends Equatable {
  final String id;
  final String itemName;
  final double quantity;
  final PackageUnit unit;
  final ReceivingSource sourceEntity;
  final String? notes;

  const ReceiptOperationItemEntity({
    required this.id,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.sourceEntity,
    this.notes,
  });

  @override
  List<Object?> get props => [id, itemName, quantity, unit, sourceEntity];
}

/// عملية استلام مجمّعة (بالتة موحدة أو ميكس أو تزويد) محسوبة بالكامل في PostgreSQL
class ReceiptOperationEntity extends Equatable {
  final String operationKey;
  final String palletId;
  final String palletReference;
  final MovementActionType movementType;
  final ReceiptOperationKind operationKind;
  final int itemsCount;
  final String totalSummary;
  final String slotCode;
  final ReceivingSource sourceEntity;
  final String performedByName;
  final DateTime createdAt;
  final List<ReceiptOperationItemEntity> items;

  const ReceiptOperationEntity({
    required this.operationKey,
    required this.palletId,
    required this.palletReference,
    required this.movementType,
    required this.operationKind,
    required this.itemsCount,
    required this.totalSummary,
    required this.slotCode,
    required this.sourceEntity,
    required this.performedByName,
    required this.createdAt,
    required this.items,
  });

  String get kindDisplayLabel => operationKind == ReceiptOperationKind.mixed
      ? 'ميكس ($itemsCount أصناف)'
      : operationKind.arLabel;

  @override
  List<Object?> get props => [
    operationKey,
    palletId,
    palletReference,
    operationKind,
    itemsCount,
    totalSummary,
    slotCode,
    createdAt,
  ];
}

/// ملخص مؤشرات سجل الاستلامات (محسوب بالكامل داخل PostgreSQL على كافة النتائج المفلترة)
class ReceiptsHistorySummaryEntity extends Equatable {
  final int totalOperations;
  final int singleCount;
  final int mixedCount;
  final int addItemCount;
  final int totalItemLines;
  final String totalsByUnitSummary;

  const ReceiptsHistorySummaryEntity({
    this.totalOperations = 0,
    this.singleCount = 0,
    this.mixedCount = 0,
    this.addItemCount = 0,
    this.totalItemLines = 0,
    this.totalsByUnitSummary = '0',
  });

  @override
  List<Object?> get props => [
    totalOperations,
    singleCount,
    mixedCount,
    addItemCount,
    totalItemLines,
    totalsByUnitSummary,
  ];
}

/// نتيجة صفحة واحدة من سجل الاستلامات + الملخص الكلي
class ReceiptsHistoryPageEntity extends Equatable {
  final PagedResult<ReceiptOperationEntity> page;
  final ReceiptsHistorySummaryEntity summary;

  const ReceiptsHistoryPageEntity({
    required this.page,
    required this.summary,
  });

  const ReceiptsHistoryPageEntity.empty()
    : page = const PagedResult.empty(),
      summary = const ReceiptsHistorySummaryEntity();

  @override
  List<Object?> get props => [page, summary];
}

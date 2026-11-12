import 'package:equatable/equatable.dart';

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

  static ReceivingSource fromDb(String val) => ReceivingSource.values.firstWhere(
        (e) => e.dbValue == val,
        orElse: () => ReceivingSource.production,
      );
}

/// أنواع الحركات المخزنية المطابقة لـ PostgreSQL ENUM (movement_type)
enum MovementActionType {
  receiveNew('receive_new', 'استلام بالتة جديدة'),
  addItemToPallet('add_item_to_pallet', 'تزويد صنف على بالتة'),
  adjustQuantity('adjust_quantity', 'تعديل كمية جرد'),
  dispatch('dispatch', 'صرف من الثلاجة'),
  condemn('condemn', 'إعدام'),
  relocate('relocate', 'تحويل بين الراكات');

  final String dbValue;
  final String arLabel;
  const MovementActionType(this.dbValue, this.arLabel);

  static MovementActionType fromDb(String val) => MovementActionType.values.firstWhere(
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
  })  : productionDate = productionDate ?? DateTime.now(),
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

/// كيان سجل الاستلامات والصرف والتعديلات
class ReceivingMovementEntity extends Equatable {
  final String id;
  final String palletId;
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
  List<Object?> get props => [id, movementType, itemName, quantityChanged, createdAt];
}

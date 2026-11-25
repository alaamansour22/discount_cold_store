import 'package:equatable/equatable.dart';

import '../../../../core/pagination/paged_result.dart';
import '../../../receiving/domain/entities/receiving_entities.dart';

enum DeletedActionKind {
  fullPallet('DELETE_MISTAKEN_PALLET', 'حذف بالتة كاملة'),
  singleItem('DELETE_MISTAKEN_PALLET_ITEM', 'حذف صنف محدد');

  final String dbValue;
  final String arLabel;
  const DeletedActionKind(this.dbValue, this.arLabel);

  static DeletedActionKind fromDb(String val) =>
      DeletedActionKind.values.firstWhere(
        (e) => e.dbValue == val,
        orElse: () => DeletedActionKind.singleItem,
      );
}

class DeletedItemSnapshot extends Equatable {
  final String itemName;
  final double quantity;
  final PackageUnit unit;
  final DateTime? productionDate;
  final DateTime? expiryDate;

  const DeletedItemSnapshot({
    required this.itemName,
    required this.quantity,
    required this.unit,
    this.productionDate,
    this.expiryDate,
  });

  @override
  List<Object?> get props => [
    itemName,
    quantity,
    unit,
    productionDate,
    expiryDate,
  ];
}

class DeletedRecordEntity extends Equatable {
  final String id;
  final DeletedActionKind actionKind;
  final String palletReference;
  final String slotCode;
  final ReceivingSource? sourceEntity;
  final String reason;
  final String deletedByName;
  final DateTime deletedAt;
  final bool slotFreed;
  final List<DeletedItemSnapshot> items;

  const DeletedRecordEntity({
    required this.id,
    required this.actionKind,
    required this.palletReference,
    required this.slotCode,
    this.sourceEntity,
    required this.reason,
    required this.deletedByName,
    required this.deletedAt,
    required this.slotFreed,
    required this.items,
  });

  bool get isFullPallet => actionKind == DeletedActionKind.fullPallet;

  @override
  List<Object?> get props => [
    id,
    actionKind,
    palletReference,
    slotCode,
    reason,
    deletedByName,
    deletedAt,
    slotFreed,
    items,
  ];
}

class DeletedRecordsFilter extends Equatable {
  final int page;
  final int pageSize;
  final String search;
  final DeletedActionKind? kind;
  final DateTime? fromDate;
  final DateTime? toDate;

  const DeletedRecordsFilter({
    this.page = 1,
    this.pageSize = 20,
    this.search = '',
    this.kind,
    this.fromDate,
    this.toDate,
  });

  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      kind != null ||
      fromDate != null ||
      toDate != null;

  DeletedRecordsFilter copyWith({
    int? page,
    int? pageSize,
    String? search,
    DeletedActionKind? kind,
    bool clearKind = false,
    DateTime? fromDate,
    bool clearFromDate = false,
    DateTime? toDate,
    bool clearToDate = false,
  }) {
    return DeletedRecordsFilter(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      search: search ?? this.search,
      kind: clearKind ? null : (kind ?? this.kind),
      fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
    );
  }

  @override
  List<Object?> get props => [page, pageSize, search, kind, fromDate, toDate];
}

class DeletedRecordsSummaryEntity extends Equatable {
  final int totalDeletions;
  final int fullPalletCount;
  final int singleItemCount;

  const DeletedRecordsSummaryEntity({
    this.totalDeletions = 0,
    this.fullPalletCount = 0,
    this.singleItemCount = 0,
  });

  @override
  List<Object?> get props => [
    totalDeletions,
    fullPalletCount,
    singleItemCount,
  ];
}

class DeletedRecordsPageEntity extends Equatable {
  final PagedResult<DeletedRecordEntity> page;
  final DeletedRecordsSummaryEntity summary;

  const DeletedRecordsPageEntity({required this.page, required this.summary});

  const DeletedRecordsPageEntity.empty()
    : page = const PagedResult.empty(),
      summary = const DeletedRecordsSummaryEntity();

  @override
  List<Object?> get props => [page, summary];
}
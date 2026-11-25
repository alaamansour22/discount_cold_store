import 'package:equatable/equatable.dart';

import '../../../../core/pagination/paged_result.dart';
import '../../../receiving/domain/entities/receiving_entities.dart';

class SystemMovementEntity extends Equatable {
  final String id;
  final String palletId;
  final String palletReference;
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

  const SystemMovementEntity({
    required this.id,
    required this.palletId,
    this.palletReference = '—',
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

class MovementsLogFilter extends Equatable {
  final int page;
  final int pageSize;
  final String search;
  final MovementActionType? movementType;
  final ReceivingSource? source;
  final DateTime? fromDate;
  final DateTime? toDate;

  const MovementsLogFilter({
    this.page = 1,
    this.pageSize = 25,
    this.search = '',
    this.movementType,
    this.source,
    this.fromDate,
    this.toDate,
  });

  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      movementType != null ||
      source != null ||
      fromDate != null ||
      toDate != null;

  MovementsLogFilter copyWith({
    int? page,
    int? pageSize,
    String? search,
    MovementActionType? movementType,
    bool clearMovementType = false,
    ReceivingSource? source,
    bool clearSource = false,
    DateTime? fromDate,
    bool clearFromDate = false,
    DateTime? toDate,
    bool clearToDate = false,
  }) {
    return MovementsLogFilter(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      search: search ?? this.search,
      movementType: clearMovementType
          ? null
          : (movementType ?? this.movementType),
      source: clearSource ? null : (source ?? this.source),
      fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
    );
  }

  @override
  List<Object?> get props => [
    page,
    pageSize,
    search,
    movementType,
    source,
    fromDate,
    toDate,
  ];
}

class MovementsLogSummaryEntity extends Equatable {
  final int totalMovements;
  final int todayMovements;

  const MovementsLogSummaryEntity({
    this.totalMovements = 0,
    this.todayMovements = 0,
  });

  @override
  List<Object?> get props => [totalMovements, todayMovements];
}

class MovementsLogPageEntity extends Equatable {
  final PagedResult<SystemMovementEntity> page;
  final MovementsLogSummaryEntity summary;

  const MovementsLogPageEntity({required this.page, required this.summary});

  const MovementsLogPageEntity.empty()
    : page = const PagedResult.empty(pageSize: 25),
      summary = const MovementsLogSummaryEntity();

  @override
  List<Object?> get props => [page, summary];
}
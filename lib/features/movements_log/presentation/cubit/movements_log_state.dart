import 'package:discount_cold_store/features/movements_log/domain/entities/movements_log_entities.dart';
import 'package:discount_cold_store/features/receiving_dispatch/domain/entities/receiving_dispatch_entities.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/error_handler.dart';


class MovementsLogState extends Equatable {
  final bool isLoading;
  final List<SystemMovementEntity> movements;
  final DateTime? fromDate;
  final DateTime? toDate;
  final MovementActionType? movementTypeFilter;
  final ReceivingSource? sourceFilter;
  final AppFailure? failure;

  const MovementsLogState({
    this.isLoading = true,
    this.movements = const [],
    this.fromDate,
    this.toDate,
    this.movementTypeFilter,
    this.sourceFilter,
    this.failure,
  });

  MovementsLogState copyWith({
    bool? isLoading,
    List<SystemMovementEntity>? movements,
    DateTime? fromDate,
    bool clearFromDate = false,
    DateTime? toDate,
    bool clearToDate = false,
    MovementActionType? movementTypeFilter,
    bool clearMovementType = false,
    ReceivingSource? sourceFilter,
    bool clearSource = false,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return MovementsLogState(
      isLoading: isLoading ?? this.isLoading,
      movements: movements ?? this.movements,
      fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
      movementTypeFilter: clearMovementType
          ? null
          : (movementTypeFilter ?? this.movementTypeFilter),
      sourceFilter: clearSource ? null : (sourceFilter ?? this.sourceFilter),
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        movements,
        fromDate,
        toDate,
        movementTypeFilter,
        sourceFilter,
        failure,
      ];
}

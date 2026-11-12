import 'dart:async';
import 'package:discount_cold_store/features/movements_log/domain/usecases/movements_log_usecases.dart';
import 'package:discount_cold_store/features/receiving_dispatch/domain/entities/receiving_dispatch_entities.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/error_handler.dart';
import 'movements_log_state.dart';

class MovementsLogCubit extends Cubit<MovementsLogState> {
  final MovementsLogUseCases _useCases;
  StreamSubscription<void>? _realtimeSub;

  MovementsLogCubit(this._useCases) : super(const MovementsLogState()) {
    loadMovements();
    _realtimeSub = _useCases.watchRealtime().listen((_) {
      loadMovements(silent: true);
    });
  }

  Future<void> loadMovements({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(isLoading: true, clearFailure: true));
    }
    try {
      final list = await _useCases.getMovements(
        fromDate: state.fromDate,
        toDate: state.toDate,
        movementTypeFilter: state.movementTypeFilter,
        sourceFilter: state.sourceFilter,
      );
      emit(state.copyWith(
        isLoading: false,
        movements: list,
        clearFailure: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        failure: ErrorHandler.handle(e),
      ));
    }
  }

  Future<void> applyFilters({
    DateTime? fromDate,
    DateTime? toDate,
    MovementActionType? movementTypeFilter,
    bool clearMovementType = false,
    ReceivingSource? sourceFilter,
    bool clearSource = false,
  }) async {
    emit(state.copyWith(
      isLoading: true,
      fromDate: fromDate,
      clearFromDate: fromDate == null,
      toDate: toDate,
      clearToDate: toDate == null,
      movementTypeFilter: movementTypeFilter,
      clearMovementType: clearMovementType,
      sourceFilter: sourceFilter,
      clearSource: clearSource,
      clearFailure: true,
    ));

    try {
      final list = await _useCases.getMovements(
        fromDate: state.fromDate,
        toDate: state.toDate,
        movementTypeFilter: state.movementTypeFilter,
        sourceFilter: state.sourceFilter,
      );
      emit(state.copyWith(
        isLoading: false,
        movements: list,
        clearFailure: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        failure: ErrorHandler.handle(e),
      ));
    }
  }

  @override
  Future<void> close() {
    _realtimeSub?.cancel();
    return super.close();
  }
}

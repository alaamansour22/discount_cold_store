import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/error_handler.dart';
import '../../domain/usecases/condemnations_usecases.dart';
import 'condemnations_state.dart';

class CondemnationsCubit extends Cubit<CondemnationsState> {
  final CondemnationsUseCases _useCases;
  StreamSubscription<void>? _realtimeSub;

  CondemnationsCubit(this._useCases) : super(const CondemnationsState()) {
    loadCondemnationsData();
    _realtimeSub = _useCases.watchRealtimeChanges().listen((_) {
      loadCondemnationsData(silent: true);
    });
  }

  Future<void> loadCondemnationsData({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(isLoading: true, clearFailure: true, clearSuccess: true));
    }
    try {
      final alertsRes = await _useCases.getActiveAlerts();
      final records = await _useCases.getHistoryRecords(
        fromDate: state.fromDateFilter,
        toDate: state.toDateFilter,
      );

      emit(state.copyWith(
        isLoading: false,
        alertItems: alertsRes.alertItems,
        globalThresholdDays: alertsRes.globalThresholdDays,
        userCustomAlertDays: alertsRes.userCustomAlertDays,
        historyRecords: records,
        clearFailure: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        failure: ErrorHandler.handle(e),
      ));
    }
  }

  Future<void> applyDateRangeFilter({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    emit(state.copyWith(
      isLoading: true,
      fromDateFilter: fromDate,
      clearFromDate: fromDate == null,
      toDateFilter: toDate,
      clearToDate: toDate == null,
      clearFailure: true,
      clearSuccess: true,
    ));

    try {
      final records = await _useCases.getHistoryRecords(
        fromDate: fromDate,
        toDate: toDate,
      );
      emit(state.copyWith(
        isLoading: false,
        historyRecords: records,
        clearFailure: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        failure: ErrorHandler.handle(e),
      ));
    }
  }

  void selectSourceFilter(String sourceFilter) {
    emit(state.copyWith(
      sourceFilter: sourceFilter,
      clearFailure: true,
      clearSuccess: true,
    ));
  }

  Future<void> approveCondemnation({
    required String palletItemId,
    required double availableQuantity,
    required double quantityToCondemn,
    required String reason,
  }) async {
    emit(state.copyWith(isSubmitting: true, clearFailure: true, clearSuccess: true));
    try {
      await _useCases.approveCondemnation(
        palletItemId: palletItemId,
        availableQuantity: availableQuantity,
        quantityToCondemn: quantityToCondemn,
        reason: reason,
      );
      await loadCondemnationsData(silent: true);
      emit(state.copyWith(
        isSubmitting: false,
        successMessage: 'تم اعتماد إعدام الصنف وتوثيقه في سجل الإعدامات بنجاح',
      ));
    } catch (e) {
      final failure = ErrorHandler.handle(e);
      if (failure.type == FailureType.concurrencyConflict ||
          failure.type == FailureType.insufficientQuantity) {
        await loadCondemnationsData(silent: true);
      }
      emit(state.copyWith(isSubmitting: false, failure: failure));
    }
  }

  @override
  Future<void> close() {
    _realtimeSub?.cancel();
    return super.close();
  }
}
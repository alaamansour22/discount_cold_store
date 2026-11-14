import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/usecases/condemnations_usecases.dart';
import 'condemnations_state.dart';

class CondemnationsCubit extends Cubit<CondemnationsState> {
  final CondemnationsUseCases _useCases;
  StreamSubscription<void>? _realtimeSub;

  int _loadGeneration = 0;
  int _historyGeneration = 0;
  bool _isClosing = false;
  bool _realtimeReloadQueued = false;

  CondemnationsCubit(this._useCases) : super(const CondemnationsState()) {
    // The Cubit is app-scoped and the shell uses IndexedStack, so the screen
    // can remain alive while hidden. Realtime updates are coalesced.
    unawaited(loadCondemnationsData());
    _realtimeSub = _useCases.watchRealtimeChanges().listen((_) {
      if (_isClosing || isClosed || _realtimeReloadQueued) return;
      _realtimeReloadQueued = true;
      scheduleMicrotask(() {
        _realtimeReloadQueued = false;
        if (!_isClosing && !isClosed) {
          unawaited(loadCondemnationsData(silent: true));
        }
      });
    });
  }

  Future<void> loadCondemnationsData({bool silent = false}) async {
    if (_isClosing || isClosed) return;
    final generation = ++_loadGeneration;
    if (!silent) {
      emit(
        state.copyWith(isLoading: true, clearFailure: true, clearSuccess: true),
      );
    }

    try {
      final results = await Future.wait<dynamic>([
        _useCases.getActiveAlerts(),
        _useCases.getHistoryRecords(
          fromDate: state.fromDateFilter,
          toDate: state.toDateFilter,
        ),
      ]);
      if (_isClosing || isClosed || generation != _loadGeneration) return;

      final alertsRes = results[0];
      final records = results[1];
      emit(
        state.copyWith(
          isLoading: false,
          alertItems: alertsRes.alertItems,
          globalThresholdDays: alertsRes.globalThresholdDays,
          userCustomAlertDays: alertsRes.userCustomAlertDays,
          historyRecords: records,
          clearFailure: true,
        ),
      );
    } catch (e) {
      if (_isClosing || isClosed || generation != _loadGeneration) return;
      emit(state.copyWith(isLoading: false, failure: ErrorHandler.handle(e)));
    }
  }

  Future<void> applyDateRangeFilter({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    if (_isClosing || isClosed) return;
    final generation = ++_historyGeneration;
    // Invalidate a full refresh already in flight because it may have used
    // the previous date range.
    ++_loadGeneration;

    emit(
      state.copyWith(
        isLoading: true,
        fromDateFilter: fromDate,
        clearFromDate: fromDate == null,
        toDateFilter: toDate,
        clearToDate: toDate == null,
        clearFailure: true,
        clearSuccess: true,
      ),
    );

    try {
      final records = await _useCases.getHistoryRecords(
        fromDate: fromDate,
        toDate: toDate,
      );
      if (_isClosing || isClosed || generation != _historyGeneration) return;
      emit(
        state.copyWith(
          isLoading: false,
          historyRecords: records,
          clearFailure: true,
        ),
      );
    } catch (e) {
      if (_isClosing || isClosed || generation != _historyGeneration) return;
      emit(state.copyWith(isLoading: false, failure: ErrorHandler.handle(e)));
    }
  }

  void selectSourceFilter(String sourceFilter) {
    if (_isClosing || isClosed) return;
    emit(
      state.copyWith(
        sourceFilter: sourceFilter,
        clearFailure: true,
        clearSuccess: true,
      ),
    );
  }

  Future<void> approveCondemnation({
    required String palletItemId,
    required double availableQuantity,
    required double quantityToCondemn,
    required String reason,
  }) async {
    if (_isClosing || isClosed) return;
    emit(
      state.copyWith(
        isSubmitting: true,
        clearFailure: true,
        clearSuccess: true,
      ),
    );
    try {
      await _useCases.approveCondemnation(
        palletItemId: palletItemId,
        availableQuantity: availableQuantity,
        quantityToCondemn: quantityToCondemn,
        reason: reason,
      );
      if (_isClosing || isClosed) return;
      await loadCondemnationsData(silent: true);
      if (_isClosing || isClosed) return;
      emit(
        state.copyWith(
          isSubmitting: false,
          successMessage:
              'تم اعتماد إعدام الصنف وتوثيقه في سجل الإعدامات بنجاح',
        ),
      );
    } catch (e) {
      if (_isClosing || isClosed) return;
      final failure = ErrorHandler.handle(e);
      if (failure.type == FailureType.concurrencyConflict ||
          failure.type == FailureType.insufficientQuantity) {
        await loadCondemnationsData(silent: true);
      }
      if (_isClosing || isClosed) return;
      emit(state.copyWith(isSubmitting: false, failure: failure));
    }
  }

  @override
  Future<void> close() async {
    _isClosing = true;
    ++_loadGeneration;
    ++_historyGeneration;
    await _realtimeSub?.cancel();
    _realtimeSub = null;
    await super.close();
  }
}

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/entities/condemnations_entities.dart';
import '../../domain/usecases/condemnations_usecases.dart';
import 'condemnations_state.dart';

class CondemnationsCubit extends Cubit<CondemnationsState> {
  final CondemnationsUseCases _useCases;
  StreamSubscription<void>? _realtimeSub;

  int _alertsRequestSeq = 0;
  int _historyRequestSeq = 0;
  bool _isClosing = false;
  bool _realtimeReloadQueued = false;

  CondemnationsCubit(this._useCases) : super(const CondemnationsState()) {
    unawaited(loadAll(silent: false));
    _realtimeSub = _useCases.watchRealtimeChanges().listen((_) {
      if (_isClosing || isClosed || _realtimeReloadQueued) {
        return;
      }
      _realtimeReloadQueued = true;
      scheduleMicrotask(() {
        _realtimeReloadQueued = false;
        if (!_isClosing && !isClosed) {
          unawaited(loadAll(silent: true));
        }
      });
    });
  }

  Future<void> loadAll({bool silent = false}) async {
    await Future.wait([
      loadAlerts(silent: silent),
      loadHistory(silent: silent),
    ]);
  }

  // ==================== 1. تنبيهات الإعدام (Server-Side Pagination) ====================

  Future<void> loadAlerts({
    CondemnationAlertsFilter? filter,
    bool silent = false,
  }) async {
    if (_isClosing || isClosed) {
      return;
    }
    final targetFilter = filter ?? state.alertsFilter;
    final seq = ++_alertsRequestSeq;

    if (!silent) {
      emit(
        state.copyWith(
          isAlertsLoading: true,
          alertsFilter: targetFilter,
          clearFailure: true,
          clearSuccess: true,
        ),
      );
    }

    try {
      final result = await _useCases.getActiveAlerts(targetFilter);
      if (_isClosing || isClosed || seq != _alertsRequestSeq) {
        return;
      }

      if (targetFilter.page > result.page.totalPages &&
          result.page.totalPages >= 1) {
        await loadAlerts(
          filter: targetFilter.copyWith(page: result.page.totalPages),
          silent: silent,
        );
        return;
      }

      emit(
        state.copyWith(
          isAlertsLoading: false,
          alertsInitialized: true,
          alertsFilter: targetFilter,
          alertsData: result,
          clearFailure: true,
        ),
      );
    } catch (e) {
      if (_isClosing || isClosed || seq != _alertsRequestSeq) {
        return;
      }
      emit(
        state.copyWith(
          isAlertsLoading: false,
          alertsInitialized: true,
          failure: ErrorHandler.handle(e),
        ),
      );
    }
  }

  Future<void> updateAlertsFilter(CondemnationAlertsFilter nextFilter) =>
      loadAlerts(filter: nextFilter.copyWith(page: 1));

  Future<void> goToAlertsPage(int page) =>
      loadAlerts(filter: state.alertsFilter.copyWith(page: page));

  Future<void> changeAlertsPageSize(int pageSize) => loadAlerts(
    filter: state.alertsFilter.copyWith(page: 1, pageSize: pageSize),
  );

  Future<void> clearAlertsFilters() => loadAlerts(
    filter: CondemnationAlertsFilter(pageSize: state.alertsFilter.pageSize),
  );

  Future<CondemnationAlertsPageEntity> fetchAlertsForExport() {
    return _useCases.getActiveAlerts(
      state.alertsFilter.copyWith(page: 1, pageSize: 500),
    );
  }

  // ==================== 2. سجل الإعدامات (Server-Side Pagination) ====================

  Future<void> loadHistory({
    CondemnationHistoryFilter? filter,
    bool silent = false,
  }) async {
    if (_isClosing || isClosed) {
      return;
    }
    final targetFilter = filter ?? state.historyFilter;
    final seq = ++_historyRequestSeq;

    if (!silent) {
      emit(
        state.copyWith(
          isHistoryLoading: true,
          historyFilter: targetFilter,
          clearFailure: true,
          clearSuccess: true,
        ),
      );
    }

    try {
      final result = await _useCases.getHistoryRecords(targetFilter);
      if (_isClosing || isClosed || seq != _historyRequestSeq) {
        return;
      }

      if (targetFilter.page > result.page.totalPages &&
          result.page.totalPages >= 1) {
        await loadHistory(
          filter: targetFilter.copyWith(page: result.page.totalPages),
          silent: silent,
        );
        return;
      }

      emit(
        state.copyWith(
          isHistoryLoading: false,
          historyInitialized: true,
          historyFilter: targetFilter,
          historyData: result,
          clearFailure: true,
        ),
      );
    } catch (e) {
      if (_isClosing || isClosed || seq != _historyRequestSeq) {
        return;
      }
      emit(
        state.copyWith(
          isHistoryLoading: false,
          historyInitialized: true,
          failure: ErrorHandler.handle(e),
        ),
      );
    }
  }

  Future<void> updateHistoryFilter(CondemnationHistoryFilter nextFilter) =>
      loadHistory(filter: nextFilter.copyWith(page: 1));

  Future<void> goToHistoryPage(int page) =>
      loadHistory(filter: state.historyFilter.copyWith(page: page));

  Future<void> changeHistoryPageSize(int pageSize) => loadHistory(
    filter: state.historyFilter.copyWith(page: 1, pageSize: pageSize),
  );

  Future<void> clearHistoryFilters() => loadHistory(
    filter: CondemnationHistoryFilter(pageSize: state.historyFilter.pageSize),
  );

  Future<CondemnationHistoryPageEntity> fetchHistoryForExport() {
    return _useCases.getHistoryRecords(
      state.historyFilter.copyWith(page: 1, pageSize: 1000),
    );
  }

  // ==================== 3. اعتماد إعدام صنف ====================

  Future<bool> approveCondemnation({
    required String palletItemId,
    required double availableQuantity,
    required double quantityToCondemn,
    required String reason,
  }) async {
    if (_isClosing || isClosed) {
      return false;
    }
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
      if (_isClosing || isClosed) {
        return true;
      }
      await loadAll(silent: true);
      if (_isClosing || isClosed) {
        return true;
      }
      emit(
        state.copyWith(
          isSubmitting: false,
          successMessage:
              'تم اعتماد إعدام الصنف وتوثيقه في سجل الإعدامات بنجاح',
        ),
      );
      return true;
    } catch (e) {
      if (_isClosing || isClosed) {
        return false;
      }
      final failure = ErrorHandler.handle(e);
      if (failure.type == FailureType.concurrencyConflict ||
          failure.type == FailureType.insufficientQuantity) {
        await loadAll(silent: true);
      }
      if (_isClosing || isClosed) {
        return false;
      }
      emit(state.copyWith(isSubmitting: false, failure: failure));
      return false;
    }
  }

  @override
  Future<void> close() async {
    _isClosing = true;
    ++_alertsRequestSeq;
    ++_historyRequestSeq;
    await _realtimeSub?.cancel();
    _realtimeSub = null;
    await super.close();
  }
}
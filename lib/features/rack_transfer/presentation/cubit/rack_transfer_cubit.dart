import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/entities/rack_transfer_entities.dart';
import '../../domain/usecases/rack_transfer_usecases.dart';
import 'rack_transfer_state.dart';

class RackTransferCubit extends Cubit<RackTransferState> {
  final RackTransferUseCases _useCases;
  StreamSubscription<void>? _realtimeSub;
  int _historyRequestSeq = 0;

  RackTransferCubit(this._useCases) : super(const RackTransferState()) {
    loadTransferData();
    _realtimeSub = _useCases.watchRealtimeChanges().listen((_) {
      if (!isClosed) {
        loadTransferData(silent: true);
      }
    });
  }

  Future<void> loadTransferData({bool silent = false}) async {
    if (isClosed) {
      return;
    }
    if (!silent) {
      emit(
        state.copyWith(isLoading: true, clearFailure: true, clearSuccess: true),
      );
    }
    try {
      final slots = await _useCases.getAllSlots();
      if (isClosed) {
        return;
      }
      emit(
        state.copyWith(isLoading: false, allSlots: slots, clearFailure: true),
      );
      if (state.historyInitialized) {
        await loadHistory(silent: true);
      }
    } catch (e) {
      if (isClosed) {
        return;
      }
      emit(state.copyWith(isLoading: false, failure: ErrorHandler.handle(e)));
    }
  }

  // ==================== سجل التحويلات (Server-Side Pagination) ====================

  Future<void> ensureHistoryLoaded() async {
    if (!state.historyInitialized && !state.isHistoryLoading) {
      await loadHistory();
    }
  }

  Future<void> loadHistory({
    RackTransferHistoryFilter? filter,
    bool silent = false,
  }) async {
    if (isClosed) {
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
        ),
      );
    }

    try {
      final result = await _useCases.getHistory(targetFilter);
      if (isClosed || seq != _historyRequestSeq) {
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
      if (isClosed || seq != _historyRequestSeq) {
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

  Future<void> updateHistoryFilter(RackTransferHistoryFilter nextFilter) =>
      loadHistory(filter: nextFilter.copyWith(page: 1));

  Future<void> goToHistoryPage(int page) =>
      loadHistory(filter: state.historyFilter.copyWith(page: page));

  Future<void> changeHistoryPageSize(int pageSize) => loadHistory(
    filter: state.historyFilter.copyWith(page: 1, pageSize: pageSize),
  );

  Future<void> clearHistoryFilters() => loadHistory(
    filter: RackTransferHistoryFilter(pageSize: state.historyFilter.pageSize),
  );

  Future<RackTransferHistoryPageEntity> fetchHistoryForExport() {
    return _useCases.getHistory(
      state.historyFilter.copyWith(page: 1, pageSize: 500),
    );
  }

  // ==================== نموذج تحويل الراكات ====================

  void selectSourceSlot(String slotId) {
    emit(
      state.copyWith(
        selectedSourceSlotId: slotId,
        clearFailure: true,
        clearSuccess: true,
      ),
    );
  }

  void selectTargetSlot(String slotId) {
    emit(
      state.copyWith(
        selectedTargetSlotId: slotId,
        clearFailure: true,
        clearSuccess: true,
      ),
    );
  }

  void selectTargetZoneFilter(String zoneFilter) {
    emit(
      state.copyWith(
        targetZoneFilter: zoneFilter,
        clearFailure: true,
        clearSuccess: true,
      ),
    );
  }

  Future<void> executeTransfer({required String notes}) async {
    if (isClosed) {
      return;
    }
    final source = state.selectedSourceSlot;
    final target = state.selectedTargetSlot;
    if (source == null || source.palletId == null || target == null) {
      return;
    }

    emit(
      state.copyWith(
        isSubmitting: true,
        clearFailure: true,
        clearSuccess: true,
      ),
    );
    try {
      await _useCases.relocatePallet(
        palletId: source.palletId!,
        sourceSlotId: source.slotId,
        targetSlotId: target.slotId,
        notes: notes,
      );
      if (isClosed) {
        return;
      }
      await loadTransferData(silent: true);
      if (isClosed) {
        return;
      }
      emit(
        state.copyWith(
          isSubmitting: false,
          successMessage:
              'تم تحويل البالتة بنجاح من [${source.slotCode}] إلى [${target.slotCode}]',
        ),
      );
    } catch (e) {
      if (isClosed) {
        return;
      }
      final failure = ErrorHandler.handle(e);
      if (failure.type == FailureType.concurrencyConflict) {
        await loadTransferData(silent: true);
      }
      if (isClosed) {
        return;
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
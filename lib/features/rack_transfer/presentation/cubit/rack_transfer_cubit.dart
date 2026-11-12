import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/error_handler.dart';
import '../../domain/usecases/rack_transfer_usecases.dart';
import 'rack_transfer_state.dart';

class RackTransferCubit extends Cubit<RackTransferState> {
  final RackTransferUseCases _useCases;
  StreamSubscription<void>? _realtimeSub;

  RackTransferCubit(this._useCases) : super(const RackTransferState()) {
    loadTransferData();
    _realtimeSub = _useCases.watchRealtimeChanges().listen((_) {
      loadTransferData(silent: true);
    });
  }

  Future<void> loadTransferData({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(isLoading: true, clearFailure: true, clearSuccess: true));
    }
    try {
      final slots = await _useCases.getAllSlots();
      final history = await _useCases.getHistory();
      emit(state.copyWith(
        isLoading: false,
        allSlots: slots,
        history: history,
        clearFailure: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        failure: ErrorHandler.handle(e),
      ));
    }
  }

  void selectSourceSlot(String slotId) {
    emit(state.copyWith(
      selectedSourceSlotId: slotId,
      clearFailure: true,
      clearSuccess: true,
    ));
  }

  void selectTargetSlot(String slotId) {
    emit(state.copyWith(
      selectedTargetSlotId: slotId,
      clearFailure: true,
      clearSuccess: true,
    ));
  }

  void selectTargetZoneFilter(String zoneFilter) {
    emit(state.copyWith(
      targetZoneFilter: zoneFilter,
      clearFailure: true,
      clearSuccess: true,
    ));
  }

  Future<void> executeTransfer({required String notes}) async {
    final source = state.selectedSourceSlot;
    final target = state.selectedTargetSlot;
    if (source == null || source.palletId == null || target == null) return;

    emit(state.copyWith(isSubmitting: true, clearFailure: true, clearSuccess: true));
    try {
      await _useCases.relocatePallet(
        palletId: source.palletId!,
        sourceSlotId: source.slotId,
        targetSlotId: target.slotId,
        notes: notes,
      );
      await loadTransferData(silent: true);
      emit(state.copyWith(
        isSubmitting: false,
        successMessage:
            'تم تحويل البالتة بنجاح من [${source.slotCode}] إلى [${target.slotCode}]',
      ));
    } catch (e) {
      final failure = ErrorHandler.handle(e);
      if (failure.type == FailureType.concurrencyConflict) {
        await loadTransferData(silent: true);
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
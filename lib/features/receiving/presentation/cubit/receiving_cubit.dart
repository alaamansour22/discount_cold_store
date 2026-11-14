import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/entities/receiving_entities.dart';
import '../../domain/usecases/receiving_usecases.dart';
import '../../../warehouse/domain/usecases/warehouse_usecases.dart';
import 'receiving_state.dart';

class ReceivingCubit extends Cubit<ReceivingState> {
  final ReceivingUseCases _useCases;
  final WarehouseUseCases _warehouseUseCases;
  StreamSubscription<void>? _realtimeSub;

  ReceivingCubit(this._useCases, this._warehouseUseCases)
    : super(const ReceivingState()) {
    loadData();
    _realtimeSub = _warehouseUseCases.watchUpdates().listen((_) {
      loadData(silent: true);
    });
  }

  Future<void> loadData({bool silent = false}) async {
    if (!silent) {
      emit(
        state.copyWith(isLoading: true, clearFailure: true, clearSuccess: true),
      );
    }
    try {
      final slots = await _warehouseUseCases.getRackSlots();
      final movements = await _useCases.getMovementsLog();
      emit(
        state.copyWith(
          isLoading: false,
          slots: slots,
          movements: movements,
          clearFailure: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, failure: ErrorHandler.handle(e)));
    }
  }

  void selectZone(String zoneCode) {
    final defaultRack = zoneCode == 'C2' ? 'A' : 'N';
    emit(
      state.copyWith(
        selectedZone: zoneCode,
        selectedRackLetter: defaultRack,
        clearFailure: true,
        clearSuccess: true,
      ),
    );
  }

  void selectRackLetter(String rackLetter) {
    final code = rackLetter.trim().toUpperCase().codeUnitAt(0);
    final zone = (code >= 'A'.codeUnitAt(0) && code <= 'M'.codeUnitAt(0))
        ? 'C2'
        : 'C3';
    emit(
      state.copyWith(
        selectedZone: zone,
        selectedRackLetter: rackLetter,
        clearFailure: true,
        clearSuccess: true,
      ),
    );
  }

  Future<void> receiveNewPallet({
    required ReceivingSource sourceEntity,
    required String slotId,
    required List<PalletItemDraft> items,
  }) async {
    emit(
      state.copyWith(
        isSubmitting: true,
        clearFailure: true,
        clearSuccess: true,
      ),
    );
    try {
      await _useCases.receiveNewPallet(
        sourceEntity: sourceEntity,
        slotId: slotId,
        items: items,
      );
      await loadData(silent: true);
      emit(
        state.copyWith(
          isSubmitting: false,
          successMessage: items.length > 1
              ? 'تم استلام وتسكين البالتة الميكس (${items.length} أصناف) بنجاح'
              : 'تم استلام وتسكين البالتة بنجاح',
        ),
      );
    } catch (e) {
      final failure = ErrorHandler.handle(e);
      if (failure.type == FailureType.concurrencyConflict) {
        await loadData(silent: true);
      }
      emit(state.copyWith(isSubmitting: false, failure: failure));
    }
  }

  Future<void> addItemsToExistingPallet({
    required String palletId,
    required ReceivingSource sourceEntity,
    required List<PalletItemDraft> items,
  }) async {
    emit(
      state.copyWith(
        isSubmitting: true,
        clearFailure: true,
        clearSuccess: true,
      ),
    );
    try {
      await _useCases.addItemsToExistingPallet(
        palletId: palletId,
        sourceEntity: sourceEntity,
        items: items,
      );
      await loadData(silent: true);
      emit(
        state.copyWith(
          isSubmitting: false,
          successMessage: 'تم تزويد الأصناف الجديدة على البالتة بنجاح',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(isSubmitting: false, failure: ErrorHandler.handle(e)),
      );
    }
  }

  Future<void> adjustOrReleaseItem({
    required String palletItemId,
    required MovementActionType action,
    required double targetQuantity,
    String notes = '',
  }) async {
    emit(
      state.copyWith(
        isSubmitting: true,
        clearFailure: true,
        clearSuccess: true,
      ),
    );
    try {
      await _useCases.adjustOrReleaseItem(
        palletItemId: palletItemId,
        action: action,
        targetQuantity: targetQuantity,
        notes: notes,
      );
      await loadData(silent: true);
      emit(
        state.copyWith(
          isSubmitting: false,
          successMessage: 'تم تنفيذ عملية (${action.arLabel}) بنجاح',
        ),
      );
    } catch (e) {
      final failure = ErrorHandler.handle(e);
      if (failure.type == FailureType.concurrencyConflict ||
          failure.type == FailureType.insufficientQuantity) {
        await loadData(silent: true);
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

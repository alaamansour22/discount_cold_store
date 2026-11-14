import '../../../../core/error/error_handler.dart';
import '../entities/rack_transfer_entities.dart';
import '../repositories/i_rack_transfer_repository.dart';

class GetAllSlotsForTransferUseCase {
  final IRackTransferRepository _repository;
  const GetAllSlotsForTransferUseCase(this._repository);

  Future<List<TransferSlotEntity>> call() =>
      _repository.getAllSlotsForTransfer();
}

class GetRelocationHistoryUseCase {
  final IRackTransferRepository _repository;
  const GetRelocationHistoryUseCase(this._repository);

  Future<List<RackTransferHistoryEntity>> call({int limit = 150}) =>
      _repository.getRelocationHistory(limit: limit);
}

class RelocatePalletUseCase {
  final IRackTransferRepository _repository;
  const RelocatePalletUseCase(this._repository);

  Future<void> call({
    required String palletId,
    required String sourceSlotId,
    required String targetSlotId,
    required String notes,
  }) async {
    if (sourceSlotId == targetSlotId) {
      throw const AppFailure(
        message: 'لا يمكن نقل البالتة إلى نفس الموقع الموجودة فيه حالياً.',
        type: FailureType.validationError,
      );
    }
    return _repository.relocatePallet(
      palletId: palletId,
      targetSlotId: targetSlotId,
      notes: notes,
    );
  }
}

class WatchRealtimeTransferChangesUseCase {
  final IRackTransferRepository _repository;
  const WatchRealtimeTransferChangesUseCase(this._repository);

  Stream<void> call() => _repository.watchRealtimeTransferChanges();
}

/// حزمة UseCases مجمعة لموديول تحويل الراكات
class RackTransferUseCases {
  final GetAllSlotsForTransferUseCase getAllSlots;
  final GetRelocationHistoryUseCase getHistory;
  final RelocatePalletUseCase relocatePallet;
  final WatchRealtimeTransferChangesUseCase watchRealtimeChanges;

  RackTransferUseCases(IRackTransferRepository repository)
    : getAllSlots = GetAllSlotsForTransferUseCase(repository),
      getHistory = GetRelocationHistoryUseCase(repository),
      relocatePallet = RelocatePalletUseCase(repository),
      watchRealtimeChanges = WatchRealtimeTransferChangesUseCase(repository);
}

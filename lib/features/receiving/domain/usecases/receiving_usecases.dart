import '../../../../core/error/error_handler.dart';
import '../entities/receiving_entities.dart';
import '../repositories/i_receiving_repository.dart';

class GetReceivingMovementsLogUseCase {
  final IReceivingRepository _repository;
  const GetReceivingMovementsLogUseCase(this._repository);

  Future<List<ReceivingMovementEntity>> call({int limit = 250}) =>
      _repository.getMovementsLog(limit: limit);
}

class ReceiveNewPalletUseCase {
  final IReceivingRepository _repository;
  const ReceiveNewPalletUseCase(this._repository);

  Future<void> call({
    required ReceivingSource sourceEntity,
    required String slotId,
    required List<PalletItemDraft> items,
  }) async {
    if (items.isEmpty || !items.every((i) => i.isValid)) {
      throw const AppFailure(
        message: 'بيانات الأصناف غير مكتملة أو تاريخ الانتهاء غير صحيح.',
        type: FailureType.validationError,
      );
    }
    return _repository.receiveNewPallet(
      sourceEntity: sourceEntity,
      slotId: slotId,
      items: items,
    );
  }
}

class AddItemsToExistingPalletUseCase {
  final IReceivingRepository _repository;
  const AddItemsToExistingPalletUseCase(this._repository);

  Future<void> call({
    required String palletId,
    required ReceivingSource sourceEntity,
    required List<PalletItemDraft> items,
  }) async {
    if (items.isEmpty || !items.every((i) => i.isValid)) {
      throw const AppFailure(
        message: 'تأكد من صحة بيانات الصنف المضاف وتواريخ الصلاحية.',
        type: FailureType.validationError,
      );
    }
    return _repository.addItemsToExistingPallet(
      palletId: palletId,
      sourceEntity: sourceEntity,
      items: items,
    );
  }
}

class AdjustOrReleaseItemUseCase {
  final IReceivingRepository _repository;
  const AdjustOrReleaseItemUseCase(this._repository);

  Future<void> call({
    required String palletItemId,
    required MovementActionType action,
    required double targetQuantity,
    String notes = '',
  }) {
    return _repository.adjustOrReleaseItem(
      palletItemId: palletItemId,
      action: action,
      targetQuantity: targetQuantity,
      notes: notes,
    );
  }
}

/// حزمة UseCases مجمعة لموديول الاستلام والصرف
class ReceivingUseCases {
  final GetReceivingMovementsLogUseCase getMovementsLog;
  final ReceiveNewPalletUseCase receiveNewPallet;
  final AddItemsToExistingPalletUseCase addItemsToExistingPallet;
  final AdjustOrReleaseItemUseCase adjustOrReleaseItem;

  ReceivingUseCases(IReceivingRepository repository)
    : getMovementsLog = GetReceivingMovementsLogUseCase(repository),
      receiveNewPallet = ReceiveNewPalletUseCase(repository),
      addItemsToExistingPallet = AddItemsToExistingPalletUseCase(repository),
      adjustOrReleaseItem = AdjustOrReleaseItemUseCase(repository);
}

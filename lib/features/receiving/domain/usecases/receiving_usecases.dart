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

class DeleteMistakenPalletUseCase {
  final IReceivingRepository _repository;
  const DeleteMistakenPalletUseCase(this._repository);

  Future<void> call({
    required String palletId,
    required String reason,
  }) async {
    if (palletId.trim().isEmpty) {
      throw const AppFailure(
        message: 'معرّف البالتة غير صحيح.',
        type: FailureType.validationError,
      );
    }
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) {
      throw const AppFailure(
        message: 'يرجى كتابة سبب حذف البالتة.',
        type: FailureType.validationError,
      );
    }
    if (cleanReason.length > 500) {
      throw const AppFailure(
        message: 'سبب الحذف أطول من الحد المسموح (500 حرف).',
        type: FailureType.validationError,
      );
    }
    return _repository.deleteMistakenPallet(
      palletId: palletId,
      reason: cleanReason,
    );
  }
}

class DeleteMistakenPalletItemUseCase {
  final IReceivingRepository _repository;
  const DeleteMistakenPalletItemUseCase(this._repository);

  Future<bool> call({
    required String palletItemId,
    required String reason,
  }) async {
    if (palletItemId.trim().isEmpty) {
      throw const AppFailure(
        message: 'معرّف الصنف غير صحيح.',
        type: FailureType.validationError,
      );
    }
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) {
      throw const AppFailure(
        message: 'يرجى كتابة سبب حذف الصنف.',
        type: FailureType.validationError,
      );
    }
    if (cleanReason.length > 500) {
      throw const AppFailure(
        message: 'سبب الحذف أطول من الحد المسموح (500 حرف).',
        type: FailureType.validationError,
      );
    }
    return _repository.deleteMistakenPalletItem(
      palletItemId: palletItemId,
      reason: cleanReason,
    );
  }
}

/// حزمة UseCases مجمعة لموديول الاستلام والصرف
class ReceivingUseCases {
  final GetReceivingMovementsLogUseCase getMovementsLog;
  final ReceiveNewPalletUseCase receiveNewPallet;
  final AddItemsToExistingPalletUseCase addItemsToExistingPallet;
  final AdjustOrReleaseItemUseCase adjustOrReleaseItem;
  final DeleteMistakenPalletUseCase deleteMistakenPallet;
  final DeleteMistakenPalletItemUseCase deleteMistakenPalletItem;

  ReceivingUseCases(IReceivingRepository repository)
    : getMovementsLog = GetReceivingMovementsLogUseCase(repository),
      receiveNewPallet = ReceiveNewPalletUseCase(repository),
      addItemsToExistingPallet = AddItemsToExistingPalletUseCase(repository),
      adjustOrReleaseItem = AdjustOrReleaseItemUseCase(repository),
      deleteMistakenPallet = DeleteMistakenPalletUseCase(repository),
      deleteMistakenPalletItem = DeleteMistakenPalletItemUseCase(repository);
}
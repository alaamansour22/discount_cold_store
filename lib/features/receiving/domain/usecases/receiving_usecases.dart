import '../../../../core/error/error_handler.dart';
import '../entities/receiving_entities.dart';
import '../repositories/i_receiving_repository.dart';

// =============================================================================
// دوال تحقق مساعدة موحّدة (تمنع تكرار الفحوصات بين الـ UseCases)
// =============================================================================
String _requireNonEmptyId(String rawId, String entityLabel) {
  final cleanId = rawId.trim();
  if (cleanId.isEmpty) {
    throw AppFailure(
      message: 'معرّف $entityLabel غير صحيح.',
      type: FailureType.validationError,
    );
  }
  return cleanId;
}

String _validateDeletionReason(String rawReason, String entityLabel) {
  final cleanReason = rawReason.trim();
  if (cleanReason.isEmpty) {
    throw AppFailure(
      message: 'يرجى كتابة سبب حذف $entityLabel.',
      type: FailureType.validationError,
    );
  }
  if (cleanReason.length > 500) {
    throw const AppFailure(
      message: 'سبب الحذف أطول من الحد المسموح (500 حرف).',
      type: FailureType.validationError,
    );
  }
  return cleanReason;
}

// =============================================================================
// Query UseCases (Server-Side Pagination & Aggregation)
// =============================================================================
class GetReceiptsHistoryPaginatedUseCase {
  final IReceivingRepository _repository;
  const GetReceiptsHistoryPaginatedUseCase(this._repository);

  Future<ReceiptsHistoryPageEntity> call(ReceiptsHistoryFilter filter) async {
    if (filter.fromDate != null &&
        filter.toDate != null &&
        filter.fromDate!.isAfter(filter.toDate!)) {
      throw const AppFailure(
        message: 'تاريخ البداية لا يمكن أن يكون بعد تاريخ النهاية.',
        type: FailureType.validationError,
      );
    }

    final normalizedFilter = filter.copyWith(
      page: filter.page < 1 ? 1 : filter.page,
      pageSize: filter.pageSize.clamp(1, 500),
      search: filter.search.trim(),
    );

    return _repository.getReceiptsHistoryPaginated(normalizedFilter);
  }
}

// =============================================================================
// Command UseCases (جميع العمليات الفعلية تُنفّذ داخل PostgreSQL RPCs)
// =============================================================================
class ReceiveNewPalletUseCase {
  final IReceivingRepository _repository;
  const ReceiveNewPalletUseCase(this._repository);

  Future<void> call({
    required ReceivingSource sourceEntity,
    required String slotId,
    required List<PalletItemDraft> items,
  }) async {
    final cleanSlotId = _requireNonEmptyId(slotId, 'موقع الراك');
    if (items.isEmpty || !items.every((i) => i.isValid)) {
      throw const AppFailure(
        message: 'بيانات الأصناف غير مكتملة أو تاريخ الانتهاء غير صحيح.',
        type: FailureType.validationError,
      );
    }
    return _repository.receiveNewPallet(
      sourceEntity: sourceEntity,
      slotId: cleanSlotId,
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
    final cleanPalletId = _requireNonEmptyId(palletId, 'البالتة');
    if (items.isEmpty || !items.every((i) => i.isValid)) {
      throw const AppFailure(
        message: 'تأكد من صحة بيانات الصنف المضاف وتواريخ الصلاحية.',
        type: FailureType.validationError,
      );
    }
    return _repository.addItemsToExistingPallet(
      palletId: cleanPalletId,
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
  }) async {
    final cleanItemId = _requireNonEmptyId(palletItemId, 'الصنف');

    if (action == MovementActionType.dispatch) {
      throw const AppFailure(
        message: 'يجب تنفيذ الصرف من خلال شاشة إنشاء مستند الصرف.',
        type: FailureType.validationError,
      );
    }
    if (action == MovementActionType.adjustQuantity && targetQuantity < 0) {
      throw const AppFailure(
        message: 'الكمية الجديدة لا يمكن أن تكون سالبة.',
        type: FailureType.validationError,
      );
    }
    if (action == MovementActionType.condemn && targetQuantity <= 0) {
      throw const AppFailure(
        message: 'الكمية المطلوب إعدامها يجب أن تكون أكبر من صفر.',
        type: FailureType.validationError,
      );
    }

    final cleanNotes = notes.trim();
    if (cleanNotes.length > 500) {
      throw const AppFailure(
        message: 'الملاحظات أطول من الحد المسموح (500 حرف).',
        type: FailureType.validationError,
      );
    }

    return _repository.adjustOrReleaseItem(
      palletItemId: cleanItemId,
      action: action,
      targetQuantity: targetQuantity,
      notes: cleanNotes,
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
    final cleanPalletId = _requireNonEmptyId(palletId, 'البالتة');
    final cleanReason = _validateDeletionReason(reason, 'البالتة');

    return _repository.deleteMistakenPallet(
      palletId: cleanPalletId,
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
    final cleanItemId = _requireNonEmptyId(palletItemId, 'الصنف');
    final cleanReason = _validateDeletionReason(reason, 'الصنف');

    return _repository.deleteMistakenPalletItem(
      palletItemId: cleanItemId,
      reason: cleanReason,
    );
  }
}

// =============================================================================
// حزمة UseCases المجمّعة لموديول الاستلام
// =============================================================================
class ReceivingUseCases {
  final GetReceiptsHistoryPaginatedUseCase getReceiptsHistoryPaginated;
  final ReceiveNewPalletUseCase receiveNewPallet;
  final AddItemsToExistingPalletUseCase addItemsToExistingPallet;
  final AdjustOrReleaseItemUseCase adjustOrReleaseItem;
  final DeleteMistakenPalletUseCase deleteMistakenPallet;
  final DeleteMistakenPalletItemUseCase deleteMistakenPalletItem;

  ReceivingUseCases(IReceivingRepository repository)
    : getReceiptsHistoryPaginated = GetReceiptsHistoryPaginatedUseCase(
        repository,
      ),
      receiveNewPallet = ReceiveNewPalletUseCase(repository),
      addItemsToExistingPallet = AddItemsToExistingPalletUseCase(repository),
      adjustOrReleaseItem = AdjustOrReleaseItemUseCase(repository),
      deleteMistakenPallet = DeleteMistakenPalletUseCase(repository),
      deleteMistakenPalletItem = DeleteMistakenPalletItemUseCase(repository);
}
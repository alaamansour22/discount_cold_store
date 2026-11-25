import '../../../../core/error/error_handler.dart';
import '../entities/rack_transfer_entities.dart';
import '../repositories/i_rack_transfer_repository.dart';

class GetAllSlotsForTransferUseCase {
  final IRackTransferRepository _repository;
  const GetAllSlotsForTransferUseCase(this._repository);

  Future<List<TransferSlotEntity>> call() =>
      _repository.getAllSlotsForTransfer();
}

class GetRelocationHistoryPaginatedUseCase {
  final IRackTransferRepository _repository;
  const GetRelocationHistoryPaginatedUseCase(this._repository);

  Future<RackTransferHistoryPageEntity> call(
    RackTransferHistoryFilter filter,
  ) async {
    if (filter.fromDate != null &&
        filter.toDate != null &&
        filter.toDate!.isBefore(filter.fromDate!)) {
      throw const AppFailure(
        message: 'تاريخ النهاية يجب أن يكون بعد أو يساوي تاريخ البداية.',
        type: FailureType.validationError,
      );
    }

    final normalized = filter.copyWith(
      page: filter.page < 1 ? 1 : filter.page,
      pageSize: filter.pageSize.clamp(1, 500),
      search: filter.search.trim(),
    );

    return _repository.getRelocationHistoryPaginated(normalized);
  }
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
    final cleanPalletId = palletId.trim();
    final cleanSourceId = sourceSlotId.trim();
    final cleanTargetId = targetSlotId.trim();

    if (cleanPalletId.isEmpty ||
        cleanSourceId.isEmpty ||
        cleanTargetId.isEmpty) {
      throw const AppFailure(
        message: 'بيانات البالتة أو المواقع المحددة غير مكتملة.',
        type: FailureType.validationError,
      );
    }
    if (cleanSourceId == cleanTargetId) {
      throw const AppFailure(
        message: 'لا يمكن نقل البالتة إلى نفس الموقع الموجودة فيه حالياً.',
        type: FailureType.validationError,
      );
    }
    final cleanNotes = notes.trim();
    if (cleanNotes.length > 500) {
      throw const AppFailure(
        message: 'ملاحظات التحويل أطول من الحد المسموح (500 حرف).',
        type: FailureType.validationError,
      );
    }

    return _repository.relocatePallet(
      palletId: cleanPalletId,
      targetSlotId: cleanTargetId,
      notes: cleanNotes,
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
  final GetRelocationHistoryPaginatedUseCase getHistory;
  final RelocatePalletUseCase relocatePallet;
  final WatchRealtimeTransferChangesUseCase watchRealtimeChanges;

  RackTransferUseCases(IRackTransferRepository repository)
    : getAllSlots = GetAllSlotsForTransferUseCase(repository),
      getHistory = GetRelocationHistoryPaginatedUseCase(repository),
      relocatePallet = RelocatePalletUseCase(repository),
      watchRealtimeChanges = WatchRealtimeTransferChangesUseCase(repository);
}
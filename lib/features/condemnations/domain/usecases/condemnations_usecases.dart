import '../../../../core/error/error_handler.dart';
import '../entities/condemnations_entities.dart';
import '../repositories/i_condemnations_repository.dart';

class GetActiveCondemnationAlertsUseCase {
  final ICondemnationsRepository _repository;
  const GetActiveCondemnationAlertsUseCase(this._repository);

  Future<({
    List<CondemnationAlertItemEntity> alertItems,
    int globalThresholdDays,
    int userCustomAlertDays,
  })> call() => _repository.getActiveCondemnationAlerts();
}

class GetCondemnationRecordsUseCase {
  final ICondemnationsRepository _repository;
  const GetCondemnationRecordsUseCase(this._repository);

  Future<List<CondemnationHistoryRecordEntity>> call({
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 300,
  }) async {
    if (fromDate != null && toDate != null && toDate.isBefore(fromDate)) {
      throw const AppFailure(
        message: 'تاريخ النهاية (إلى تاريخ) يجب أن يكون بعد أو يساوي تاريخ البداية (من تاريخ).',
        type: FailureType.validationError,
      );
    }
    return _repository.getCondemnationRecords(
      fromDate: fromDate,
      toDate: toDate,
      limit: limit,
    );
  }
}

class ApproveItemCondemnationUseCase {
  final ICondemnationsRepository _repository;
  const ApproveItemCondemnationUseCase(this._repository);

  Future<void> call({
    required String palletItemId,
    required double availableQuantity,
    required double quantityToCondemn,
    required String reason,
  }) async {
    if (quantityToCondemn <= 0 || quantityToCondemn > availableQuantity) {
      throw AppFailure(
        message: 'الكمية المطلوب إعدامها ($quantityToCondemn) غير صحيحة أو أكبر من المتاح ($availableQuantity).',
        type: FailureType.validationError,
      );
    }
    return _repository.approveItemCondemnation(
      palletItemId: palletItemId,
      quantityToCondemn: quantityToCondemn,
      reason: reason.trim().isEmpty ? 'إعدام صلاحية معتمد' : reason.trim(),
    );
  }
}

class WatchRealtimeCondemnationChangesUseCase {
  final ICondemnationsRepository _repository;
  const WatchRealtimeCondemnationChangesUseCase(this._repository);

  Stream<void> call() => _repository.watchRealtimeCondemnationChanges();
}

/// حزمة UseCases مجمعة لموديول الإعدامات لسهولة حقنها في CondemnationsCubit
class CondemnationsUseCases {
  final GetActiveCondemnationAlertsUseCase getActiveAlerts;
  final GetCondemnationRecordsUseCase getHistoryRecords;
  final ApproveItemCondemnationUseCase approveCondemnation;
  final WatchRealtimeCondemnationChangesUseCase watchRealtimeChanges;

  CondemnationsUseCases(ICondemnationsRepository repository)
      : getActiveAlerts = GetActiveCondemnationAlertsUseCase(repository),
        getHistoryRecords = GetCondemnationRecordsUseCase(repository),
        approveCondemnation = ApproveItemCondemnationUseCase(repository),
        watchRealtimeChanges =
            WatchRealtimeCondemnationChangesUseCase(repository);
}
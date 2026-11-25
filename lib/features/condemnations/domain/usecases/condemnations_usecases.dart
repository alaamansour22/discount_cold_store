import '../../../../core/error/error_handler.dart';
import '../entities/condemnations_entities.dart';
import '../repositories/i_condemnations_repository.dart';

class GetCondemnationAlertsPaginatedUseCase {
  final ICondemnationsRepository _repository;
  const GetCondemnationAlertsPaginatedUseCase(this._repository);

  Future<CondemnationAlertsPageEntity> call(CondemnationAlertsFilter filter) {
    final normalized = filter.copyWith(
      page: filter.page < 1 ? 1 : filter.page,
      pageSize: filter.pageSize.clamp(1, 500),
      search: filter.search.trim(),
    );
    return _repository.getActiveAlertsPaginated(normalized);
  }
}

class GetCondemnationHistoryPaginatedUseCase {
  final ICondemnationsRepository _repository;
  const GetCondemnationHistoryPaginatedUseCase(this._repository);

  Future<CondemnationHistoryPageEntity> call(
    CondemnationHistoryFilter filter,
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
      pageSize: filter.pageSize.clamp(1, 1000),
      search: filter.search.trim(),
    );
    return _repository.getCondemnationHistoryPaginated(normalized);
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
    final cleanId = palletItemId.trim();
    if (cleanId.isEmpty) {
      throw const AppFailure(
        message: 'معرّف الصنف غير صحيح.',
        type: FailureType.validationError,
      );
    }
    if (quantityToCondemn <= 0 || quantityToCondemn > availableQuantity) {
      throw AppFailure(
        message:
            'الكمية المطلوب إعدامها ($quantityToCondemn) غير صحيحة أو أكبر من المتاح ($availableQuantity).',
        type: FailureType.validationError,
      );
    }
    final cleanReason = reason.trim().isEmpty
        ? 'إعدام صلاحية معتمد'
        : reason.trim();
    if (cleanReason.length > 500) {
      throw const AppFailure(
        message: 'سبب الإعدام أطول من الحد المسموح (500 حرف).',
        type: FailureType.validationError,
      );
    }

    return _repository.approveItemCondemnation(
      palletItemId: cleanId,
      quantityToCondemn: quantityToCondemn,
      reason: cleanReason,
    );
  }
}

class WatchRealtimeCondemnationChangesUseCase {
  final ICondemnationsRepository _repository;
  const WatchRealtimeCondemnationChangesUseCase(this._repository);

  Stream<void> call() => _repository.watchRealtimeCondemnationChanges();
}

/// حزمة UseCases مجمعة لموديول الإعدامات (توافق كامل مع InjectionContainer)
class CondemnationsUseCases {
  final GetCondemnationAlertsPaginatedUseCase getActiveAlerts;
  final GetCondemnationHistoryPaginatedUseCase getHistoryRecords;
  final ApproveItemCondemnationUseCase approveCondemnation;
  final WatchRealtimeCondemnationChangesUseCase watchRealtimeChanges;

  CondemnationsUseCases(ICondemnationsRepository repository)
    : getActiveAlerts = GetCondemnationAlertsPaginatedUseCase(repository),
      getHistoryRecords = GetCondemnationHistoryPaginatedUseCase(repository),
      approveCondemnation = ApproveItemCondemnationUseCase(repository),
      watchRealtimeChanges = WatchRealtimeCondemnationChangesUseCase(
        repository,
      );
}
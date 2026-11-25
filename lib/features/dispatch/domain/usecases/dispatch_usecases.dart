import '../../../../core/error/error_handler.dart';
import '../entities/dispatch_entities.dart';
import '../repositories/i_dispatch_repository.dart';

class DispatchUseCases {
  final IDispatchRepository repository;

  const DispatchUseCases(this.repository);

  Future<DispatchAvailablePalletsPageEntity> availablePallets(
    DispatchAvailablePalletsFilter filter,
  ) {
    final normalized = filter.copyWith(
      page: filter.page < 1 ? 1 : filter.page,
      pageSize: filter.pageSize.clamp(1, 200),
      search: filter.search.trim(),
    );
    return repository.getAvailablePalletsPaginated(normalized);
  }

  Future<DispatchDocumentsPageEntity> documents(
    DispatchDocumentsFilter filter,
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
    return repository.getDocumentsPaginated(normalized);
  }

  Future<List<DispatchDocumentLineEntity>> documentLines(String id) =>
      repository.getDocumentLines(id);

  Future<DispatchReversalReadinessEntity> checkReversalReadiness(String id) =>
      repository.checkReversalReadiness(id);

  Future<DispatchJsonMap> create(List<DispatchDraftLine> lines) async {
    if (lines.isEmpty) {
      throw const AppFailure(
        message: 'اختر صنفاً واحداً على الأقل قبل اعتماد إذن الصرف.',
        type: FailureType.validationError,
      );
    }
    final palletIds = lines.map((l) => l.item.palletId).toSet();
    if (palletIds.length > 50) {
      throw const AppFailure(
        message: 'الحد الأقصى 50 بالتة في مستند الصرف الواحد.',
        type: FailureType.validationError,
      );
    }
    for (final line in lines) {
      if (line.quantity <= 0 || line.quantity > line.item.quantity) {
        throw AppFailure(
          message: 'الكمية غير صحيحة للصنف (${line.item.itemName}).',
          type: FailureType.validationError,
        );
      }
    }
    return repository.createDocument(lines);
  }

  Future<void> reverse({
    required String documentId,
    required String reason,
    List<DispatchSlotAssignment> alternativeSlots = const [],
  }) async {
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) {
      throw const AppFailure(
        message: 'يرجى إدخال سبب التراجع عن مستند الصرف.',
        type: FailureType.validationError,
      );
    }
    if (cleanReason.length > 1000) {
      throw const AppFailure(
        message: 'سبب التراجع أطول من الحد المسموح (1000 حرف).',
        type: FailureType.validationError,
      );
    }
    return repository.reverseDocument(
      documentId: documentId,
      reason: cleanReason,
      alternativeSlots: alternativeSlots,
    );
  }

  Stream<void> watchRealtimeChanges() => repository.watchRealtimeChanges();
}
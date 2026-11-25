import '../entities/dispatch_entities.dart';

abstract class IDispatchRepository {
  Future<DispatchAvailablePalletsPageEntity> getAvailablePalletsPaginated(
    DispatchAvailablePalletsFilter filter,
  );

  Future<DispatchDocumentsPageEntity> getDocumentsPaginated(
    DispatchDocumentsFilter filter,
  );

  Future<List<DispatchDocumentLineEntity>> getDocumentLines(String documentId);

  Future<DispatchReversalReadinessEntity> checkReversalReadiness(
    String documentId,
  );

  Future<DispatchJsonMap> createDocument(List<DispatchDraftLine> lines);

  Future<void> reverseDocument({
    required String documentId,
    required String reason,
    List<DispatchSlotAssignment> alternativeSlots = const [],
  });

  Stream<void> watchRealtimeChanges();
}
import '../../../../core/error/error_handler.dart';
import '../../domain/entities/dispatch_entities.dart';
import '../../domain/repositories/i_dispatch_repository.dart';
import '../datasources/dispatch_remote_data_source.dart';

class DispatchRepositoryImpl implements IDispatchRepository {
  final IDispatchRemoteDataSource remote;

  DispatchRepositoryImpl(this.remote);

  @override
  Future<DispatchAvailablePalletsPageEntity> getAvailablePalletsPaginated(
    DispatchAvailablePalletsFilter filter,
  ) async {
    try {
      return await remote.fetchAvailablePalletsPaginated(filter);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<DispatchDocumentsPageEntity> getDocumentsPaginated(
    DispatchDocumentsFilter filter,
  ) async {
    try {
      return await remote.fetchDocumentsPaginated(filter);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<DispatchDocumentLineEntity>> getDocumentLines(String id) async {
    try {
      return await remote.getDocumentLines(id);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<DispatchReversalReadinessEntity> checkReversalReadiness(
    String id,
  ) async {
    try {
      return await remote.checkReversalReadiness(id);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<DispatchJsonMap> createDocument(
    List<DispatchDraftLine> lines,
  ) async {
    try {
      return await remote.createDocument(lines);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> reverseDocument({
    required String documentId,
    required String reason,
    List<DispatchSlotAssignment> alternativeSlots = const [],
  }) async {
    try {
      await remote.reverseDocument(
        documentId: documentId,
        reason: reason,
        alternativeSlots: alternativeSlots,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Stream<void> watchRealtimeChanges() => remote.subscribeToDispatchChanges();
}
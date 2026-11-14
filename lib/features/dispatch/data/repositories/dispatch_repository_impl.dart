import '../../domain/entities/dispatch_entities.dart';
import '../../domain/repositories/i_dispatch_repository.dart';
import '../../../receiving/domain/entities/receiving_entities.dart';
import '../datasources/dispatch_remote_data_source.dart';

class DispatchRepositoryImpl implements IDispatchRepository {
  final IDispatchRemoteDataSource remote;
  DispatchRepositoryImpl(this.remote);
  @override
  Future<List<ReceivingPalletItemEntity>> getAvailableItems() =>
      remote.getAvailableItems();
  @override
  Future<List<DispatchDocumentEntity>> getDocuments({int limit = 30}) =>
      remote.getDocuments(limit: limit);
  @override
  Future<List<DispatchDocumentLineEntity>> getDocumentLines(String id) =>
      remote.getDocumentLines(id);
  @override
  Future<Map<String, dynamic>> createDocument(List<DispatchDraftLine> lines) =>
      remote.createDocument(lines);
  @override
  Future<void> reverseDocument(String id, String reason) =>
      remote.reverseDocument(id, reason);
}

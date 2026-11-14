import '../entities/dispatch_entities.dart';
import '../../../receiving/domain/entities/receiving_entities.dart';

abstract class IDispatchRepository {
  Future<List<ReceivingPalletItemEntity>> getAvailableItems();
  Future<List<DispatchDocumentEntity>> getDocuments({int limit = 30});
  Future<List<DispatchDocumentLineEntity>> getDocumentLines(String documentId);
  Future<Map<String, dynamic>> createDocument(List<DispatchDraftLine> lines);
  Future<void> reverseDocument(String documentId, String reason);
}

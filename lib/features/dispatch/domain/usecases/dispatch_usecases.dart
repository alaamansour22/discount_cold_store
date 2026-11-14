import '../entities/dispatch_entities.dart';
import '../repositories/i_dispatch_repository.dart';

class DispatchUseCases {
  final IDispatchRepository repository;
  const DispatchUseCases(this.repository);
  Future<List<dynamic>> availableItems() => repository.getAvailableItems();
  Future<List<DispatchDocumentEntity>> documents() => repository.getDocuments();
  Future<List<DispatchDocumentLineEntity>> documentLines(String id) =>
      repository.getDocumentLines(id);
  Future<Map<String, dynamic>> create(List<DispatchDraftLine> lines) =>
      repository.createDocument(lines);
  Future<void> reverse(String id, String reason) =>
      repository.reverseDocument(id, reason);
}

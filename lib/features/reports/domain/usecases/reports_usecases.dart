import '../entities/report_entities.dart';
import '../repositories/i_reports_repository.dart';

class ReportsUseCases {
  final IReportsRepository _repository;

  ReportsUseCases(this._repository);

  Future<List<ReportRow>> getDispatchItems(ReportDateRange range) =>
      _repository.getDispatchItems(range);

  Future<List<ReportRow>> getDispatchDocuments(ReportDateRange range) =>
      _repository.getDispatchDocuments(range);

  Future<List<ReportRow>> getReceipts(ReportDateRange range) =>
      _repository.getReceipts(range);

  Future<List<ReportRow>> getCurrentInventory() =>
      _repository.getCurrentInventory();

  Future<List<ReportRow>> getItemBalances() => _repository.getItemBalances();

  Future<List<ReportRow>> getCondemnationHistory(ReportDateRange range) =>
      _repository.getCondemnationHistory(range);

  Future<int> getCondemnationThreshold() =>
      _repository.getCondemnationThreshold();

  Future<List<ReportRow>> getCondemnationAlerts(int threshold) =>
      _repository.getCondemnationAlerts(threshold);
}
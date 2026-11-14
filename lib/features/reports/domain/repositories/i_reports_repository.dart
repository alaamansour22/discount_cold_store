import '../entities/report_entities.dart';

abstract class IReportsRepository {
  Future<List<ReportRow>> getDispatchItems(ReportDateRange range);
  Future<List<ReportRow>> getDispatchDocuments(ReportDateRange range);
  Future<List<ReportRow>> getReceipts(ReportDateRange range);
  Future<List<ReportRow>> getCurrentInventory();
  Future<List<ReportRow>> getItemBalances();
  Future<List<ReportRow>> getCondemnationHistory(ReportDateRange range);
  Future<int> getCondemnationThreshold();
  Future<List<ReportRow>> getCondemnationAlerts(int threshold);
}
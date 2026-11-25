import '../entities/report_entities.dart';

abstract class IReportsRepository {
  Future<ReportPageEntity> getReportPaginated(ReportQueryParams params);
}
import '../../../../core/error/error_handler.dart';
import '../../domain/entities/report_entities.dart';
import '../../domain/repositories/i_reports_repository.dart';
import '../datasources/reports_remote_data_source.dart';

class ReportsRepositoryImpl implements IReportsRepository {
  final IReportsRemoteDataSource _remoteDataSource;

  ReportsRepositoryImpl(this._remoteDataSource);

  @override
  Future<ReportPageEntity> getReportPaginated(ReportQueryParams params) async {
    try {
      return await _remoteDataSource.fetchReportPaginated(params);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
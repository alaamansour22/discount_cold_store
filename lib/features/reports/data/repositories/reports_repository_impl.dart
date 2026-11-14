import '../../../../core/error/error_handler.dart';
import '../../domain/entities/report_entities.dart';
import '../../domain/repositories/i_reports_repository.dart';
import '../datasources/reports_remote_data_source.dart';

class ReportsRepositoryImpl implements IReportsRepository {
  final IReportsRemoteDataSource _remoteDataSource;

  ReportsRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<ReportRow>> getDispatchItems(ReportDateRange range) async {
    try {
      return await _remoteDataSource.fetchDispatchItems(range);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<ReportRow>> getDispatchDocuments(ReportDateRange range) async {
    try {
      return await _remoteDataSource.fetchDispatchDocuments(range);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<ReportRow>> getReceipts(ReportDateRange range) async {
    try {
      return await _remoteDataSource.fetchReceipts(range);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<ReportRow>> getCurrentInventory() async {
    try {
      return await _remoteDataSource.fetchCurrentInventory();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<ReportRow>> getItemBalances() async {
    try {
      return await _remoteDataSource.fetchItemBalances();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<ReportRow>> getCondemnationHistory(ReportDateRange range) async {
    try {
      return await _remoteDataSource.fetchCondemnationHistory(range);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<int> getCondemnationThreshold() async {
    try {
      return await _remoteDataSource.fetchCondemnationThreshold();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<ReportRow>> getCondemnationAlerts(int threshold) async {
    try {
      return await _remoteDataSource.fetchCondemnationAlerts(threshold);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
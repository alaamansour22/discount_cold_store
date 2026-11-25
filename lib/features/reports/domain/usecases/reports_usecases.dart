import '../../../../core/error/error_handler.dart';
import '../entities/report_entities.dart';
import '../repositories/i_reports_repository.dart';

class ReportsUseCases {
  final IReportsRepository _repository;

  const ReportsUseCases(this._repository);

  Future<ReportPageEntity> getReportPaginated(ReportQueryParams params) async {
    if (params.fromDate != null &&
        params.toDate != null &&
        params.toDate!.isBefore(params.fromDate!)) {
      throw const AppFailure(
        message: 'تاريخ النهاية يجب أن يكون بعد أو يساوي تاريخ البداية.',
        type: FailureType.validationError,
      );
    }

    final normalized = params.copyWith(
      page: params.page < 1 ? 1 : params.page,
      pageSize: params.pageSize.clamp(1, 5000),
      search: params.search.trim(),
    );

    return _repository.getReportPaginated(normalized);
  }
}
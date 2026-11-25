import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/entities/report_entities.dart';
import '../../domain/usecases/reports_usecases.dart';
import 'reports_state.dart';

class ReportsCubit extends Cubit<ReportsState> {
  final ReportsUseCases _useCases;

  ReportsCubit(this._useCases) : super(const ReportsState());

  Future<ReportPageEntity> fetchReportPage(ReportQueryParams params) async {
    if (isClosed) {
      throw StateError('ReportsCubit is closed');
    }
    emit(state.copyWith(isLoading: true, clearFailure: true));
    try {
      final result = await _useCases.getReportPaginated(params);
      if (!isClosed) {
        emit(state.copyWith(isLoading: false, lastReport: result));
      }
      return result;
    } catch (e) {
      final failure = ErrorHandler.handle(e);
      if (!isClosed) {
        emit(state.copyWith(isLoading: false, failure: failure));
      }
      throw failure;
    }
  }

  /// جلب كافة الصفوف المطابقة لتصدير PDF كامل (حتى 5000 سجل من PostgreSQL)
  Future<ReportPageEntity> fetchReportForPrint(ReportQueryParams params) {
    return fetchReportPage(params.copyWith(page: 1, pageSize: 5000));
  }
}
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/report_entities.dart';
import '../../domain/usecases/reports_usecases.dart';
import 'reports_state.dart';

class ReportsCubit extends Cubit<ReportsState> {
  final ReportsUseCases _useCases;

  ReportsCubit(this._useCases) : super(const ReportsState());

  Future<List<ReportRow>> _run(
    Future<List<ReportRow>> Function() request,
  ) async {
    if (isClosed) throw StateError('ReportsCubit is closed');
    emit(state.copyWith(isLoading: true, clearFailure: true));
    try {
      final records = await request();
      if (!isClosed) {
        emit(state.copyWith(isLoading: false, records: records));
      }
      return records;
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(isLoading: false, failure: e.toString()));
      }
      rethrow;
    }
  }

  Future<List<ReportRow>> getDispatchItems(ReportDateRange range) =>
      _run(() => _useCases.getDispatchItems(range));

  Future<List<ReportRow>> getDispatchDocuments(ReportDateRange range) =>
      _run(() => _useCases.getDispatchDocuments(range));

  Future<List<ReportRow>> getReceipts(ReportDateRange range) =>
      _run(() => _useCases.getReceipts(range));

  Future<List<ReportRow>> getCurrentInventory() =>
      _run(_useCases.getCurrentInventory);

  Future<List<ReportRow>> getItemBalances() => _run(_useCases.getItemBalances);

  Future<List<ReportRow>> getCondemnationHistory(ReportDateRange range) =>
      _run(() => _useCases.getCondemnationHistory(range));

  Future<int> getCondemnationThreshold() =>
      _useCases.getCondemnationThreshold();

  Future<List<ReportRow>> getCondemnationAlerts(int threshold) =>
      _run(() => _useCases.getCondemnationAlerts(threshold));
}
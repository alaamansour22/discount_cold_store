import 'package:equatable/equatable.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/entities/report_entities.dart';

class ReportsState extends Equatable {
  final bool isLoading;
  final AppFailure? failure;
  final ReportPageEntity? lastReport;

  const ReportsState({
    this.isLoading = false,
    this.failure,
    this.lastReport,
  });

  ReportsState copyWith({
    bool? isLoading,
    AppFailure? failure,
    bool clearFailure = false,
    ReportPageEntity? lastReport,
  }) {
    return ReportsState(
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
      lastReport: lastReport ?? this.lastReport,
    );
  }

  @override
  List<Object?> get props => [isLoading, failure, lastReport];
}
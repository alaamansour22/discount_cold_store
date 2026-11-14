import 'package:equatable/equatable.dart';

import '../../domain/entities/report_entities.dart';

class ReportsState extends Equatable {
  final bool isLoading;
  final String? failure;
  final List<ReportRow> records;

  const ReportsState({
    this.isLoading = false,
    this.failure,
    this.records = const [],
  });

  ReportsState copyWith({
    bool? isLoading,
    String? failure,
    bool clearFailure = false,
    List<ReportRow>? records,
  }) => ReportsState(
    isLoading: isLoading ?? this.isLoading,
    failure: clearFailure ? null : (failure ?? this.failure),
    records: records ?? this.records,
  );

  @override
  List<Object?> get props => [isLoading, failure, records];
}

import 'package:equatable/equatable.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/entities/condemnations_entities.dart';

class CondemnationsState extends Equatable {
  final bool isLoading;
  final bool isSubmitting;
  final List<CondemnationAlertItemEntity> alertItems;
  final List<CondemnationHistoryRecordEntity> historyRecords;
  final int globalThresholdDays;
  final int userCustomAlertDays;
  final DateTime? fromDateFilter;
  final DateTime? toDateFilter;
  final String sourceFilter; // 'ALL' | 'production' | 'quality_inspection'
  final AppFailure? failure;
  final String? successMessage;

  const CondemnationsState({
    this.isLoading = true,
    this.isSubmitting = false,
    this.alertItems = const [],
    this.historyRecords = const [],
    this.globalThresholdDays = 7,
    this.userCustomAlertDays = 7,
    this.fromDateFilter,
    this.toDateFilter,
    this.sourceFilter = 'ALL',
    this.failure,
    this.successMessage,
  });

  List<CondemnationHistoryRecordEntity> get sourceFilteredHistory {
    if (sourceFilter == 'ALL') return historyRecords;
    return historyRecords.where((r) => r.sourceDb == sourceFilter).toList();
  }

  CondemnationsState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<CondemnationAlertItemEntity>? alertItems,
    List<CondemnationHistoryRecordEntity>? historyRecords,
    int? globalThresholdDays,
    int? userCustomAlertDays,
    DateTime? fromDateFilter,
    bool clearFromDate = false,
    DateTime? toDateFilter,
    bool clearToDate = false,
    String? sourceFilter,
    AppFailure? failure,
    bool clearFailure = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return CondemnationsState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      alertItems: alertItems ?? this.alertItems,
      historyRecords: historyRecords ?? this.historyRecords,
      globalThresholdDays: globalThresholdDays ?? this.globalThresholdDays,
      userCustomAlertDays: userCustomAlertDays ?? this.userCustomAlertDays,
      fromDateFilter: clearFromDate
          ? null
          : (fromDateFilter ?? this.fromDateFilter),
      toDateFilter: clearToDate ? null : (toDateFilter ?? this.toDateFilter),
      sourceFilter: sourceFilter ?? this.sourceFilter,
      failure: clearFailure ? null : (failure ?? this.failure),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isSubmitting,
    alertItems,
    historyRecords,
    globalThresholdDays,
    userCustomAlertDays,
    fromDateFilter,
    toDateFilter,
    sourceFilter,
    failure,
    successMessage,
  ];
}

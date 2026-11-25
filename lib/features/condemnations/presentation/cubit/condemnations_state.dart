import 'package:equatable/equatable.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/entities/condemnations_entities.dart';

class CondemnationsState extends Equatable {
  // تبويب الأصناف المستحقة للإعدام (Server-Side Pagination)
  final bool isAlertsLoading;
  final bool alertsInitialized;
  final CondemnationAlertsPageEntity alertsData;
  final CondemnationAlertsFilter alertsFilter;

  // تبويب سجل الإعدامات المعتمدة (Server-Side Pagination)
  final bool isHistoryLoading;
  final bool historyInitialized;
  final CondemnationHistoryPageEntity historyData;
  final CondemnationHistoryFilter historyFilter;

  // تنفيذ الاعتماد والرسائل
  final bool isSubmitting;
  final AppFailure? failure;
  final String? successMessage;

  const CondemnationsState({
    this.isAlertsLoading = false,
    this.alertsInitialized = false,
    this.alertsData = const CondemnationAlertsPageEntity.empty(),
    this.alertsFilter = const CondemnationAlertsFilter(),
    this.isHistoryLoading = false,
    this.historyInitialized = false,
    this.historyData = const CondemnationHistoryPageEntity.empty(),
    this.historyFilter = const CondemnationHistoryFilter(),
    this.isSubmitting = false,
    this.failure,
    this.successMessage,
  });

  CondemnationsState copyWith({
    bool? isAlertsLoading,
    bool? alertsInitialized,
    CondemnationAlertsPageEntity? alertsData,
    CondemnationAlertsFilter? alertsFilter,
    bool? isHistoryLoading,
    bool? historyInitialized,
    CondemnationHistoryPageEntity? historyData,
    CondemnationHistoryFilter? historyFilter,
    bool? isSubmitting,
    AppFailure? failure,
    bool clearFailure = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return CondemnationsState(
      isAlertsLoading: isAlertsLoading ?? this.isAlertsLoading,
      alertsInitialized: alertsInitialized ?? this.alertsInitialized,
      alertsData: alertsData ?? this.alertsData,
      alertsFilter: alertsFilter ?? this.alertsFilter,
      isHistoryLoading: isHistoryLoading ?? this.isHistoryLoading,
      historyInitialized: historyInitialized ?? this.historyInitialized,
      historyData: historyData ?? this.historyData,
      historyFilter: historyFilter ?? this.historyFilter,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : (failure ?? this.failure),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
    isAlertsLoading,
    alertsInitialized,
    alertsData,
    alertsFilter,
    isHistoryLoading,
    historyInitialized,
    historyData,
    historyFilter,
    isSubmitting,
    failure,
    successMessage,
  ];
}
import 'package:equatable/equatable.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/entities/dispatch_entities.dart';

class DispatchState extends Equatable {
  // حالة البالتات المتاحة للصرف (Server-Side Pagination)
  final bool isPalletsLoading;
  final bool palletsInitialized;
  final DispatchAvailablePalletsPageEntity palletsData;
  final DispatchAvailablePalletsFilter palletsFilter;

  // حالة سجل مستندات الصرف (Server-Side Pagination)
  final bool isDocsLoading;
  final bool docsInitialized;
  final DispatchDocumentsPageEntity docsData;
  final DispatchDocumentsFilter docsFilter;

  // تفاصيل البنود المحمّلة لكل مستند
  final Map<String, List<DispatchDocumentLineEntity>> details;
  final Set<String> loadingDetailIds;

  // العمليات الفورية والرسائل
  final bool submitting;
  final AppFailure? failure;
  final String? success;

  const DispatchState({
    this.isPalletsLoading = false,
    this.palletsInitialized = false,
    this.palletsData = const DispatchAvailablePalletsPageEntity.empty(),
    this.palletsFilter = const DispatchAvailablePalletsFilter(),
    this.isDocsLoading = false,
    this.docsInitialized = false,
    this.docsData = const DispatchDocumentsPageEntity.empty(),
    this.docsFilter = const DispatchDocumentsFilter(),
    this.details = const {},
    this.loadingDetailIds = const {},
    this.submitting = false,
    this.failure,
    this.success,
  });

  DispatchState copyWith({
    bool? isPalletsLoading,
    bool? palletsInitialized,
    DispatchAvailablePalletsPageEntity? palletsData,
    DispatchAvailablePalletsFilter? palletsFilter,
    bool? isDocsLoading,
    bool? docsInitialized,
    DispatchDocumentsPageEntity? docsData,
    DispatchDocumentsFilter? docsFilter,
    Map<String, List<DispatchDocumentLineEntity>>? details,
    Set<String>? loadingDetailIds,
    bool? submitting,
    AppFailure? failure,
    bool clearFailure = false,
    String? success,
    bool clearSuccess = false,
  }) {
    return DispatchState(
      isPalletsLoading: isPalletsLoading ?? this.isPalletsLoading,
      palletsInitialized: palletsInitialized ?? this.palletsInitialized,
      palletsData: palletsData ?? this.palletsData,
      palletsFilter: palletsFilter ?? this.palletsFilter,
      isDocsLoading: isDocsLoading ?? this.isDocsLoading,
      docsInitialized: docsInitialized ?? this.docsInitialized,
      docsData: docsData ?? this.docsData,
      docsFilter: docsFilter ?? this.docsFilter,
      details: details ?? this.details,
      loadingDetailIds: loadingDetailIds ?? this.loadingDetailIds,
      submitting: submitting ?? this.submitting,
      failure: clearFailure ? null : (failure ?? this.failure),
      success: clearSuccess ? null : (success ?? this.success),
    );
  }

  @override
  List<Object?> get props => [
    isPalletsLoading,
    palletsInitialized,
    palletsData,
    palletsFilter,
    isDocsLoading,
    docsInitialized,
    docsData,
    docsFilter,
    details,
    loadingDetailIds,
    submitting,
    failure,
    success,
  ];
}
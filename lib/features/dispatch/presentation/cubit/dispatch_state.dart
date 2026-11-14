import 'package:equatable/equatable.dart';

import '../../domain/entities/dispatch_entities.dart';
import '../../../receiving/domain/entities/receiving_entities.dart';

class DispatchState extends Equatable {
  final bool loading, submitting;
  final List<ReceivingPalletItemEntity> availableItems;
  final List<DispatchDocumentEntity> documents;
  final String? error, success;
  final Map<String, List<DispatchDocumentLineEntity>> details;
  const DispatchState({
    this.loading = false,
    this.submitting = false,
    this.availableItems = const [],
    this.documents = const [],
    this.error,
    this.success,
    this.details = const {},
  });
  DispatchState copyWith({
    bool? loading,
    bool? submitting,
    List<ReceivingPalletItemEntity>? availableItems,
    List<DispatchDocumentEntity>? documents,
    String? error,
    String? success,
    Map<String, List<DispatchDocumentLineEntity>>? details,
    bool clearError = false,
    bool clearSuccess = false,
  }) => DispatchState(
    loading: loading ?? this.loading,
    submitting: submitting ?? this.submitting,
    availableItems: availableItems ?? this.availableItems,
    documents: documents ?? this.documents,
    error: clearError ? null : (error ?? this.error),
    success: clearSuccess ? null : (success ?? this.success),
    details: details ?? this.details,
  );
  @override
  List<Object?> get props => [
    loading,
    submitting,
    availableItems,
    documents,
    error,
    success,
    details,
  ];
}

import 'package:equatable/equatable.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/entities/movements_log_entities.dart';

class MovementsLogState extends Equatable {
  final bool isLoading;
  final bool initialized;
  final MovementsLogPageEntity data;
  final MovementsLogFilter filter;
  final AppFailure? failure;

  const MovementsLogState({
    this.isLoading = true,
    this.initialized = false,
    this.data = const MovementsLogPageEntity.empty(),
    this.filter = const MovementsLogFilter(),
    this.failure,
  });

  MovementsLogState copyWith({
    bool? isLoading,
    bool? initialized,
    MovementsLogPageEntity? data,
    MovementsLogFilter? filter,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return MovementsLogState(
      isLoading: isLoading ?? this.isLoading,
      initialized: initialized ?? this.initialized,
      data: data ?? this.data,
      filter: filter ?? this.filter,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [isLoading, initialized, data, filter, failure];
}
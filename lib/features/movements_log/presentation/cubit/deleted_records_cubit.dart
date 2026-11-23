import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/entities/deleted_record_entity.dart';
import '../../domain/usecases/movements_log_usecases.dart';

class DeletedRecordsState extends Equatable {
  final bool isLoading;
  final List<DeletedRecordEntity> records;
  final DateTime? fromDate;
  final DateTime? toDate;
  final DeletedActionKind? kindFilter;
  final AppFailure? failure;

  const DeletedRecordsState({
    this.isLoading = true,
    this.records = const [],
    this.fromDate,
    this.toDate,
    this.kindFilter,
    this.failure,
  });

  DeletedRecordsState copyWith({
    bool? isLoading,
    List<DeletedRecordEntity>? records,
    DateTime? fromDate,
    bool clearFromDate = false,
    DateTime? toDate,
    bool clearToDate = false,
    DeletedActionKind? kindFilter,
    bool clearKindFilter = false,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return DeletedRecordsState(
      isLoading: isLoading ?? this.isLoading,
      records: records ?? this.records,
      fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
      kindFilter: clearKindFilter ? null : (kindFilter ?? this.kindFilter),
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    records,
    fromDate,
    toDate,
    kindFilter,
    failure,
  ];
}

class DeletedRecordsCubit extends Cubit<DeletedRecordsState> {
  final MovementsLogUseCases _useCases;
  StreamSubscription<void>? _realtimeSub;

  DeletedRecordsCubit(this._useCases) : super(const DeletedRecordsState()) {
    loadRecords();
    _realtimeSub = _useCases.watchRealtimeDeletedRecords().listen((_) {
      if (!isClosed) {
        loadRecords(silent: true);
      }
    });
  }

  Future<void> loadRecords({bool silent = false}) async {
    if (isClosed) return;
    if (!silent) {
      emit(state.copyWith(isLoading: true, clearFailure: true));
    }
    try {
      final list = await _useCases.getDeletedRecords(
        fromDate: state.fromDate,
        toDate: state.toDate,
        kindFilter: state.kindFilter,
      );
      if (isClosed) return;
      emit(
        state.copyWith(isLoading: false, records: list, clearFailure: true),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, failure: ErrorHandler.handle(e)));
    }
  }

  Future<void> applyFilters({
    DateTime? fromDate,
    bool clearFromDate = false,
    DateTime? toDate,
    bool clearToDate = false,
    DeletedActionKind? kindFilter,
    bool clearKindFilter = false,
  }) async {
    if (isClosed) return;
    emit(
      state.copyWith(
        isLoading: true,
        fromDate: fromDate,
        clearFromDate: clearFromDate,
        toDate: toDate,
        clearToDate: clearToDate,
        kindFilter: kindFilter,
        clearKindFilter: clearKindFilter,
        clearFailure: true,
      ),
    );
    await loadRecords(silent: true);
  }

  @override
  Future<void> close() {
    _realtimeSub?.cancel();
    return super.close();
  }
}
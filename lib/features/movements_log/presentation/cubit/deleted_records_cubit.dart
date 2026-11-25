import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/entities/deleted_record_entity.dart';
import '../../domain/usecases/movements_log_usecases.dart';

class DeletedRecordsState extends Equatable {
  final bool isLoading;
  final bool initialized;
  final DeletedRecordsPageEntity data;
  final DeletedRecordsFilter filter;
  final AppFailure? failure;

  const DeletedRecordsState({
    this.isLoading = true,
    this.initialized = false,
    this.data = const DeletedRecordsPageEntity.empty(),
    this.filter = const DeletedRecordsFilter(),
    this.failure,
  });

  DeletedRecordsState copyWith({
    bool? isLoading,
    bool? initialized,
    DeletedRecordsPageEntity? data,
    DeletedRecordsFilter? filter,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return DeletedRecordsState(
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

class DeletedRecordsCubit extends Cubit<DeletedRecordsState> {
  final MovementsLogUseCases _useCases;
  StreamSubscription<void>? _realtimeSub;
  int _requestSeq = 0;

  DeletedRecordsCubit(this._useCases) : super(const DeletedRecordsState()) {
    loadRecords();
    _realtimeSub = _useCases.watchRealtimeDeletedRecords().listen((_) {
      if (!isClosed) {
        loadRecords(silent: true);
      }
    });
  }

  Future<void> loadRecords({
    DeletedRecordsFilter? filter,
    bool silent = false,
  }) async {
    if (isClosed) {
      return;
    }
    final targetFilter = filter ?? state.filter;
    final seq = ++_requestSeq;

    if (!silent) {
      emit(
        state.copyWith(
          isLoading: true,
          filter: targetFilter,
          clearFailure: true,
        ),
      );
    }

    try {
      final result = await _useCases.getDeletedRecords(targetFilter);
      if (isClosed || seq != _requestSeq) {
        return;
      }

      if (targetFilter.page > result.page.totalPages &&
          result.page.totalPages >= 1) {
        await loadRecords(
          filter: targetFilter.copyWith(page: result.page.totalPages),
          silent: silent,
        );
        return;
      }

      emit(
        state.copyWith(
          isLoading: false,
          initialized: true,
          filter: targetFilter,
          data: result,
          clearFailure: true,
        ),
      );
    } catch (e) {
      if (isClosed || seq != _requestSeq) {
        return;
      }
      emit(
        state.copyWith(
          isLoading: false,
          initialized: true,
          failure: ErrorHandler.handle(e),
        ),
      );
    }
  }

  Future<void> updateFilter(DeletedRecordsFilter nextFilter) =>
      loadRecords(filter: nextFilter.copyWith(page: 1));

  Future<void> goToPage(int page) =>
      loadRecords(filter: state.filter.copyWith(page: page));

  Future<void> changePageSize(int pageSize) =>
      loadRecords(filter: state.filter.copyWith(page: 1, pageSize: pageSize));

  Future<void> clearFilters() => loadRecords(
    filter: DeletedRecordsFilter(pageSize: state.filter.pageSize),
  );

  Future<DeletedRecordsPageEntity> fetchForExport() {
    return _useCases.getDeletedRecords(
      state.filter.copyWith(page: 1, pageSize: 500),
    );
  }

  @override
  Future<void> close() {
    _realtimeSub?.cancel();
    return super.close();
  }
}
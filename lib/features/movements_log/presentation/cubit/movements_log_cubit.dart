import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/entities/movements_log_entities.dart';
import '../../domain/usecases/movements_log_usecases.dart';
import 'movements_log_state.dart';

class MovementsLogCubit extends Cubit<MovementsLogState> {
  final MovementsLogUseCases _useCases;
  StreamSubscription<void>? _realtimeSub;
  int _requestSeq = 0;

  MovementsLogCubit(this._useCases) : super(const MovementsLogState()) {
    loadMovements();
    _realtimeSub = _useCases.watchRealtime().listen((_) {
      if (!isClosed) {
        loadMovements(silent: true);
      }
    });
  }

  Future<void> loadMovements({
    MovementsLogFilter? filter,
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
      final result = await _useCases.getMovements(targetFilter);
      if (isClosed || seq != _requestSeq) {
        return;
      }

      if (targetFilter.page > result.page.totalPages &&
          result.page.totalPages >= 1) {
        await loadMovements(
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

  Future<void> updateFilter(MovementsLogFilter nextFilter) =>
      loadMovements(filter: nextFilter.copyWith(page: 1));

  Future<void> goToPage(int page) =>
      loadMovements(filter: state.filter.copyWith(page: page));

  Future<void> changePageSize(int pageSize) =>
      loadMovements(filter: state.filter.copyWith(page: 1, pageSize: pageSize));

  Future<void> clearFilters() => loadMovements(
    filter: MovementsLogFilter(pageSize: state.filter.pageSize),
  );

  Future<MovementsLogPageEntity> fetchForExport() {
    return _useCases.getMovements(state.filter.copyWith(page: 1, pageSize: 1000));
  }

  @override
  Future<void> close() {
    _realtimeSub?.cancel();
    return super.close();
  }
}
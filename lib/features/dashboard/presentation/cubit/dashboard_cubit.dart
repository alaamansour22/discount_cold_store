import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/entities/dashboard_stats_entity.dart';
import '../../domain/usecases/dashboard_usecases.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final DashboardUseCases _useCases;
  StreamSubscription<void>? _realtimeSub;
  Timer? _debounceTimer;
  int _statsRequestSeq = 0;
  int _notificationsRequestSeq = 0;

  DashboardCubit(this._useCases) : super(const DashboardState()) {
    loadDashboard();
    _realtimeSub = _useCases.watchRealtimeChanges().listen((_) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (!isClosed) {
          loadDashboard(silent: true);
        }
      });
    });
  }

  Future<void> loadDashboard({bool silent = false}) async {
    if (isClosed) {
      return;
    }
    final seq = ++_statsRequestSeq;

    if (!silent) {
      emit(state.copyWith(isLoading: true, clearFailure: true));
    } else {
      emit(state.copyWith(isRefreshing: true));
    }

    try {
      final stats = await _useCases.getStats();
      if (isClosed || seq != _statsRequestSeq) {
        return;
      }

      emit(
        state.copyWith(
          isLoading: false,
          isRefreshing: false,
          stats: stats,
          lastUpdated: DateTime.now(),
          clearFailure: true,
        ),
      );

      if (state.notificationsInitialized) {
        unawaited(loadNotifications(silent: true));
      }
    } catch (e) {
      if (isClosed || seq != _statsRequestSeq) {
        return;
      }
      emit(
        state.copyWith(
          isLoading: false,
          isRefreshing: false,
          failure: ErrorHandler.handle(e),
        ),
      );
    }
  }

  Future<void> loadNotifications({
    DashboardNotificationsFilter? filter,
    bool silent = false,
  }) async {
    if (isClosed) {
      return;
    }
    final targetFilter = filter ?? state.notificationsFilter;
    final seq = ++_notificationsRequestSeq;

    if (!silent) {
      emit(
        state.copyWith(
          isNotificationsLoading: true,
          notificationsFilter: targetFilter,
          clearFailure: true,
        ),
      );
    }

    try {
      final result = await _useCases.getNotifications(targetFilter);
      if (isClosed || seq != _notificationsRequestSeq) {
        return;
      }

      if (targetFilter.page > result.page.totalPages &&
          result.page.totalPages >= 1) {
        await loadNotifications(
          filter: targetFilter.copyWith(page: result.page.totalPages),
          silent: silent,
        );
        return;
      }

      emit(
        state.copyWith(
          isNotificationsLoading: false,
          notificationsInitialized: true,
          notificationsFilter: targetFilter,
          notificationsData: result,
          clearFailure: true,
        ),
      );
    } catch (e) {
      if (isClosed || seq != _notificationsRequestSeq) {
        return;
      }
      emit(
        state.copyWith(
          isNotificationsLoading: false,
          notificationsInitialized: true,
          failure: ErrorHandler.handle(e),
        ),
      );
    }
  }

  Future<void> toggleUnreadOnly(bool unreadOnly) => loadNotifications(
    filter: state.notificationsFilter.copyWith(page: 1, unreadOnly: unreadOnly),
  );

  Future<void> goToNotificationsPage(int page) => loadNotifications(
    filter: state.notificationsFilter.copyWith(page: page),
  );

  Future<void> markAllNotificationsRead() async {
    if (isClosed) {
      return;
    }
    try {
      await _useCases.markAllNotificationsRead();
      if (isClosed) {
        return;
      }
      await Future.wait([
        loadDashboard(silent: true),
        loadNotifications(silent: true),
      ]);
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(failure: ErrorHandler.handle(e)));
      }
    }
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    _realtimeSub?.cancel();
    return super.close();
  }
}
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/usecases/dashboard_usecases.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final DashboardUseCases _useCases;
  StreamSubscription<void>? _realtimeSub;
  Timer? _debounceTimer;

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
    if (!silent) {
      emit(state.copyWith(isLoading: true, clearFailure: true));
    } else {
      emit(state.copyWith(isRefreshing: true));
    }
    try {
      final results = await Future.wait([
        _useCases.getStats(),
        _useCases.getNotifications(),
      ]);
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          isRefreshing: false,
          stats: results[0] as dynamic,
          notifications: results[1] as dynamic,
          lastUpdated: DateTime.now(),
          clearFailure: true,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          isRefreshing: false,
          failure: ErrorHandler.handle(e),
        ),
      );
    }
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await _useCases.markAllNotificationsRead();
      await loadDashboard(silent: true);
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
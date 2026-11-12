import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/error_handler.dart';
import '../../domain/usecases/dashboard_usecases.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final DashboardUseCases _useCases;
  StreamSubscription<void>? _realtimeSub;

  DashboardCubit(this._useCases) : super(const DashboardState()) {
    loadDashboard();
    _realtimeSub = _useCases.watchRealtimeChanges().listen((_) {
      loadDashboard(silent: true);
    });
  }

  Future<void> loadDashboard({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(isLoading: true, clearFailure: true));
    }
    try {
      final stats = await _useCases.getStats();
      final notifications = await _useCases.getNotifications();
      emit(state.copyWith(
        isLoading: false,
        stats: stats,
        notifications: notifications,
        clearFailure: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        failure: ErrorHandler.handle(e),
      ));
    }
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await _useCases.markAllNotificationsRead();
      await loadDashboard(silent: true);
    } catch (e) {
      emit(state.copyWith(failure: ErrorHandler.handle(e)));
    }
  }

  @override
  Future<void> close() {
    _realtimeSub?.cancel();
    return super.close();
  }
}
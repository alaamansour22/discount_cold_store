import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/usecases/settings_usecases.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final SettingsUseCases _useCases;

  SettingsCubit(this._useCases) : super(const SettingsState()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    emit(
      state.copyWith(isLoading: true, clearFailure: true, clearSuccess: true),
    );
    try {
      final settings = await _useCases.getSettings();
      emit(
        state.copyWith(
          isLoading: false,
          settings: settings,
          clearFailure: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, failure: ErrorHandler.handle(e)));
    }
  }

  Future<void> saveNotificationSettings({
    required int globalThresholdDays,
    required int userCustomAlertDays,
    required bool notificationsEnabled,
    required bool receiveMondayAlert,
  }) async {
    emit(
      state.copyWith(
        isSubmitting: true,
        clearFailure: true,
        clearSuccess: true,
      ),
    );
    try {
      final updated = await _useCases.saveSettings(
        globalThresholdDays: globalThresholdDays,
        userCustomAlertDays: userCustomAlertDays,
        notificationsEnabled: notificationsEnabled,
        receiveMondayAlert: receiveMondayAlert,
      );
      emit(
        state.copyWith(
          isSubmitting: false,
          settings: updated,
          successMessage:
              'تم حفظ إعدادات التنبيه قبل الإعدام ($userCustomAlertDays أيام) وتحديث الإشعارات بنجاح',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(isSubmitting: false, failure: ErrorHandler.handle(e)),
      );
    }
  }
}

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/entities/create_user_params.dart';
import '../../domain/usecases/settings_usecases.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final SettingsUseCases _useCases;

  SettingsCubit(this._useCases) : super(const SettingsState()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    if (isClosed) return;
    emit(
      state.copyWith(isLoading: true, clearFailure: true, clearSuccess: true),
    );
    try {
      final settings = await _useCases.getSettings();
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          settings: settings,
          clearFailure: true,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, failure: ErrorHandler.handle(e)));
    }
  }

  Future<void> saveNotificationSettings({
    required int globalThresholdDays,
    required int userCustomAlertDays,
    required bool notificationsEnabled,
    required bool receiveMondayAlert,
  }) async {
    if (isClosed) return;
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
      if (isClosed) return;
      emit(
        state.copyWith(
          isSubmitting: false,
          settings: updated,
          successMessage:
              'تم حفظ إعدادات التنبيه قبل الإعدام ($userCustomAlertDays أيام) وتحديث الإشعارات بنجاح',
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(isSubmitting: false, failure: ErrorHandler.handle(e)),
      );
    }
  }

  /// تعيد null عند النجاح، أو رسالة الخطأ لعرضها مباشرة داخل نافذة إضافة المستخدم
  Future<String?> createUser(CreateUserParams params) async {
    if (isClosed) return 'تعذر تنفيذ العملية حالياً.';
    emit(
      state.copyWith(
        isSubmitting: true,
        clearFailure: true,
        clearSuccess: true,
      ),
    );
    try {
      await _useCases.createUser(params);
      if (isClosed) return null;
      emit(
        state.copyWith(
          isSubmitting: false,
          successMessage:
              'تم إضافة المستخدم (${params.fullName.trim()}) بصلاحية (${params.role.arLabel}) بنجاح',
        ),
      );
      return null;
    } catch (e) {
      final failure = ErrorHandler.handle(e);
      if (!isClosed) {
        emit(state.copyWith(isSubmitting: false));
      }
      return failure.message;
    }
  }

  /// تعيد null عند النجاح، أو رسالة الخطأ لعرضها مباشرة داخل نافذة تأكيد الحذف
  Future<String?> deleteUser({
    required String userId,
    required String fullName,
    required String reason,
  }) async {
    if (isClosed) return 'تعذر تنفيذ العملية حالياً.';
    emit(
      state.copyWith(
        isSubmitting: true,
        clearFailure: true,
        clearSuccess: true,
      ),
    );
    try {
      final mode = await _useCases.deleteUser(
        userId: userId,
        reason: reason,
      );
      if (isClosed) return null;
      final msg = mode == UserDeletionMode.hardDeleted
          ? 'تم حذف حساب الموظف ($fullName) نهائياً بنجاح'
          : 'الموظف ($fullName) لديه حركات مخزنية مسجلة؛ تم إيقاف حسابه وسحب صلاحياته ومنعه من الدخول نهائياً مع حفظ سجل الحركات';
      emit(
        state.copyWith(
          isSubmitting: false,
          successMessage: msg,
        ),
      );
      return null;
    } catch (e) {
      final failure = ErrorHandler.handle(e);
      if (!isClosed) {
        emit(state.copyWith(isSubmitting: false));
      }
      return failure.message;
    }
  }
}
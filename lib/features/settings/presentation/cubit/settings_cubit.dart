import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_handler.dart';
import '../../domain/entities/admin_user_entity.dart';
import '../../domain/entities/create_user_params.dart';
import '../../domain/usecases/settings_usecases.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final SettingsUseCases _useCases;
  int _usersRequestSeq = 0;

  SettingsCubit(this._useCases) : super(const SettingsState()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    if (isClosed) {
      return;
    }
    emit(
      state.copyWith(isLoading: true, clearFailure: true, clearSuccess: true),
    );
    try {
      final settings = await _useCases.getSettings();
      if (isClosed) {
        return;
      }
      emit(
        state.copyWith(
          isLoading: false,
          settings: settings,
          clearFailure: true,
        ),
      );
    } catch (e) {
      if (isClosed) {
        return;
      }
      emit(state.copyWith(isLoading: false, failure: ErrorHandler.handle(e)));
    }
  }

  Future<void> saveNotificationSettings({
    required int globalThresholdDays,
    required int userCustomAlertDays,
    required bool notificationsEnabled,
    required bool receiveMondayAlert,
  }) async {
    if (isClosed) {
      return;
    }
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
      if (isClosed) {
        return;
      }
      emit(
        state.copyWith(
          isSubmitting: false,
          settings: updated,
          successMessage:
              'تم حفظ إعدادات التنبيه قبل الإعدام ($userCustomAlertDays أيام) وتحديث الإشعارات بنجاح',
        ),
      );
    } catch (e) {
      if (isClosed) {
        return;
      }
      emit(
        state.copyWith(isSubmitting: false, failure: ErrorHandler.handle(e)),
      );
    }
  }

  // ==================== إدارة المستخدمين للأدمن (Server-Side Pagination) ====================

  Future<void> ensureAdminUsersLoaded() async {
    if (!state.usersInitialized && !state.isUsersLoading) {
      await loadAdminUsers();
    }
  }

  Future<void> loadAdminUsers({
    AdminUsersFilter? filter,
    bool silent = false,
  }) async {
    if (isClosed) {
      return;
    }
    final targetFilter = filter ?? state.usersFilter;
    final seq = ++_usersRequestSeq;

    if (!silent) {
      emit(
        state.copyWith(
          isUsersLoading: true,
          usersFilter: targetFilter,
          clearUsersFailure: true,
        ),
      );
    }

    try {
      final result = await _useCases.getAdminUsers(targetFilter);
      if (isClosed || seq != _usersRequestSeq) {
        return;
      }

      if (targetFilter.page > result.page.totalPages &&
          result.page.totalPages >= 1) {
        await loadAdminUsers(
          filter: targetFilter.copyWith(page: result.page.totalPages),
          silent: silent,
        );
        return;
      }

      emit(
        state.copyWith(
          isUsersLoading: false,
          usersInitialized: true,
          usersFilter: targetFilter,
          usersData: result,
          clearUsersFailure: true,
        ),
      );
    } catch (e) {
      if (isClosed || seq != _usersRequestSeq) {
        return;
      }
      emit(
        state.copyWith(
          isUsersLoading: false,
          usersInitialized: true,
          usersFailure: ErrorHandler.handle(e),
        ),
      );
    }
  }

  Future<void> updateUsersFilter(AdminUsersFilter nextFilter) =>
      loadAdminUsers(filter: nextFilter.copyWith(page: 1));

  Future<void> goToUsersPage(int page) =>
      loadAdminUsers(filter: state.usersFilter.copyWith(page: page));

  Future<void> changeUsersPageSize(int pageSize) => loadAdminUsers(
    filter: state.usersFilter.copyWith(page: 1, pageSize: pageSize),
  );

  Future<void> clearUsersFilters() => loadAdminUsers(
    filter: AdminUsersFilter(pageSize: state.usersFilter.pageSize),
  );

  Future<void> toggleDispatchReversalPermission({
    required AdminUserEntity user,
    required bool grant,
  }) async {
    if (isClosed || state.updatingUserIds.contains(user.id)) {
      return;
    }

    final nextUpdating = Set<String>.from(state.updatingUserIds)..add(user.id);
    emit(
      state.copyWith(
        updatingUserIds: nextUpdating,
        clearFailure: true,
        clearSuccess: true,
      ),
    );

    final actionLabel = grant ? 'منح' : 'سحب';
    try {
      await _useCases.setDispatchReversalPermission(
        profileId: user.id,
        grant: grant,
      );
      if (isClosed) {
        return;
      }
      await loadAdminUsers(silent: true);
      if (isClosed) {
        return;
      }
      final doneUpdating = Set<String>.from(state.updatingUserIds)
        ..remove(user.id);
      emit(
        state.copyWith(
          updatingUserIds: doneUpdating,
          successMessage:
              'تم $actionLabel صلاحية عكس الصرف للمستخدم ${user.fullName}',
        ),
      );
    } catch (e) {
      if (isClosed) {
        return;
      }
      final doneUpdating = Set<String>.from(state.updatingUserIds)
        ..remove(user.id);
      emit(
        state.copyWith(
          updatingUserIds: doneUpdating,
          failure: ErrorHandler.handle(e),
        ),
      );
    }
  }

  /// تعيد null عند النجاح، أو رسالة الخطأ لعرضها مباشرة داخل نافذة إضافة المستخدم
  Future<String?> createUser(CreateUserParams params) async {
    if (isClosed) {
      return 'تعذر تنفيذ العملية حالياً.';
    }
    emit(
      state.copyWith(
        isSubmitting: true,
        clearFailure: true,
        clearSuccess: true,
      ),
    );
    try {
      await _useCases.createUser(params);
      if (isClosed) {
        return null;
      }
      if (state.usersInitialized) {
        await loadAdminUsers(silent: true);
      }
      if (isClosed) {
        return null;
      }
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
    if (isClosed) {
      return 'تعذر تنفيذ العملية حالياً.';
    }
    emit(
      state.copyWith(
        isSubmitting: true,
        clearFailure: true,
        clearSuccess: true,
      ),
    );
    try {
      final mode = await _useCases.deleteUser(userId: userId, reason: reason);
      if (isClosed) {
        return null;
      }
      if (state.usersInitialized) {
        await loadAdminUsers(silent: true);
      }
      if (isClosed) {
        return null;
      }
      final msg = mode == UserDeletionMode.hardDeleted
          ? 'تم حذف حساب الموظف ($fullName) نهائياً بنجاح'
          : 'الموظف ($fullName) لديه حركات مخزنية مسجلة؛ تم إيقاف حسابه وسحب صلاحياته ومنعه من الدخول نهائياً مع حفظ سجل الحركات';
      emit(state.copyWith(isSubmitting: false, successMessage: msg));
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
import '../../../../core/error/error_handler.dart';
import '../entities/admin_user_entity.dart';
import '../entities/create_user_params.dart';
import '../entities/notification_settings_entity.dart';
import '../repositories/i_settings_repository.dart';

class GetSettingsUseCase {
  final ISettingsRepository _repository;
  const GetSettingsUseCase(this._repository);

  Future<NotificationSettingsEntity> call() => _repository.getSettings();
}

class SaveNotificationSettingsUseCase {
  final ISettingsRepository _repository;
  const SaveNotificationSettingsUseCase(this._repository);

  Future<NotificationSettingsEntity> call({
    required int globalThresholdDays,
    required int userCustomAlertDays,
    required bool notificationsEnabled,
    required bool receiveMondayAlert,
  }) async {
    if (globalThresholdDays < 1 || globalThresholdDays > 365) {
      throw const AppFailure(
        message: 'مدة حساب الإعدامات العامة يجب أن تكون بين 1 و 365 يوماً.',
        type: FailureType.validationError,
      );
    }
    if (userCustomAlertDays < 1 || userCustomAlertDays > 365) {
      throw const AppFailure(
        message:
            'مدة التنبيه الشخصي قبل الإعدام يجب أن تكون بين 1 و 365 يوماً.',
        type: FailureType.validationError,
      );
    }

    return _repository.saveNotificationSettings(
      globalThresholdDays: globalThresholdDays,
      userCustomAlertDays: userCustomAlertDays,
      notificationsEnabled: notificationsEnabled,
      receiveMondayAlert: receiveMondayAlert,
    );
  }
}

class GetAdminUsersPaginatedUseCase {
  final ISettingsRepository _repository;
  const GetAdminUsersPaginatedUseCase(this._repository);

  Future<AdminUsersPageEntity> call(AdminUsersFilter filter) {
    final normalized = filter.copyWith(
      page: filter.page < 1 ? 1 : filter.page,
      pageSize: filter.pageSize.clamp(1, 100),
      search: filter.search.trim(),
    );
    return _repository.getAdminUsersPaginated(normalized);
  }
}

class SetDispatchReversalPermissionUseCase {
  final ISettingsRepository _repository;
  const SetDispatchReversalPermissionUseCase(this._repository);

  Future<void> call({
    required String profileId,
    required bool grant,
  }) async {
    final cleanId = profileId.trim();
    if (cleanId.isEmpty) {
      throw const AppFailure(
        message: 'معرّف الموظف غير صحيح.',
        type: FailureType.validationError,
      );
    }
    return _repository.setDispatchReversalPermission(
      profileId: cleanId,
      grant: grant,
    );
  }
}

class CreateUserUseCase {
  final ISettingsRepository _repository;
  const CreateUserUseCase(this._repository);

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<void> call(CreateUserParams params) async {
    final fullName = params.fullName.trim();
    final employeeCode = params.employeeCode.trim();
    final email = params.email.trim().toLowerCase();
    final password = params.password;

    if (fullName.length < 2 || fullName.length > 120) {
      throw const AppFailure(
        message: 'يرجى إدخال اسم الموظف بالكامل (حرفين على الأقل).',
        type: FailureType.validationError,
      );
    }
    if (employeeCode.isEmpty || employeeCode.length > 40) {
      throw const AppFailure(
        message: 'يرجى إدخال كود الموظف بشكل صحيح.',
        type: FailureType.validationError,
      );
    }
    if (!_emailRegex.hasMatch(email)) {
      throw const AppFailure(
        message: 'يرجى إدخال بريد إلكتروني صحيح.',
        type: FailureType.validationError,
      );
    }
    if (password.length < 6 || password.length > 72) {
      throw const AppFailure(
        message: 'كلمة المرور يجب أن تكون بين 6 و 72 حرفاً.',
        type: FailureType.validationError,
      );
    }

    return _repository.createUser(
      CreateUserParams(
        fullName: fullName,
        employeeCode: employeeCode,
        email: email,
        password: password,
        role: params.role,
        grantDispatchReversal: params.grantDispatchReversal,
      ),
    );
  }
}

class DeleteUserUseCase {
  final ISettingsRepository _repository;
  const DeleteUserUseCase(this._repository);

  Future<UserDeletionMode> call({
    required String userId,
    required String reason,
  }) async {
    final cleanId = userId.trim();
    final cleanReason = reason.trim();

    if (cleanId.isEmpty) {
      throw const AppFailure(
        message: 'معرّف المستخدم غير صحيح.',
        type: FailureType.validationError,
      );
    }
    if (cleanReason.isEmpty) {
      throw const AppFailure(
        message: 'يرجى كتابة سبب حذف الحساب.',
        type: FailureType.validationError,
      );
    }
    if (cleanReason.length > 500) {
      throw const AppFailure(
        message: 'سبب الحذف أطول من الحد المسموح (500 حرف).',
        type: FailureType.validationError,
      );
    }

    return _repository.deleteUser(userId: cleanId, reason: cleanReason);
  }
}

/// حزمة UseCases مجمعة لموديول الإعدادات لسهولة حقنها في SettingsCubit
class SettingsUseCases {
  final GetSettingsUseCase getSettings;
  final SaveNotificationSettingsUseCase saveSettings;
  final GetAdminUsersPaginatedUseCase getAdminUsers;
  final SetDispatchReversalPermissionUseCase setDispatchReversalPermission;
  final CreateUserUseCase createUser;
  final DeleteUserUseCase deleteUser;

  SettingsUseCases(ISettingsRepository repository)
    : getSettings = GetSettingsUseCase(repository),
      saveSettings = SaveNotificationSettingsUseCase(repository),
      getAdminUsers = GetAdminUsersPaginatedUseCase(repository),
      setDispatchReversalPermission = SetDispatchReversalPermissionUseCase(
        repository,
      ),
      createUser = CreateUserUseCase(repository),
      deleteUser = DeleteUserUseCase(repository);
}
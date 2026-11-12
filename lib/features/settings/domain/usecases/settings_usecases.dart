import '../../../../core/error/error_handler.dart';
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
        message: 'مدة التنبيه الشخصي قبل الإعدام يجب أن تكون بين 1 و 365 يوماً.',
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

/// حزمة UseCases مجمعة لموديول الإعدادات لسهولة حقنها في SettingsCubit
class SettingsUseCases {
  final GetSettingsUseCase getSettings;
  final SaveNotificationSettingsUseCase saveSettings;

  SettingsUseCases(ISettingsRepository repository)
      : getSettings = GetSettingsUseCase(repository),
        saveSettings = SaveNotificationSettingsUseCase(repository);
}
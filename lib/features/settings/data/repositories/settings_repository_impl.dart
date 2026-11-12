import '../../../../core/error/error_handler.dart';
import '../../domain/entities/notification_settings_entity.dart';
import '../../domain/repositories/i_settings_repository.dart';
import '../datasources/settings_remote_data_source.dart';

class SettingsRepositoryImpl implements ISettingsRepository {
  final ISettingsRemoteDataSource _remoteDataSource;

  SettingsRepositoryImpl(this._remoteDataSource);

  @override
  Future<NotificationSettingsEntity> getSettings() async {
    try {
      return await _remoteDataSource.fetchSettings();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<NotificationSettingsEntity> saveNotificationSettings({
    required int globalThresholdDays,
    required int userCustomAlertDays,
    required bool notificationsEnabled,
    required bool receiveMondayAlert,
  }) async {
    try {
      return await _remoteDataSource.updateSettings(
        globalThresholdDays: globalThresholdDays,
        userCustomAlertDays: userCustomAlertDays,
        notificationsEnabled: notificationsEnabled,
        receiveMondayAlert: receiveMondayAlert,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
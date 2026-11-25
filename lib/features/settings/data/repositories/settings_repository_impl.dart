import '../../../../core/error/error_handler.dart';
import '../../domain/entities/admin_user_entity.dart';
import '../../domain/entities/create_user_params.dart';
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

  @override
  Future<AdminUsersPageEntity> getAdminUsersPaginated(
    AdminUsersFilter filter,
  ) async {
    try {
      return await _remoteDataSource.fetchAdminUsersPaginated(filter);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> setDispatchReversalPermission({
    required String profileId,
    required bool grant,
  }) async {
    try {
      await _remoteDataSource.rpcSetDispatchReversalPermission(
        profileId: profileId,
        grant: grant,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> createUser(CreateUserParams params) async {
    try {
      await _remoteDataSource.rpcAdminCreateUser(params);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<UserDeletionMode> deleteUser({
    required String userId,
    required String reason,
  }) async {
    try {
      return await _remoteDataSource.rpcAdminDeleteUser(
        userId: userId,
        reason: reason,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
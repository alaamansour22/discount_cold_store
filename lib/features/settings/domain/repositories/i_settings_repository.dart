import '../entities/admin_user_entity.dart';
import '../entities/create_user_params.dart';
import '../entities/notification_settings_entity.dart';

abstract class ISettingsRepository {
  /// جلب إعدادات مدة الإعدامات العامة للثلاجة + إعدادات التنبيه الشخصية للمستخدم
  Future<NotificationSettingsEntity> getSettings();

  /// حفظ التعديلات عبر rpc_save_notification_settings
  Future<NotificationSettingsEntity> saveNotificationSettings({
    required int globalThresholdDays,
    required int userCustomAlertDays,
    required bool notificationsEnabled,
    required bool receiveMondayAlert,
  });

  /// جلب قائمة الموظفين بالبحث والفلاتر والباجينيشن للأدمن فقط عبر rpc_admin_list_users_paginated
  Future<AdminUsersPageEntity> getAdminUsersPaginated(AdminUsersFilter filter);

  /// منح أو سحب صلاحية عكس مستندات الصرف لموظف
  Future<void> setDispatchReversalPermission({
    required String profileId,
    required bool grant,
  });

  /// إنشاء مستخدم جديد بصلاحياته (متاح لمدير النظام فقط عبر rpc_admin_create_user)
  Future<void> createUser(CreateUserParams params);

  /// حذف حساب موظف أو إيقافه نهائياً إذا كان لديه تاريخ تشغيلي (عبر rpc_admin_delete_user)
  Future<UserDeletionMode> deleteUser({
    required String userId,
    required String reason,
  });
}
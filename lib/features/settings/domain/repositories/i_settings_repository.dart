import '../entities/notification_settings_entity.dart';

abstract class ISettingsRepository {
  /// جلب إعدادات مدة الإعدامات العامة للثلاجة + إعدادات التنبيه الشخصية للمستخدم
  Future<NotificationSettingsEntity> getSettings();

  /// حفظ التعديلات وتحديث محرك إشعارات الصلاحية فوراً عبر الدالة الذرية rpc_update_user_notification_settings
  Future<NotificationSettingsEntity> saveNotificationSettings({
    required int globalThresholdDays,
    required int userCustomAlertDays,
    required bool notificationsEnabled,
    required bool receiveMondayAlert,
  });
}

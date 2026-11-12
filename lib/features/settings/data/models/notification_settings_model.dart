import '../../domain/entities/notification_settings_entity.dart';

typedef SettingsJsonMap = Map<String, dynamic>;

class NotificationSettingsModel extends NotificationSettingsEntity {
  const NotificationSettingsModel({
    required super.globalThresholdDays,
    required super.userCustomAlertDays,
    required super.notificationsEnabled,
    required super.receiveMondayAlert,
  });

  factory NotificationSettingsModel.fromJson({
    required SettingsJsonMap globalJson,
    SettingsJsonMap? profileJson,
  }) {
    final globalDays =
        (globalJson['condemnation_threshold_days'] as num?)?.toInt() ?? 7;

    return NotificationSettingsModel(
      globalThresholdDays: globalDays,
      userCustomAlertDays:
          (profileJson?['custom_alert_days'] as num?)?.toInt() ?? globalDays,
      notificationsEnabled:
          profileJson?['notifications_enabled'] as bool? ?? true,
      receiveMondayAlert:
          profileJson?['receive_monday_alert'] as bool? ?? true,
    );
  }
}
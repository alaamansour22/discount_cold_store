import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_settings_model.dart';

abstract class ISettingsRemoteDataSource {
  Future<NotificationSettingsModel> fetchSettings();

  Future<NotificationSettingsModel> updateSettings({
    required int globalThresholdDays,
    required int userCustomAlertDays,
    required bool notificationsEnabled,
    required bool receiveMondayAlert,
  });
}

class SettingsRemoteDataSourceImpl implements ISettingsRemoteDataSource {
  final SupabaseClient _supabase;

  SettingsRemoteDataSourceImpl(this._supabase);

  @override
  Future<NotificationSettingsModel> fetchSettings() async {
    final userId = _supabase.auth.currentUser?.id;

    final globalRes = await _supabase
        .from('cold_storage_settings')
        .select('condemnation_threshold_days')
        .eq('id', 1)
        .single();

    SettingsJsonMap? profileMap;
    if (userId != null) {
      final profileRes = await _supabase
          .from('profiles')
          .select('custom_alert_days, notifications_enabled, receive_monday_alert')
          .eq('id', userId)
          .maybeSingle();
      if (profileRes != null) {
        profileMap = SettingsJsonMap.from(profileRes as Map);
      }
    }

    return NotificationSettingsModel.fromJson(
      globalJson: SettingsJsonMap.from(globalRes as Map),
      profileJson: profileMap,
    );
  }

  @override
  Future<NotificationSettingsModel> updateSettings({
    required int globalThresholdDays,
    required int userCustomAlertDays,
    required bool notificationsEnabled,
    required bool receiveMondayAlert,
  }) async {
    final userId = _supabase.auth.currentUser?.id;

    // 1. تحديث الحد العام للثلاجة
    await _supabase.from('cold_storage_settings').update({
      'condemnation_threshold_days': globalThresholdDays,
      'updated_by': userId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', 1);

    // 2. استدعاء الدالة الذرية rpc_update_user_notification_settings لتحديث تنبيه المستخدم وإعادة تقييم الإشعارات فوراً
    await _supabase.rpc('rpc_update_user_notification_settings', params: {
      'p_custom_alert_days': userCustomAlertDays,
      'p_notifications_enabled': notificationsEnabled,
    });

    // 3. تحديث خيار تقرير يوم الإثنين الأسبوعي في جدول profiles
    if (userId != null) {
      await _supabase.from('profiles').update({
        'receive_monday_alert': receiveMondayAlert,
      }).eq('id', userId);
    }

    return fetchSettings();
  }
}
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/create_user_params.dart';
import '../models/notification_settings_model.dart';

abstract class ISettingsRemoteDataSource {
  Future<NotificationSettingsModel> fetchSettings();

  Future<NotificationSettingsModel> updateSettings({
    required int globalThresholdDays,
    required int userCustomAlertDays,
    required bool notificationsEnabled,
    required bool receiveMondayAlert,
  });

  Future<void> rpcAdminCreateUser(CreateUserParams params);

  Future<UserDeletionMode> rpcAdminDeleteUser({
    required String userId,
    required String reason,
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
          .select(
            'custom_alert_days, notifications_enabled, receive_monday_alert',
          )
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

    await _supabase
        .from('cold_storage_settings')
        .update({
          'condemnation_threshold_days': globalThresholdDays,
          'updated_by': userId,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', 1);

    await _supabase.rpc(
      'rpc_update_user_notification_settings',
      params: {
        'p_custom_alert_days': userCustomAlertDays,
        'p_notifications_enabled': notificationsEnabled,
      },
    );

    if (userId != null) {
      await _supabase
          .from('profiles')
          .update({'receive_monday_alert': receiveMondayAlert})
          .eq('id', userId);
    }

    return fetchSettings();
  }

  @override
  Future<void> rpcAdminCreateUser(CreateUserParams params) async {
    await _supabase.rpc(
      'rpc_admin_create_user',
      params: {
        'p_full_name': params.fullName.trim(),
        'p_employee_code': params.employeeCode.trim(),
        'p_email': params.email.trim().toLowerCase(),
        'p_password': params.password,
        'p_role': params.role.dbValue,
        'p_grant_dispatch_reversal': params.grantDispatchReversal,
      },
    );
  }

  @override
  Future<UserDeletionMode> rpcAdminDeleteUser({
    required String userId,
    required String reason,
  }) async {
    final res = await _supabase.rpc(
      'rpc_admin_delete_user',
      params: {
        'p_target_user_id': userId.trim(),
        'p_reason': reason.trim(),
      },
    );
    if (res is Map) {
      return UserDeletionMode.fromDb(res['deletion_mode']?.toString());
    }
    return UserDeletionMode.hardDeleted;
  }
}
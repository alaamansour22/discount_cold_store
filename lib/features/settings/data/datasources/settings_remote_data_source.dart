import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/pagination/paged_result.dart';
import '../../domain/entities/admin_user_entity.dart';
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

  Future<AdminUsersPageEntity> fetchAdminUsersPaginated(
    AdminUsersFilter filter,
  );

  Future<void> rpcSetDispatchReversalPermission({
    required String profileId,
    required bool grant,
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
        profileMap = SettingsJsonMap.from(profileRes);
      }
    }

    return NotificationSettingsModel.fromJson(
      globalJson: SettingsJsonMap.from(globalRes),
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
    final res = await _supabase.rpc(
      'rpc_save_notification_settings',
      params: {
        'p_global_threshold_days': globalThresholdDays,
        'p_custom_alert_days': userCustomAlertDays,
        'p_notifications_enabled': notificationsEnabled,
        'p_receive_monday_alert': receiveMondayAlert,
      },
    );

    if (res is Map) {
      final map = SettingsJsonMap.from(res);
      return NotificationSettingsModel.fromJson(
        globalJson: map,
        profileJson: map,
      );
    }

    return fetchSettings();
  }

  @override
  Future<AdminUsersPageEntity> fetchAdminUsersPaginated(
    AdminUsersFilter filter,
  ) async {
    final res = await _supabase.rpc(
      'rpc_admin_list_users_paginated',
      params: {
        'p_page': filter.page,
        'p_page_size': filter.pageSize,
        'p_search': filter.search.trim().isEmpty ? null : filter.search.trim(),
        'p_role': filter.role,
        'p_active_only': filter.activeOnly,
      },
    );

    if (res is! Map) {
      return const AdminUsersPageEntity.empty();
    }

    final map = AdminUserJsonMap.from(res);
    final paged = PagedResult<AdminUserEntity>.fromRpcJson(
      map,
      AdminUserEntity.fromJson,
    );

    final summaryMap = map['summary'] is Map
        ? AdminUserJsonMap.from(map['summary'] as Map)
        : const <String, dynamic>{};

    final summary = AdminUsersSummaryEntity(
      totalUsers:
          (summaryMap['total_users'] as num?)?.toInt() ?? paged.totalCount,
      activeCount: (summaryMap['active_count'] as num?)?.toInt() ?? 0,
      inactiveCount: (summaryMap['inactive_count'] as num?)?.toInt() ?? 0,
      dispatchReversalCount:
          (summaryMap['dispatch_reversal_count'] as num?)?.toInt() ?? 0,
    );

    return AdminUsersPageEntity(page: paged, summary: summary);
  }

  @override
  Future<void> rpcSetDispatchReversalPermission({
    required String profileId,
    required bool grant,
  }) async {
    await _supabase.rpc(
      grant ? 'rpc_grant_profile_permission' : 'rpc_revoke_profile_permission',
      params: {'p_profile_id': profileId.trim()},
    );
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
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/pagination/paged_result.dart';
import '../../domain/entities/dashboard_stats_entity.dart';

abstract class IDashboardRemoteDataSource {
  Future<DashboardStatsEntity> fetchStats();

  Future<DashboardNotificationsPageEntity> fetchNotificationsPaginated(
    DashboardNotificationsFilter filter,
  );

  Future<void> markAllNotificationsRead();

  Stream<void> subscribeToChanges();
}

class DashboardRemoteDataSourceImpl implements IDashboardRemoteDataSource {
  final SupabaseClient _supabase;

  DashboardRemoteDataSourceImpl(this._supabase);

  @override
  Future<DashboardStatsEntity> fetchStats() async {
    // طلب RPC واحد موحّد يُرجع كافة إحصائيات الرئيسية + الحرجة + أحدث الحركات + عداد الإشعارات
    final rpcRes = await _supabase.rpc('rpc_get_dashboard_overview');
    if (rpcRes is! Map) {
      return const DashboardStatsEntity();
    }

    final summary = DashboardJsonMap.from(rpcRes);
    final rawCritical = summary['critical_items'] as List? ?? const [];
    final rawMovements = summary['recent_movements'] as List? ?? const [];

    final criticalItems = [
      for (final raw in rawCritical)
        if (raw is Map)
          DashboardCriticalItemEntity.fromJson(DashboardJsonMap.from(raw)),
    ];

    final recentMovements = [
      for (final raw in rawMovements)
        if (raw is Map)
          DashboardRecentMovementEntity.fromJson(DashboardJsonMap.from(raw)),
    ];

    return DashboardStatsEntity(
      totalSlots: (summary['total_slots'] as num?)?.toInt() ?? 320,
      occupiedSlots: (summary['occupied_slots'] as num?)?.toInt() ?? 0,
      emptySlots: (summary['empty_slots'] as num?)?.toInt() ?? 320,
      zoneC2Total: (summary['zone_c2_total'] as num?)?.toInt() ?? 208,
      zoneC2Occupied: (summary['zone_c2_occupied'] as num?)?.toInt() ?? 0,
      zoneC3Total: (summary['zone_c3_total'] as num?)?.toInt() ?? 112,
      zoneC3Occupied: (summary['zone_c3_occupied'] as num?)?.toInt() ?? 0,
      mixedPalletsCount:
          (summary['mixed_pallets_count'] as num?)?.toInt() ?? 0,
      activeItemsCount: (summary['active_items_count'] as num?)?.toInt() ?? 0,
      nearExpiryAlertsCount:
          (summary['near_expiry_alerts_count'] as num?)?.toInt() ?? 0,
      expiredItemsCount:
          (summary['expired_items_count'] as num?)?.toInt() ?? 0,
      totalCondemnedRecordsCount:
          (summary['total_condemned_records_count'] as num?)?.toInt() ?? 0,
      todayMovementsCount:
          (summary['today_movements_count'] as num?)?.toInt() ?? 0,
      userAlertDays: (summary['user_alert_days'] as num?)?.toInt() ?? 7,
      unreadNotificationsCount:
          (summary['unread_notifications_count'] as num?)?.toInt() ?? 0,
      criticalItems: criticalItems,
      recentMovements: recentMovements,
    );
  }

  @override
  Future<DashboardNotificationsPageEntity> fetchNotificationsPaginated(
    DashboardNotificationsFilter filter,
  ) async {
    final res = await _supabase.rpc(
      'rpc_get_user_notifications_paginated',
      params: {
        'p_page': filter.page,
        'p_page_size': filter.pageSize,
        'p_unread_only': filter.unreadOnly,
      },
    );

    if (res is! Map) {
      return const DashboardNotificationsPageEntity.empty();
    }

    final map = DashboardJsonMap.from(res);
    final paged = PagedResult<DashboardNotificationEntity>.fromRpcJson(
      map,
      DashboardNotificationEntity.fromJson,
    );

    final summaryMap = map['summary'] is Map
        ? DashboardJsonMap.from(map['summary'] as Map)
        : const <String, dynamic>{};

    final summary = DashboardNotificationsSummaryEntity(
      totalNotifications:
          (summaryMap['total_notifications'] as num?)?.toInt() ??
          paged.totalCount,
      unreadCount: (summaryMap['unread_count'] as num?)?.toInt() ?? 0,
    );

    return DashboardNotificationsPageEntity(page: paged, summary: summary);
  }

  @override
  Future<void> markAllNotificationsRead() async {
    await _supabase.rpc('rpc_mark_notifications_read');
  }

  @override
  Stream<void> subscribeToChanges() {
    final controller = StreamController<void>.broadcast();
    final channel = _supabase
        .channel('dashboard_realtime_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rack_slots',
          callback: (_) => controller.add(null),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pallets',
          callback: (_) => controller.add(null),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pallet_items',
          callback: (_) => controller.add(null),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'condemnation_records',
          callback: (_) => controller.add(null),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_movements',
          callback: (_) => controller.add(null),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_notifications',
          callback: (_) => controller.add(null),
        )
        .subscribe();

    controller.onCancel = () {
      _supabase.removeChannel(channel);
    };
    return controller.stream;
  }
}
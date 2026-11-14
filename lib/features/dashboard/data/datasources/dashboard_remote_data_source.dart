import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/dashboard_stats_entity.dart';

typedef DashboardJson = Map<String, dynamic>;

abstract class IDashboardRemoteDataSource {
  Future<DashboardStatsEntity> fetchStats();
  Future<List<DashboardNotificationEntity>> fetchNotifications();
  Future<void> markAllNotificationsRead();
  Stream<void> subscribeToChanges();
}

class DashboardRemoteDataSourceImpl implements IDashboardRemoteDataSource {
  final SupabaseClient _supabase;

  DashboardRemoteDataSourceImpl(this._supabase);

  @override
  Future<DashboardStatsEntity> fetchStats() async {
    // جلب الملخص المجمع من الـ View/RPC + القوائم المختصرة بالتوازي
    final results = await Future.wait<dynamic>([
      _fetchAggregatedSummary(),
      _fetchCriticalItems(),
      _fetchRecentMovements(),
    ]);

    final summary = results[0] as DashboardJson;
    final criticalItems = results[1] as List<DashboardCriticalItemEntity>;
    final recentMovements = results[2] as List<DashboardRecentMovementEntity>;

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
      criticalItems: criticalItems,
      recentMovements: recentMovements,
    );
  }

  Future<DashboardJson> _fetchAggregatedSummary() async {
    try {
      final rpcRes = await _supabase.rpc('rpc_get_dashboard_overview');
      if (rpcRes is Map) {
        return DashboardJson.from(rpcRes);
      }
    } catch (_) {
      // Fallback متوازي ومحسّن في حال لم تُنشأ الدالة في قاعدة البيانات بعد
    }

    final userId = _supabase.auth.currentUser?.id;
    final todayStart = DateTime.now();
    final startOfDayIso = DateTime(
      todayStart.year,
      todayStart.month,
      todayStart.day,
    ).toIso8601String();

    final parallel = await Future.wait<dynamic>([
      _supabase
          .from('rack_slots')
          .select('zone_code, is_occupied')
          .eq('is_active', true),
      _supabase
          .from('pallets')
          .select('id')
          .eq('status', 'in_stock')
          .eq('is_mixed', true)
          .count(CountOption.exact),
      _supabase
          .from('v_active_pallet_items')
          .select('days_until_expiry, condemnation_health_status'),
      _supabase
          .from('condemnation_records')
          .select('id')
          .count(CountOption.exact),
      _supabase
          .from('inventory_movements')
          .select('id')
          .gte('created_at', startOfDayIso)
          .count(CountOption.exact),
      if (userId != null)
        _supabase
            .from('profiles')
            .select('custom_alert_days')
            .eq('id', userId)
            .maybeSingle()
      else
        Future.value(null),
    ]);

    final slotsList = parallel[0] as List;
    final mixedCount = (parallel[1] as PostgrestResponse).count;
    final itemsList = parallel[2] as List;
    final condemnCount = (parallel[3] as PostgrestResponse).count;
    final todayMovCount = (parallel[4] as PostgrestResponse).count;
    final profile = parallel[5] as Map<String, dynamic>?;

    final userAlertDays = (profile?['custom_alert_days'] as num?)?.toInt() ?? 7;

    int totalSlots = slotsList.length;
    int occupiedSlots = 0;
    int c2Total = 0;
    int c2Occupied = 0;
    int c3Total = 0;
    int c3Occupied = 0;

    for (final raw in slotsList) {
      final row = DashboardJson.from(raw as Map);
      final zone = row['zone_code'] as String? ?? 'C2';
      final isOcc = row['is_occupied'] as bool? ?? false;
      if (isOcc) occupiedSlots++;
      if (zone == 'C2') {
        c2Total++;
        if (isOcc) c2Occupied++;
      } else {
        c3Total++;
        if (isOcc) c3Occupied++;
      }
    }

    int nearExpiryCount = 0;
    int expiredCount = 0;
    for (final raw in itemsList) {
      final row = DashboardJson.from(raw as Map);
      final days = (row['days_until_expiry'] as num?)?.toInt() ?? 999;
      final status = row['condemnation_health_status'] as String? ?? 'healthy';
      if (days <= 0 || status == 'expired') {
        expiredCount++;
      } else if (days <= userAlertDays || status == 'due_for_condemnation') {
        nearExpiryCount++;
      }
    }

    return {
      'total_slots': totalSlots,
      'occupied_slots': occupiedSlots,
      'empty_slots': totalSlots - occupiedSlots,
      'zone_c2_total': c2Total,
      'zone_c2_occupied': c2Occupied,
      'zone_c3_total': c3Total,
      'zone_c3_occupied': c3Occupied,
      'mixed_pallets_count': mixedCount,
      'active_items_count': itemsList.length,
      'near_expiry_alerts_count': nearExpiryCount + expiredCount,
      'expired_items_count': expiredCount,
      'total_condemned_records_count': condemnCount,
      'today_movements_count': todayMovCount,
      'user_alert_days': userAlertDays,
    };
  }

  Future<List<DashboardCriticalItemEntity>> _fetchCriticalItems() async {
    try {
      final data = await _supabase
          .from('v_active_pallet_items')
          .select(
            'pallet_item_id, item_name, slot_code, quantity, unit, days_until_expiry, condemnation_health_status',
          )
          .order('days_until_expiry', ascending: true)
          .limit(6);

      return (data as List).map((raw) {
        final m = DashboardJson.from(raw as Map);
        return DashboardCriticalItemEntity(
          palletItemId: m['pallet_item_id']?.toString() ?? '',
          itemName: m['item_name'] as String? ?? '',
          slotCode: m['slot_code'] as String? ?? '',
          quantity: (m['quantity'] as num?)?.toDouble() ?? 0,
          unit: m['unit'] as String? ?? 'carton',
          daysUntilExpiry: (m['days_until_expiry'] as num?)?.toInt() ?? 0,
          healthStatus: m['condemnation_health_status'] as String? ?? 'healthy',
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<DashboardRecentMovementEntity>> _fetchRecentMovements() async {
    try {
      final data = await _supabase
          .from('inventory_movements')
          .select(
            'id, movement_type, item_name, quantity_changed, unit, from_slot_code, to_slot_code, created_at',
          )
          .order('created_at', ascending: false)
          .limit(6);

      return (data as List).map((raw) {
        final m = DashboardJson.from(raw as Map);
        return DashboardRecentMovementEntity(
          id: m['id']?.toString() ?? '',
          movementType: m['movement_type'] as String? ?? '',
          itemName: m['item_name'] as String? ?? '',
          quantityChanged: (m['quantity_changed'] as num?)?.toDouble() ?? 0,
          unit: m['unit'] as String? ?? 'carton',
          fromSlotCode: m['from_slot_code'] as String?,
          toSlotCode: m['to_slot_code'] as String?,
          createdAt:
              DateTime.tryParse(m['created_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<DashboardNotificationEntity>> fetchNotifications() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _supabase
        .from('user_notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(80);

    final list = data as List;
    return list.map((raw) {
      final map = DashboardJson.from(raw as Map);
      return DashboardNotificationEntity(
        id: map['id'] as String,
        notificationType: map['notification_type'] as String? ?? '',
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? '',
        slotCode: map['slot_code'] as String?,
        isRead: map['is_read'] as bool? ?? false,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      );
    }).toList();
  }

  @override
  Future<void> markAllNotificationsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _supabase
        .from('user_notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
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
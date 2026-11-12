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
    final userId = _supabase.auth.currentUser?.id;

    final slotsData = await _supabase
        .from('rack_slots')
        .select('zone_code, is_occupied');

    final palletsData = await _supabase
        .from('pallets')
        .select('id, is_mixed')
        .eq('status', 'in_stock');

    final activeItemsData = await _supabase
        .from('v_active_pallet_items')
        .select('days_until_expiry, condemnation_health_status');

    final condemnationsData = await _supabase
        .from('condemnation_records')
        .select('id');

    final todayStart = DateTime.now();
    final startOfDayIso =
        DateTime(todayStart.year, todayStart.month, todayStart.day)
            .toIso8601String();

    final todayMovementsData = await _supabase
        .from('inventory_movements')
        .select('id')
        .gte('created_at', startOfDayIso);

    int userAlertDays = 7;
    if (userId != null) {
      final profile = await _supabase
          .from('profiles')
          .select('custom_alert_days')
          .eq('id', userId)
          .maybeSingle();
      if (profile != null) {
        userAlertDays = (profile['custom_alert_days'] as num?)?.toInt() ?? 7;
      }
    }

    final slotsList = slotsData as List;
    final palletsList = palletsData as List;
    final itemsList = activeItemsData as List;
    final condemnList = condemnationsData as List;
    final todayMovList = todayMovementsData as List;

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

    int mixedCount = 0;
    for (final raw in palletsList) {
      final row = DashboardJson.from(raw as Map);
      if (row['is_mixed'] == true) mixedCount++;
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

    return DashboardStatsEntity(
      totalSlots: totalSlots,
      occupiedSlots: occupiedSlots,
      emptySlots: totalSlots - occupiedSlots,
      zoneC2Total: c2Total,
      zoneC2Occupied: c2Occupied,
      zoneC3Total: c3Total,
      zoneC3Occupied: c3Occupied,
      mixedPalletsCount: mixedCount,
      activeItemsCount: itemsList.length,
      nearExpiryAlertsCount: nearExpiryCount + expiredCount,
      expiredItemsCount: expiredCount,
      totalCondemnedRecordsCount: condemnList.length,
      todayMovementsCount: todayMovList.length,
      userAlertDays: userAlertDays,
    );
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
          table: 'pallet_items',
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
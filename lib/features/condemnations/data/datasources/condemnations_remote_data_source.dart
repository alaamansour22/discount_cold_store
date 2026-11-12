import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/condemnations_entities.dart';
import '../models/condemnations_models.dart';

class ActiveAlertsDto {
  final List<CondemnationAlertItemEntity> alertItems;
  final int globalThresholdDays;
  final int userCustomAlertDays;

  const ActiveAlertsDto({
    required this.alertItems,
    required this.globalThresholdDays,
    required this.userCustomAlertDays,
  });
}

abstract class ICondemnationsRemoteDataSource {
  Future<ActiveAlertsDto> fetchActiveAlertsAndThresholds();

  Future<List<CondemnationHistoryRecordEntity>> fetchCondemnationHistory({
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 300,
  });

  Future<void> rpcCondemnItem({
    required String palletItemId,
    required double quantityToCondemn,
    required String reason,
  });

  Stream<void> subscribeToCondemnationChanges();
}

class CondemnationsRemoteDataSourceImpl
    implements ICondemnationsRemoteDataSource {
  final SupabaseClient _supabase;

  CondemnationsRemoteDataSourceImpl(this._supabase);

  @override
  Future<ActiveAlertsDto> fetchActiveAlertsAndThresholds() async {
    final userId = _supabase.auth.currentUser?.id;

    final settingsRes = await _supabase
        .from('cold_storage_settings')
        .select('condemnation_threshold_days')
        .eq('id', 1)
        .single();

    final int globalDays =
        (settingsRes['condemnation_threshold_days'] as num?)?.toInt() ?? 7;

    int userDays = globalDays;
    if (userId != null) {
      final profileRes = await _supabase
          .from('profiles')
          .select('custom_alert_days')
          .eq('id', userId)
          .maybeSingle();
      if (profileRes != null) {
        userDays =
            (profileRes['custom_alert_days'] as num?)?.toInt() ?? globalDays;
      }
    }

    final int maxThreshold = globalDays > userDays ? globalDays : userDays;

    final activeRows = await _supabase
        .from('v_active_pallet_items')
        .select()
        .lte('days_until_expiry', maxThreshold)
        .order('days_until_expiry', ascending: true);

    final list = activeRows as List;
    final alertEntities = list
        .map((r) => CondemnationModelMapper.alertFromViewJson(
              CondemnJsonMap.from(r as Map),
            ))
        .toList();

    return ActiveAlertsDto(
      alertItems: alertEntities,
      globalThresholdDays: globalDays,
      userCustomAlertDays: userDays,
    );
  }

  @override
  Future<List<CondemnationHistoryRecordEntity>> fetchCondemnationHistory({
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 300,
  }) async {
    var query = _supabase
        .from('condemnation_records')
        .select('*, profiles(full_name)');

    if (fromDate != null) {
      final startOfDay =
          DateTime(fromDate.year, fromDate.month, fromDate.day).toIso8601String();
      query = query.gte('created_at', startOfDay);
    }

    if (toDate != null) {
      final endOfDay = DateTime(
        toDate.year,
        toDate.month,
        toDate.day,
        23,
        59,
        59,
      ).toIso8601String();
      query = query.lte('created_at', endOfDay);
    }

    final data = await query.order('created_at', ascending: false).limit(limit);
    final list = data as List;
    return list
        .map((r) => CondemnationModelMapper.historyFromJson(
              CondemnJsonMap.from(r as Map),
            ))
        .toList();
  }

  @override
  Future<void> rpcCondemnItem({
    required String palletItemId,
    required double quantityToCondemn,
    required String reason,
  }) async {
    await _supabase.rpc('rpc_adjust_or_release_item', params: {
      'p_pallet_item_id': palletItemId,
      'p_action': 'condemn',
      'p_target_quantity': quantityToCondemn,
      'p_notes': reason,
    });
  }

  @override
  Stream<void> subscribeToCondemnationChanges() {
    final controller = StreamController<void>.broadcast();
    final channel = _supabase
        .channel('condemnations_realtime_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'condemnation_records',
          callback: (_) => controller.add(null),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pallet_items',
          callback: (_) => controller.add(null),
        )
        .subscribe();

    controller.onCancel = () {
      _supabase.removeChannel(channel);
    };
    return controller.stream;
  }
}
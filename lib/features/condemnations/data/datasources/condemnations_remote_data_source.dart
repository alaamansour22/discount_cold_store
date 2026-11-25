import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/condemnations_entities.dart';
import '../models/condemnations_models.dart';

abstract class ICondemnationsRemoteDataSource {
  Future<CondemnationAlertsPageEntity> fetchAlertsPaginated(
    CondemnationAlertsFilter filter,
  );

  Future<CondemnationHistoryPageEntity> fetchHistoryPaginated(
    CondemnationHistoryFilter filter,
  );

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

  String? _dateOnly(DateTime? d) {
    if (d == null) {
      return null;
    }
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  Future<CondemnationAlertsPageEntity> fetchAlertsPaginated(
    CondemnationAlertsFilter filter,
  ) async {
    final res = await _supabase.rpc(
      'rpc_get_condemnation_alerts_paginated',
      params: {
        'p_page': filter.page,
        'p_page_size': filter.pageSize,
        'p_search': filter.search.trim().isEmpty ? null : filter.search.trim(),
        'p_status': filter.status,
      },
    );

    if (res is Map) {
      return CondemnationModelMapper.alertsPageFromRpcJson(
        CondemnJsonMap.from(res),
      );
    }
    return const CondemnationAlertsPageEntity.empty();
  }

  @override
  Future<CondemnationHistoryPageEntity> fetchHistoryPaginated(
    CondemnationHistoryFilter filter,
  ) async {
    final res = await _supabase.rpc(
      'rpc_get_condemnation_history_paginated',
      params: {
        'p_page': filter.page,
        'p_page_size': filter.pageSize,
        'p_search': filter.search.trim().isEmpty ? null : filter.search.trim(),
        'p_source': filter.source,
        'p_from_date': _dateOnly(filter.fromDate),
        'p_to_date': _dateOnly(filter.toDate),
      },
    );

    if (res is Map) {
      return CondemnationModelMapper.historyPageFromRpcJson(
        CondemnJsonMap.from(res),
      );
    }
    return const CondemnationHistoryPageEntity.empty();
  }

  @override
  Future<void> rpcCondemnItem({
    required String palletItemId,
    required double quantityToCondemn,
    required String reason,
  }) async {
    await _supabase.rpc(
      'rpc_adjust_or_release_item',
      params: {
        'p_pallet_item_id': palletItemId,
        'p_action': 'condemn',
        'p_target_quantity': quantityToCondemn,
        'p_notes': reason,
      },
    );
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
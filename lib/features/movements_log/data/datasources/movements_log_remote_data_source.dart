import 'dart:async';

import 'package:discount_cold_store/features/receiving/domain/entities/receiving_entities.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/movements_log_models.dart';

abstract class IMovementsLogRemoteDataSource {
  Future<List<SystemMovementModel>> fetchMovements({
    DateTime? fromDate,
    DateTime? toDate,
    MovementActionType? movementTypeFilter,
    ReceivingSource? sourceFilter,
    int limit = 400,
  });

  Stream<void> subscribeToMovements();
}

class MovementsLogRemoteDataSourceImpl
    implements IMovementsLogRemoteDataSource {
  final SupabaseClient _supabase;

  MovementsLogRemoteDataSourceImpl(this._supabase);

  @override
  Future<List<SystemMovementModel>> fetchMovements({
    DateTime? fromDate,
    DateTime? toDate,
    MovementActionType? movementTypeFilter,
    ReceivingSource? sourceFilter,
    int limit = 400,
  }) async {
    var query = _supabase
        .from('inventory_movements')
        .select('*, profiles(full_name)');

    if (fromDate != null) {
      final start = DateTime(
        fromDate.year,
        fromDate.month,
        fromDate.day,
      ).toIso8601String();
      query = query.gte('created_at', start);
    }

    if (toDate != null) {
      final end = DateTime(
        toDate.year,
        toDate.month,
        toDate.day,
        23,
        59,
        59,
      ).toIso8601String();
      query = query.lte('created_at', end);
    }

    if (movementTypeFilter != null) {
      query = query.eq('movement_type', movementTypeFilter.dbValue);
    }

    if (sourceFilter != null) {
      query = query.eq('source_entity', sourceFilter.dbValue);
    }

    final data = await query.order('created_at', ascending: false).limit(limit);
    final list = data as List;
    return list
        .map((r) => SystemMovementModel.fromJson(MoveJsonMap.from(r as Map)))
        .toList();
  }

  @override
  Stream<void> subscribeToMovements() {
    final controller = StreamController<void>.broadcast();
    final channel = _supabase
        .channel('movements_log_realtime_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_movements',
          callback: (_) => controller.add(null),
        )
        .subscribe();

    controller.onCancel = () {
      _supabase.removeChannel(channel);
    };
    return controller.stream;
  }
}

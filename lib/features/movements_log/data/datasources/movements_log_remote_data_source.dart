import 'dart:async';

import 'package:discount_cold_store/features/receiving/domain/entities/receiving_entities.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/deleted_record_model.dart';
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

  Future<List<DeletedRecordModel>> fetchDeletedRecords({
    DateTime? fromDate,
    DateTime? toDate,
    String? actionTypeFilter,
    int limit = 300,
  });

  Stream<void> subscribeToDeletedRecords();
}

class MovementsLogRemoteDataSourceImpl
    implements IMovementsLogRemoteDataSource {
  final SupabaseClient _supabase;

  static const List<String> _deleteActionTypes = [
    'DELETE_MISTAKEN_PALLET',
    'DELETE_MISTAKEN_PALLET_ITEM',
  ];

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

  @override
  Future<List<DeletedRecordModel>> fetchDeletedRecords({
    DateTime? fromDate,
    DateTime? toDate,
    String? actionTypeFilter,
    int limit = 300,
  }) async {
    var query = _supabase
        .from('user_audit_logs')
        .select('*, profiles(full_name)');

    if (actionTypeFilter != null && actionTypeFilter.isNotEmpty) {
      query = query.eq('action_type', actionTypeFilter);
    } else {
      query = query.inFilter('action_type', _deleteActionTypes);
    }

    if (fromDate != null) {
      final start = DateTime(
        fromDate.year,
        fromDate.month,
        fromDate.day,
      ).toUtc().toIso8601String();
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
        999,
      ).toUtc().toIso8601String();
      query = query.lte('created_at', end);
    }

    final data = await query.order('created_at', ascending: false).limit(limit);
    final list = data as List;
    return list
        .map(
          (r) => DeletedRecordModel.fromJson(
            Map<String, dynamic>.from(r as Map),
          ),
        )
        .toList();
  }

  @override
  Stream<void> subscribeToDeletedRecords() {
    final controller = StreamController<void>.broadcast();
    final channel = _supabase
        .channel('deleted_records_realtime_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'user_audit_logs',
          callback: (_) => controller.add(null),
        )
        .subscribe();

    controller.onCancel = () {
      _supabase.removeChannel(channel);
    };
    return controller.stream;
  }
}
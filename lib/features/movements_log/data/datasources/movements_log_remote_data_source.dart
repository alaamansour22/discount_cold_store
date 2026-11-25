import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/deleted_record_entity.dart';
import '../../domain/entities/movements_log_entities.dart';
import '../models/deleted_record_model.dart';
import '../models/movements_log_models.dart';

abstract class IMovementsLogRemoteDataSource {
  Future<MovementsLogPageEntity> fetchMovementsPaginated(
    MovementsLogFilter filter,
  );

  Stream<void> subscribeToMovements();

  Future<DeletedRecordsPageEntity> fetchDeletedRecordsPaginated(
    DeletedRecordsFilter filter,
  );

  Stream<void> subscribeToDeletedRecords();
}

class MovementsLogRemoteDataSourceImpl
    implements IMovementsLogRemoteDataSource {
  final SupabaseClient _supabase;

  MovementsLogRemoteDataSourceImpl(this._supabase);

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
  Future<MovementsLogPageEntity> fetchMovementsPaginated(
    MovementsLogFilter filter,
  ) async {
    final res = await _supabase.rpc(
      'rpc_get_movements_log_paginated',
      params: {
        'p_page': filter.page,
        'p_page_size': filter.pageSize,
        'p_search': filter.search.trim().isEmpty ? null : filter.search.trim(),
        'p_movement_type': filter.movementType?.dbValue,
        'p_source': filter.source?.dbValue,
        'p_from_date': _dateOnly(filter.fromDate),
        'p_to_date': _dateOnly(filter.toDate),
      },
    );

    if (res is Map) {
      return MovementsLogPageMapper.fromRpcJson(MoveJsonMap.from(res));
    }
    return const MovementsLogPageEntity.empty();
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
  Future<DeletedRecordsPageEntity> fetchDeletedRecordsPaginated(
    DeletedRecordsFilter filter,
  ) async {
    final res = await _supabase.rpc(
      'rpc_get_deleted_records_paginated',
      params: {
        'p_page': filter.page,
        'p_page_size': filter.pageSize,
        'p_search': filter.search.trim().isEmpty ? null : filter.search.trim(),
        'p_action_type': filter.kind?.dbValue,
        'p_from_date': _dateOnly(filter.fromDate),
        'p_to_date': _dateOnly(filter.toDate),
      },
    );

    if (res is Map) {
      return DeletedRecordsPageMapper.fromRpcJson(
        Map<String, dynamic>.from(res),
      );
    }
    return const DeletedRecordsPageEntity.empty();
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
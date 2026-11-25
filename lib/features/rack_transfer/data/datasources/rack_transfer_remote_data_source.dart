import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/rack_transfer_entities.dart';
import '../models/rack_transfer_models.dart';

abstract class IRackTransferRemoteDataSource {
  Future<List<TransferJsonMap>> fetchRawSlots();
  Future<List<TransferJsonMap>> fetchActiveItems();

  Future<RackTransferHistoryPageEntity> fetchRelocationHistoryPaginated(
    RackTransferHistoryFilter filter,
  );

  Future<void> rpcRelocatePallet({
    required String palletId,
    required String targetSlotId,
    required String notes,
  });

  Stream<void> subscribeToRackTransferChanges();
}

class RackTransferRemoteDataSourceImpl
    implements IRackTransferRemoteDataSource {
  final SupabaseClient _supabase;

  RackTransferRemoteDataSourceImpl(this._supabase);

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
  Future<List<TransferJsonMap>> fetchRawSlots() async {
    final data = await _supabase
        .from('rack_slots')
        .select()
        .order('rack_letter')
        .order('floor_number')
        .order('bin_number');
    return List<TransferJsonMap>.from(data as List);
  }

  @override
  Future<List<TransferJsonMap>> fetchActiveItems() async {
    final data = await _supabase
        .from('v_active_pallet_items')
        .select()
        .order('expiry_date');
    return List<TransferJsonMap>.from(data as List);
  }

  @override
  Future<RackTransferHistoryPageEntity> fetchRelocationHistoryPaginated(
    RackTransferHistoryFilter filter,
  ) async {
    final res = await _supabase.rpc(
      'rpc_get_rack_transfers_paginated',
      params: {
        'p_page': filter.page,
        'p_page_size': filter.pageSize,
        'p_search': filter.search.trim().isEmpty ? null : filter.search.trim(),
        'p_from_date': _dateOnly(filter.fromDate),
        'p_to_date': _dateOnly(filter.toDate),
      },
    );

    if (res is Map) {
      return TransferModelMapper.historyPageFromRpcJson(
        TransferJsonMap.from(res),
      );
    }
    return const RackTransferHistoryPageEntity.empty();
  }

  @override
  Future<void> rpcRelocatePallet({
    required String palletId,
    required String targetSlotId,
    required String notes,
  }) async {
    await _supabase.rpc(
      'rpc_relocate_pallet',
      params: {
        'p_pallet_id': palletId,
        'p_target_slot_id': targetSlotId,
        'p_notes': notes.trim().isEmpty ? 'تحويل بين الراكات' : notes.trim(),
      },
    );
  }

  @override
  Stream<void> subscribeToRackTransferChanges() {
    final controller = StreamController<void>.broadcast();
    final channel = _supabase
        .channel('rack_transfer_realtime_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rack_slots',
          callback: (_) => controller.add(null),
        )
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
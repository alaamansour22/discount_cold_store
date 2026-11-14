import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/rack_transfer_entities.dart';
import '../models/rack_transfer_models.dart';

abstract class IRackTransferRemoteDataSource {
  Future<List<TransferJsonMap>> fetchRawSlots();
  Future<List<TransferJsonMap>> fetchActiveItems();
  Future<List<RackTransferHistoryEntity>> fetchRelocationMovements({
    int limit = 150,
  });

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
  Future<List<RackTransferHistoryEntity>> fetchRelocationMovements({
    int limit = 150,
  }) async {
    final data = await _supabase
        .from('inventory_movements')
        .select('*, profiles(full_name)')
        .eq('movement_type', 'relocate')
        .order('created_at', ascending: false)
        .limit(limit);

    final list = data as List;
    return list
        .map(
          (r) => TransferModelMapper.historyFromJson(
            TransferJsonMap.from(r as Map),
          ),
        )
        .toList();
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

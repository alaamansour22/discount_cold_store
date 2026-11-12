import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/receiving_dispatch_entities.dart';
import '../models/receiving_dispatch_models.dart';

abstract class IReceivingDispatchRemoteDataSource {
  Future<List<ReceivingJsonMap>> fetchRawRackSlots();
  Future<List<ReceivingPalletItemModel>> fetchActivePalletItems();
  Future<List<ReceivingMovementModel>> fetchMovements({int limit = 250});

  Future<void> rpcReceivePallet({
    required ReceivingSource sourceEntity,
    required String slotId,
    required List<PalletItemDraft> items,
  });

  Future<void> rpcAddItemsToExistingPallet({
    required String palletId,
    required ReceivingSource sourceEntity,
    required List<PalletItemDraft> items,
  });

  Future<void> rpcAdjustOrReleaseItem({
    required String palletItemId,
    required MovementActionType action,
    required double targetQuantity,
    required String notes,
  });

  Stream<void> subscribeToRackChanges();
}

class ReceivingDispatchRemoteDataSourceImpl
    implements IReceivingDispatchRemoteDataSource {
  final SupabaseClient _supabase;

  ReceivingDispatchRemoteDataSourceImpl(this._supabase);

  @override
  Future<List<ReceivingJsonMap>> fetchRawRackSlots() async {
    final data = await _supabase
        .from('rack_slots')
        .select()
        .order('rack_letter')
        .order('floor_number')
        .order('bin_number');
    return List<ReceivingJsonMap>.from(data as List);
  }

  @override
  Future<List<ReceivingPalletItemModel>> fetchActivePalletItems() async {
    final data = await _supabase
        .from('v_active_pallet_items')
        .select()
        .order('expiry_date');
    final list = data as List;
    return list
        .map((r) => ReceivingPalletItemModel.fromJson(ReceivingJsonMap.from(r as Map)))
        .toList();
  }

  @override
  Future<List<ReceivingMovementModel>> fetchMovements({int limit = 250}) async {
    final data = await _supabase
        .from('inventory_movements')
        .select('*, profiles(full_name)')
        .order('created_at', ascending: false)
        .limit(limit);
    final list = data as List;
    return list
        .map((r) => ReceivingMovementModel.fromJson(ReceivingJsonMap.from(r as Map)))
        .toList();
  }

  @override
  Future<void> rpcReceivePallet({
    required ReceivingSource sourceEntity,
    required String slotId,
    required List<PalletItemDraft> items,
  }) async {
    await _supabase.rpc('rpc_receive_pallet_v3', params: {
      'p_source_entity': sourceEntity.dbValue,
      'p_slot_id': slotId,
      'p_items': items.map((e) => e.toRpcJson()).toList(),
    });
  }

  @override
  Future<void> rpcAddItemsToExistingPallet({
    required String palletId,
    required ReceivingSource sourceEntity,
    required List<PalletItemDraft> items,
  }) async {
    await _supabase.rpc('rpc_add_items_to_existing_pallet', params: {
      'p_pallet_id': palletId,
      'p_source_entity': sourceEntity.dbValue,
      'p_items': items.map((e) => e.toRpcJson()).toList(),
    });
  }

  @override
  Future<void> rpcAdjustOrReleaseItem({
    required String palletItemId,
    required MovementActionType action,
    required double targetQuantity,
    required String notes,
  }) async {
    await _supabase.rpc('rpc_adjust_or_release_item', params: {
      'p_pallet_item_id': palletItemId,
      'p_action': action.dbValue,
      'p_target_quantity': targetQuantity,
      'p_notes': notes,
    });
  }

  @override
  Stream<void> subscribeToRackChanges() {
    final controller = StreamController<void>.broadcast();
    final channel = _supabase
        .channel('receiving_dispatch_realtime')
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
        .subscribe();

    controller.onCancel = () {
      _supabase.removeChannel(channel);
    };
    return controller.stream;
  }
}

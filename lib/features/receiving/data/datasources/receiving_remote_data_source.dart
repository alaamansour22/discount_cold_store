import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/receiving_entities.dart';
import '../models/receiving_models.dart';

abstract class IReceivingRemoteDataSource {
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

  Future<void> rpcDeleteMistakenPallet({
    required String palletId,
    required String reason,
  });

  Future<bool> rpcDeleteMistakenPalletItem({
    required String palletItemId,
    required String reason,
  });
}

class ReceivingRemoteDataSourceImpl implements IReceivingRemoteDataSource {
  final SupabaseClient _supabase;

  ReceivingRemoteDataSourceImpl(this._supabase);

  @override
  Future<List<ReceivingMovementModel>> fetchMovements({int limit = 250}) async {
    final data = await _supabase
        .from('inventory_movements')
        .select('*, profiles(full_name)')
        .order('created_at', ascending: false)
        .limit(limit);
    final list = data as List;
    return list
        .map(
          (r) =>
              ReceivingMovementModel.fromJson(ReceivingJsonMap.from(r as Map)),
        )
        .toList();
  }

  @override
  Future<void> rpcReceivePallet({
    required ReceivingSource sourceEntity,
    required String slotId,
    required List<PalletItemDraft> items,
  }) async {
    await _supabase.rpc(
      'rpc_receive_pallet_v3',
      params: {
        'p_source_entity': sourceEntity.dbValue,
        'p_slot_id': slotId,
        'p_items': items.map((e) => e.toRpcJson()).toList(),
      },
    );
  }

  @override
  Future<void> rpcAddItemsToExistingPallet({
    required String palletId,
    required ReceivingSource sourceEntity,
    required List<PalletItemDraft> items,
  }) async {
    await _supabase.rpc(
      'rpc_add_items_to_existing_pallet',
      params: {
        'p_pallet_id': palletId,
        'p_source_entity': sourceEntity.dbValue,
        'p_items': items.map((e) => e.toRpcJson()).toList(),
      },
    );
  }

  @override
  Future<void> rpcAdjustOrReleaseItem({
    required String palletItemId,
    required MovementActionType action,
    required double targetQuantity,
    required String notes,
  }) async {
    await _supabase.rpc(
      'rpc_adjust_or_release_item',
      params: {
        'p_pallet_item_id': palletItemId,
        'p_action': action.dbValue,
        'p_target_quantity': targetQuantity,
        'p_notes': notes,
      },
    );
  }

  @override
  Future<void> rpcDeleteMistakenPallet({
    required String palletId,
    required String reason,
  }) async {
    await _supabase.rpc(
      'rpc_delete_mistaken_pallet',
      params: {
        'p_pallet_id': palletId,
        'p_reason': reason.trim(),
      },
    );
  }

  @override
  Future<bool> rpcDeleteMistakenPalletItem({
    required String palletItemId,
    required String reason,
  }) async {
    final res = await _supabase.rpc(
      'rpc_delete_mistaken_pallet_item',
      params: {
        'p_pallet_item_id': palletItemId,
        'p_reason': reason.trim(),
      },
    );
    if (res is Map) {
      return res['slot_freed'] as bool? ?? false;
    }
    return false;
  }
}
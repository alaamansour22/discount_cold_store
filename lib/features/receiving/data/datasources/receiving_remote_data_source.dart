import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/receiving_entities.dart';
import '../models/receiving_models.dart';

abstract class IReceivingRemoteDataSource {
  Future<List<ReceivingMovementModel>> fetchMovements({int limit = 250});

  Future<ReceiptsHistoryPageEntity> fetchReceiptsHistoryPaginated(
    ReceiptsHistoryFilter filter,
  );

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

  String? _dateOnly(DateTime? d) {
    if (d == null) return null;
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  Future<List<ReceivingMovementModel>> fetchMovements({int limit = 250}) async {
    final data = await _supabase
        .from('inventory_movements')
        .select('*, profiles(full_name), pallets(pallet_reference)')
        .inFilter('movement_type', const ['receive_new', 'add_item_to_pallet'])
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
  Future<ReceiptsHistoryPageEntity> fetchReceiptsHistoryPaginated(
    ReceiptsHistoryFilter filter,
  ) async {
    final res = await _supabase.rpc(
      'rpc_get_receipts_history_paginated',
      params: {
        'p_page': filter.page,
        'p_page_size': filter.pageSize,
        'p_search': filter.search.trim().isEmpty ? null : filter.search.trim(),
        'p_source': filter.source?.dbValue,
        'p_kind': filter.kind == ReceiptOperationKind.all
            ? null
            : filter.kind.dbValue,
        'p_from_date': _dateOnly(filter.fromDate),
        'p_to_date': _dateOnly(filter.toDate),
      },
    );

    if (res is Map) {
      return ReceiptsHistoryModelMapper.pageFromRpcJson(
        ReceivingJsonMap.from(res),
      );
    }
    return const ReceiptsHistoryPageEntity.empty();
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
      params: {'p_pallet_id': palletId, 'p_reason': reason.trim()},
    );
  }

  @override
  Future<bool> rpcDeleteMistakenPalletItem({
    required String palletItemId,
    required String reason,
  }) async {
    final res = await _supabase.rpc(
      'rpc_delete_mistaken_pallet_item',
      params: {'p_pallet_item_id': palletItemId, 'p_reason': reason.trim()},
    );
    if (res is Map) {
      return res['slot_freed'] as bool? ?? false;
    }
    return false;
  }
}
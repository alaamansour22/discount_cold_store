import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../receiving/data/models/receiving_models.dart';

abstract class IWarehouseRemoteDataSource {
  Future<List<ReceivingJsonMap>> fetchRawRackSlots();
  Future<List<ReceivingPalletItemModel>> fetchActivePalletItems();
  Stream<void> subscribeToRackChanges();
}

class WarehouseRemoteDataSourceImpl implements IWarehouseRemoteDataSource {
  final SupabaseClient supabase;
  WarehouseRemoteDataSourceImpl(this.supabase);

  @override
  Future<List<ReceivingJsonMap>> fetchRawRackSlots() async {
    final data = await supabase
        .from('rack_slots')
        .select()
        .order('rack_letter')
        .order('floor_number')
        .order('bin_number');
    return List<ReceivingJsonMap>.from(data as List);
  }

  @override
  Future<List<ReceivingPalletItemModel>> fetchActivePalletItems() async {
    final data = await supabase
        .from('v_active_pallet_items')
        .select()
        .order('expiry_date');
    return (data as List)
        .map(
          (row) => ReceivingPalletItemModel.fromJson(
            ReceivingJsonMap.from(row as Map),
          ),
        )
        .toList();
  }

  @override
  Stream<void> subscribeToRackChanges() {
    final controller = StreamController<void>.broadcast();
    final channel = supabase
        .channel('warehouse_rack_realtime')
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
    controller.onCancel = () => supabase.removeChannel(channel);
    return controller.stream;
  }
}

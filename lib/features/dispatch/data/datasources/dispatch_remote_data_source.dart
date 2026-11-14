import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../receiving/data/models/receiving_models.dart';
import '../../../receiving/domain/entities/receiving_entities.dart';
import '../../domain/entities/dispatch_entities.dart';

abstract class IDispatchRemoteDataSource {
  Future<List<ReceivingPalletItemEntity>> getAvailableItems();
  Future<List<DispatchDocumentEntity>> getDocuments({int limit = 30});
  Future<List<DispatchDocumentLineEntity>> getDocumentLines(String documentId);
  Future<Map<String, dynamic>> createDocument(List<DispatchDraftLine> lines);
  Future<void> reverseDocument(String documentId, String reason);
}

class DispatchRemoteDataSourceImpl implements IDispatchRemoteDataSource {
  final SupabaseClient db;
  DispatchRemoteDataSourceImpl(this.db);

  @override
  Future<List<ReceivingPalletItemEntity>> getAvailableItems() async {
    final rows = await db
        .from('v_active_pallet_items')
        .select()
        .order('expiry_date');
    return (rows as List)
        .map(
          (e) => ReceivingPalletItemModel.fromJson(
            ReceivingJsonMap.from(e as Map),
          ),
        )
        .toList();
  }

  @override
  Future<List<DispatchDocumentEntity>> getDocuments({int limit = 30}) async {
    final rows = await db
        .from('dispatch_documents')
        .select('*')
        .order('created_at', ascending: false)
        .limit(limit);
    final documents = (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (documents.isEmpty) return [];
    final documentIds = documents.map((e) => e['id'] as String).toList();
    final links = await db
        .from('dispatch_document_pallets')
        .select('document_id,pallet_id')
        .inFilter('document_id', documentIds);
    final palletIds = (links as List)
        .map((e) => (e as Map)['pallet_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final refsByPallet = <String, String>{};
    if (palletIds.isNotEmpty) {
      final palletRows = await db
          .from('pallets')
          .select('id,pallet_reference')
          .inFilter('id', palletIds);
      for (final row in palletRows as List) {
        final value = Map<String, dynamic>.from(row as Map);
        refsByPallet[value['id'] as String] =
            value['pallet_reference'] as String? ?? '';
      }
    }
    final refsByDocument = <String, List<String>>{};
    for (final link in links) {
      final value = Map<String, dynamic>.from(link as Map);
      final ref = refsByPallet[value['pallet_id']];
      if (ref != null && ref.isNotEmpty) {
        refsByDocument
            .putIfAbsent(value['document_id'] as String, () => <String>[])
            .add(ref);
      }
    }
    return documents.map((document) {
      document['pallet_references'] =
          refsByDocument[document['id']] ?? <String>[];
      return DispatchDocumentEntity.fromJson(document);
    }).toList();
  }

  @override
  Future<List<DispatchDocumentLineEntity>> getDocumentLines(
    String documentId,
  ) async {
    final palletRows = await db
        .from('dispatch_document_pallets')
        .select('id,pallet_id,original_slot_code')
        .eq('document_id', documentId);
    if ((palletRows as List).isEmpty) return [];
    final palletIds = palletRows.map((e) => e['id'] as String).toList();
    final palletByDocId = {for (final e in palletRows) e['id'] as String: e};
    final palletIdsInStock = palletRows
        .map((e) => e['pallet_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final palletReferences = <String, String>{};
    if (palletIdsInStock.isNotEmpty) {
      final stockPalletRows = await db
          .from('pallets')
          .select('id,pallet_reference')
          .inFilter('id', palletIdsInStock);
      for (final row in stockPalletRows as List) {
        final value = Map<String, dynamic>.from(row as Map);
        palletReferences[value['id'] as String] =
            value['pallet_reference'] as String? ?? '';
      }
    }
    final itemRows = await db
        .from('dispatch_document_items')
        .select('*')
        .inFilter('document_pallet_id', palletIds);
    return (itemRows as List).map((e) {
      final row = Map<String, dynamic>.from(e as Map);
      final p = palletByDocId[row['document_pallet_id']];
      return DispatchDocumentLineEntity(
        palletReference:
            palletReferences[(p?['pallet_id'] ?? '').toString()] ??
            (p?['pallet_id'] ?? '').toString(),
        slotCode: (p?['original_slot_code'] ?? '').toString(),
        itemName: (row['item_name_snapshot'] ?? '').toString(),
        unit: (row['unit'] ?? '').toString(),
        method: (row['dispatch_method'] ?? '').toString(),
        quantity: (row['quantity_dispatched'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> createDocument(
    List<DispatchDraftLine> lines,
  ) async {
    // The RPC contract is one object per pallet. Selected item lines are
    // nested inside `items`; sending flat rows causes the database validator
    // to reject the request because it expects a non-empty items array.
    final grouped = <String, List<DispatchDraftLine>>{};
    for (final line in lines) {
      grouped.putIfAbsent(line.item.palletId, () => <DispatchDraftLine>[]);
      grouped[line.item.palletId]!.add(line);
    }

    final payload = grouped.entries.map((entry) {
      final itemIds = <String>{};
      for (final line in entry.value) {
        if (!itemIds.add(line.item.palletItemId)) {
          throw ArgumentError('الصنف مكرر في طلب الصرف: ${line.item.itemName}');
        }
        if (line.quantity <= 0 || line.quantity > line.item.quantity) {
          throw ArgumentError(
            'كمية الصرف غير صحيحة للصنف: ${line.item.itemName}',
          );
        }
      }

      return <String, dynamic>{
        'pallet_id': entry.key,
        // Always use custom_quantity: a full quantity for one selected line
        // must not be interpreted as dispatching every item on that pallet.
        'dispatch_method': 'custom_quantity',
        'items': entry.value
            .map(
              (line) => <String, dynamic>{
                'pallet_item_id': line.item.palletItemId,
                'quantity': line.quantity,
              },
            )
            .toList(),
      };
    }).toList();

    final result = await db.rpc(
      'rpc_create_dispatch_document',
      params: {'p_items': payload},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  @override
  Future<void> reverseDocument(String documentId, String reason) async {
    await db.rpc(
      'rpc_reverse_dispatch_document',
      params: {
        'p_document_id': documentId,
        'p_reason': reason.trim(),
        'p_alternative_slots': <Map<String, dynamic>>[],
      },
    );
  }
}

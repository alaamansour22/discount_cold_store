import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/pagination/paged_result.dart';
import '../../../receiving/data/models/receiving_models.dart';
import '../../domain/entities/dispatch_entities.dart';

abstract class IDispatchRemoteDataSource {
  Future<DispatchAvailablePalletsPageEntity> fetchAvailablePalletsPaginated(
    DispatchAvailablePalletsFilter filter,
  );

  Future<DispatchDocumentsPageEntity> fetchDocumentsPaginated(
    DispatchDocumentsFilter filter,
  );

  Future<List<DispatchDocumentLineEntity>> getDocumentLines(String documentId);

  Future<DispatchReversalReadinessEntity> checkReversalReadiness(
    String documentId,
  );

  Future<DispatchJsonMap> createDocument(List<DispatchDraftLine> lines);

  Future<void> reverseDocument({
    required String documentId,
    required String reason,
    List<DispatchSlotAssignment> alternativeSlots = const [],
  });

  Stream<void> subscribeToDispatchChanges();
}

class DispatchRemoteDataSourceImpl implements IDispatchRemoteDataSource {
  final SupabaseClient db;

  DispatchRemoteDataSourceImpl(this.db);

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
  Future<DispatchAvailablePalletsPageEntity> fetchAvailablePalletsPaginated(
    DispatchAvailablePalletsFilter filter,
  ) async {
    final res = await db.rpc(
      'rpc_get_available_pallets_for_dispatch_paginated',
      params: {
        'p_page': filter.page,
        'p_page_size': filter.pageSize,
        'p_search': filter.search.trim().isEmpty ? null : filter.search.trim(),
        'p_zone': filter.zone,
        'p_pallet_kind': filter.palletKind,
      },
    );

    if (res is! Map) {
      return const DispatchAvailablePalletsPageEntity.empty();
    }

    final map = DispatchJsonMap.from(res);
    final paged = PagedResult<DispatchAvailablePalletEntity>.fromRpcJson(
      map,
      _palletFromRpcJson,
    );

    final summaryMap = map['summary'] is Map
        ? DispatchJsonMap.from(map['summary'] as Map)
        : const <String, dynamic>{};

    final summary = DispatchAvailablePalletsSummaryEntity(
      totalPallets:
          (summaryMap['total_pallets'] as num?)?.toInt() ?? paged.totalCount,
      singleCount: (summaryMap['single_count'] as num?)?.toInt() ?? 0,
      mixedCount: (summaryMap['mixed_count'] as num?)?.toInt() ?? 0,
      totalItemLines: (summaryMap['total_item_lines'] as num?)?.toInt() ?? 0,
      totalsByUnitSummary:
          summaryMap['totals_by_unit_summary']?.toString() ?? '0',
    );

    return DispatchAvailablePalletsPageEntity(page: paged, summary: summary);
  }

  DispatchAvailablePalletEntity _palletFromRpcJson(DispatchJsonMap j) {
    final rawItems = j['items'] as List? ?? const [];
    final items = [
      for (final e in rawItems)
        if (e is Map)
          ReceivingPalletItemModel.fromJson(ReceivingJsonMap.from(e)),
    ];

    return DispatchAvailablePalletEntity(
      palletId: j['pallet_id']?.toString() ?? '',
      palletReference: j['pallet_reference']?.toString() ?? '—',
      slotId: j['slot_id']?.toString() ?? '',
      slotCode: j['slot_code']?.toString() ?? '—',
      zoneCode: j['zone_code']?.toString() ?? 'C2',
      isMixed: j['is_mixed'] as bool? ?? (items.length > 1),
      itemsCount: (j['items_count'] as num?)?.toInt() ?? items.length,
      minDaysUntilExpiry: (j['min_days_until_expiry'] as num?)?.toInt() ?? 0,
      hasCondemnationAlert: j['has_condemnation_alert'] as bool? ?? false,
      totalSummary: j['total_summary']?.toString() ?? '0',
      items: items,
    );
  }

  @override
  Future<DispatchDocumentsPageEntity> fetchDocumentsPaginated(
    DispatchDocumentsFilter filter,
  ) async {
    final res = await db.rpc(
      'rpc_get_dispatch_documents_paginated',
      params: {
        'p_page': filter.page,
        'p_page_size': filter.pageSize,
        'p_search': filter.search.trim().isEmpty ? null : filter.search.trim(),
        'p_status': filter.status,
        'p_from_date': _dateOnly(filter.fromDate),
        'p_to_date': _dateOnly(filter.toDate),
      },
    );

    if (res is! Map) {
      return const DispatchDocumentsPageEntity.empty();
    }

    final map = DispatchJsonMap.from(res);
    final paged = PagedResult<DispatchDocumentEntity>.fromRpcJson(
      map,
      DispatchDocumentEntity.fromJson,
    );

    final summaryMap = map['summary'] is Map
        ? DispatchJsonMap.from(map['summary'] as Map)
        : const <String, dynamic>{};

    final summary = DispatchDocumentsSummaryEntity(
      totalDocuments:
          (summaryMap['total_documents'] as num?)?.toInt() ?? paged.totalCount,
      completedCount: (summaryMap['completed_count'] as num?)?.toInt() ?? 0,
      reversedCount: (summaryMap['reversed_count'] as num?)?.toInt() ?? 0,
      netDispatchedQuantity:
          (summaryMap['net_dispatched_quantity'] as num?)?.toDouble() ?? 0,
      currentUserCanReverse:
          summaryMap['current_user_can_reverse'] as bool? ?? false,
    );

    return DispatchDocumentsPageEntity(page: paged, summary: summary);
  }

  @override
  Future<List<DispatchDocumentLineEntity>> getDocumentLines(
    String documentId,
  ) async {
    final res = await db.rpc(
      'rpc_get_dispatch_document_lines',
      params: {'p_document_id': documentId},
    );
    if (res is! List) {
      return const [];
    }
    return [
      for (final e in res)
        if (e is Map)
          DispatchDocumentLineEntity.fromRpcJson(DispatchJsonMap.from(e)),
    ];
  }

  @override
  Future<DispatchReversalReadinessEntity> checkReversalReadiness(
    String documentId,
  ) async {
    final res = await db.rpc(
      'rpc_check_dispatch_reversal_readiness',
      params: {'p_document_id': documentId},
    );
    return DispatchReversalReadinessEntity.fromJson(
      DispatchJsonMap.from(res as Map),
    );
  }

  @override
  Future<DispatchJsonMap> createDocument(
    List<DispatchDraftLine> lines,
  ) async {
    final grouped = <String, List<DispatchDraftLine>>{};
    for (final line in lines) {
      grouped
          .putIfAbsent(line.item.palletId, () => <DispatchDraftLine>[])
          .add(line);
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

      final isFullPallet = entry.value.every(
        (line) =>
            line.palletFullySelected &&
            line.method == 'full_pallet' &&
            line.quantity >= line.item.quantity,
      );

      if (isFullPallet) {
        return <String, dynamic>{
          'pallet_id': entry.key,
          'dispatch_method': 'full_pallet',
          'items': const <DispatchJsonMap>[],
        };
      }

      return <String, dynamic>{
        'pallet_id': entry.key,
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
    return DispatchJsonMap.from(result as Map);
  }

  @override
  Future<void> reverseDocument({
    required String documentId,
    required String reason,
    List<DispatchSlotAssignment> alternativeSlots = const [],
  }) async {
    await db.rpc(
      'rpc_reverse_dispatch_document',
      params: {
        'p_document_id': documentId,
        'p_reason': reason.trim(),
        'p_alternative_slots': alternativeSlots,
      },
    );
  }

  @override
  Stream<void> subscribeToDispatchChanges() {
    final controller = StreamController<void>.broadcast();
    final channel = db
        .channel('dispatch_module_realtime_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'dispatch_documents',
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
      db.removeChannel(channel);
    };
    return controller.stream;
  }
}
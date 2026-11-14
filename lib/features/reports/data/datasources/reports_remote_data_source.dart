import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/report_entities.dart';

abstract class IReportsRemoteDataSource {
  Future<List<ReportRow>> fetchDispatchItems(ReportDateRange range);
  Future<List<ReportRow>> fetchDispatchDocuments(ReportDateRange range);
  Future<List<ReportRow>> fetchReceipts(ReportDateRange range);
  Future<List<ReportRow>> fetchCurrentInventory();
  Future<List<ReportRow>> fetchItemBalances();
  Future<List<ReportRow>> fetchCondemnationHistory(ReportDateRange range);
  Future<int> fetchCondemnationThreshold();
  Future<List<ReportRow>> fetchCondemnationAlerts(int threshold);
}

class ReportsRemoteDataSourceImpl implements IReportsRemoteDataSource {
  final SupabaseClient _supabase;

  ReportsRemoteDataSourceImpl(this._supabase);

  @override
  Future<List<ReportRow>> fetchDispatchItems(ReportDateRange range) async {
    final data = await _supabase
        .from('v_report_dispatch_items')
        .select()
        .gte('dispatched_at', range.startIso)
        .lte('dispatched_at', range.endIso)
        .order('dispatched_at', ascending: false);
    return (data as List)
        .cast<ReportRow>()
        .where((row) => row['document_status'] == 'completed')
        .toList();
  }

  @override
  Future<List<ReportRow>> fetchDispatchDocuments(ReportDateRange range) async {
    final data = await _supabase
        .from('v_report_dispatch_documents')
        .select()
        .gte('created_at', range.startIso)
        .lte('created_at', range.endIso)
        .order('created_at', ascending: false);
    return (data as List).cast<ReportRow>();
  }

  @override
  Future<List<ReportRow>> fetchReceipts(ReportDateRange range) async {
    final data = await _supabase
        .from('v_report_receipts')
        .select()
        .gte('received_at', range.startIso)
        .lte('received_at', range.endIso)
        .order('received_at', ascending: false);
    return (data as List).cast<ReportRow>();
  }

  @override
  Future<List<ReportRow>> fetchCurrentInventory() async {
    final data = await _supabase
        .from('v_report_current_inventory')
        .select()
        .gt('quantity', 0)
        .order('item_name')
        .order('expiry_date');
    return (data as List).cast<ReportRow>();
  }

  @override
  Future<List<ReportRow>> fetchItemBalances() async {
    final data = await _supabase
        .from('v_report_item_balances')
        .select()
        .order('item_name');
    return (data as List).cast<ReportRow>();
  }

  @override
  Future<List<ReportRow>> fetchCondemnationHistory(
    ReportDateRange range,
  ) async {
    final data = await _supabase
        .from('v_report_condemnations')
        .select()
        .gte('condemned_at', range.startIso)
        .lte('condemned_at', range.endIso)
        .order('condemned_at', ascending: false)
        .limit(1000);
    return (data as List).cast<ReportRow>();
  }

  @override
  Future<int> fetchCondemnationThreshold() async {
    final data = await _supabase
        .from('cold_storage_settings')
        .select('condemnation_threshold_days')
        .eq('id', 1)
        .single();
    return (data['condemnation_threshold_days'] as num?)?.toInt() ?? 7;
  }

  @override
  Future<List<ReportRow>> fetchCondemnationAlerts(int threshold) async {
    final data = await _supabase
        .from('v_active_pallet_items')
        .select()
        .lte('days_until_expiry', threshold)
        .order('days_until_expiry');
    return (data as List).cast<ReportRow>();
  }
}
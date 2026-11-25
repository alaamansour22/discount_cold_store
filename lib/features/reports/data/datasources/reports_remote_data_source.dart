import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/report_entities.dart';

abstract class IReportsRemoteDataSource {
  Future<ReportPageEntity> fetchReportPaginated(ReportQueryParams params);
}

class ReportsRemoteDataSourceImpl implements IReportsRemoteDataSource {
  final SupabaseClient _supabase;

  ReportsRemoteDataSourceImpl(this._supabase);

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
  Future<ReportPageEntity> fetchReportPaginated(
    ReportQueryParams params,
  ) async {
    final res = await _supabase.rpc(
      'rpc_get_report_paginated',
      params: {
        'p_report_key': params.reportKey.dbValue,
        'p_from_date': _dateOnly(params.fromDate),
        'p_to_date': _dateOnly(params.toDate),
        'p_search': params.search.trim().isEmpty ? null : params.search.trim(),
        'p_page': params.page,
        'p_page_size': params.pageSize,
      },
    );

    if (res is Map) {
      return ReportPageEntity.fromRpcJson(ReportJsonMap.from(res));
    }

    return ReportPageEntity.empty(reportKey: params.reportKey.dbValue);
  }
}
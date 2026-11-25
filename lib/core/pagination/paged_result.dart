import 'package:equatable/equatable.dart';

/// عقد موحّد لنتائج الباجينيشن القادمة من دوال PostgreSQL RPC في كامل التطبيق
class PagedResult<T> extends Equatable {
  final List<T> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final bool hasPrev;
  final bool hasNext;

  const PagedResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
    required this.hasPrev,
    required this.hasNext,
  });

  const PagedResult.empty({this.pageSize = 20})
    : items = const [],
      page = 1,
      totalCount = 0,
      totalPages = 1,
      hasPrev = false,
      hasNext = false;

  int get fromItemIndex => totalCount == 0 ? 0 : ((page - 1) * pageSize) + 1;

  int get toItemIndex {
    if (totalCount == 0) return 0;
    final end = ((page - 1) * pageSize) + items.length;
    return end > totalCount ? totalCount : end;
  }

  factory PagedResult.fromRpcJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> row) itemParser,
  ) {
    final rawItems = (json['items'] as List?) ?? const [];
    final parsedItems = rawItems
        .map((e) => itemParser(Map<String, dynamic>.from(e as Map)))
        .toList();

    final page = (json['page'] as num?)?.toInt() ?? 1;
    final pageSize = (json['page_size'] as num?)?.toInt() ?? 20;
    final totalCount = (json['total_count'] as num?)?.toInt() ?? parsedItems.length;
    final totalPages = (json['total_pages'] as num?)?.toInt() ?? 1;

    return PagedResult<T>(
      items: parsedItems,
      page: page,
      pageSize: pageSize,
      totalCount: totalCount,
      totalPages: totalPages < 1 ? 1 : totalPages,
      hasPrev: json['has_prev'] as bool? ?? (page > 1),
      hasNext: json['has_next'] as bool? ?? (page < totalPages),
    );
  }

  @override
  List<Object?> get props => [
    items,
    page,
    pageSize,
    totalCount,
    totalPages,
    hasPrev,
    hasNext,
  ];
}
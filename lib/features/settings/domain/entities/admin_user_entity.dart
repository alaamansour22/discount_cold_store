import 'package:equatable/equatable.dart';

import '../../../../core/pagination/paged_result.dart';

typedef AdminUserJsonMap = Map<String, dynamic>;

class AdminUserEntity extends Equatable {
  final String id;
  final String fullName;
  final String? employeeCode;
  final String email;
  final String role; // 'admin' | 'supervisor' | 'operator' | 'quality_inspector'
  final bool isActive;
  final bool canReverseDispatch;
  final DateTime? createdAt;

  const AdminUserEntity({
    required this.id,
    required this.fullName,
    this.employeeCode,
    this.email = '',
    required this.role,
    required this.isActive,
    required this.canReverseDispatch,
    this.createdAt,
  });

  factory AdminUserEntity.fromJson(AdminUserJsonMap json) {
    final rawName = json['full_name']?.toString().trim();
    final rawCode = json['employee_code']?.toString().trim();

    return AdminUserEntity(
      id: json['id']?.toString() ?? '',
      fullName: (rawName != null && rawName.isNotEmpty)
          ? rawName
          : 'مستخدم بدون اسم',
      employeeCode: (rawCode != null && rawCode.isNotEmpty) ? rawCode : null,
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'operator',
      isActive: json['is_active'] as bool? ?? false,
      canReverseDispatch: json['can_reverse_dispatch'] as bool? ?? false,
      createdAt: DateTime.tryParse(
        json['created_at']?.toString() ?? '',
      )?.toLocal(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    fullName,
    employeeCode,
    email,
    role,
    isActive,
    canReverseDispatch,
    createdAt,
  ];
}

class AdminUsersFilter extends Equatable {
  final int page;
  final int pageSize;
  final String search;
  final String? role; // 'admin' | 'supervisor' | 'operator' | 'quality_inspector' | null
  final bool? activeOnly; // true | false | null

  const AdminUsersFilter({
    this.page = 1,
    this.pageSize = 20,
    this.search = '',
    this.role,
    this.activeOnly,
  });

  bool get hasActiveFilters =>
      search.trim().isNotEmpty || role != null || activeOnly != null;

  AdminUsersFilter copyWith({
    int? page,
    int? pageSize,
    String? search,
    String? role,
    bool clearRole = false,
    bool? activeOnly,
    bool clearActiveOnly = false,
  }) {
    return AdminUsersFilter(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      search: search ?? this.search,
      role: clearRole ? null : (role ?? this.role),
      activeOnly: clearActiveOnly ? null : (activeOnly ?? this.activeOnly),
    );
  }

  @override
  List<Object?> get props => [page, pageSize, search, role, activeOnly];
}

class AdminUsersSummaryEntity extends Equatable {
  final int totalUsers;
  final int activeCount;
  final int inactiveCount;
  final int dispatchReversalCount;

  const AdminUsersSummaryEntity({
    this.totalUsers = 0,
    this.activeCount = 0,
    this.inactiveCount = 0,
    this.dispatchReversalCount = 0,
  });

  @override
  List<Object?> get props => [
    totalUsers,
    activeCount,
    inactiveCount,
    dispatchReversalCount,
  ];
}

class AdminUsersPageEntity extends Equatable {
  final PagedResult<AdminUserEntity> page;
  final AdminUsersSummaryEntity summary;

  const AdminUsersPageEntity({required this.page, required this.summary});

  const AdminUsersPageEntity.empty()
    : page = const PagedResult.empty(),
      summary = const AdminUsersSummaryEntity();

  @override
  List<Object?> get props => [page, summary];
}
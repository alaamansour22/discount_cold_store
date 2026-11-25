import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/app_pagination_bar.dart';
import '../../../../core/widgets/responsive_shimmer.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../domain/entities/admin_user_entity.dart';
import '../../domain/entities/create_user_params.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';

String _adminRoleLabelAr(String? role) {
  switch (role) {
    case 'admin':
      return 'مدير النظام';
    case 'supervisor':
      return 'مشرف';
    case 'quality_inspector':
      return 'مراقب جودة';
    default:
      return 'مشغل';
  }
}

/// قسم إدارة المستخدمين والصلاحيات للأدمن (بحث + فلاتر + باجينيشن بالكامل داخل PostgreSQL)
class AdminUsersSection extends StatefulWidget {
  final bool isDesktop;

  const AdminUsersSection({super.key, required this.isDesktop});

  @override
  State<AdminUsersSection> createState() => _AdminUsersSectionState();
}

class _AdminUsersSectionState extends State<AdminUsersSection> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SettingsCubit>().ensureAdminUsersLoaded();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      final cubit = context.read<SettingsCubit>();
      cubit.updateUsersFilter(
        cubit.state.usersFilter.copyWith(search: value.trim()),
      );
    });
  }

  void _clearFilters(SettingsCubit cubit) {
    _searchDebounce?.cancel();
    _searchController.clear();
    cubit.clearUsersFilters();
  }

  Future<void> _openAddUserDialog() async {
    final settingsCubit = context.read<SettingsCubit>();
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddUserDialog(
        onSubmit: (params) => settingsCubit.createUser(params),
      ),
    );
  }

  Future<void> _openDeleteUserDialog(AdminUserEntity user) async {
    final settingsCubit = context.read<SettingsCubit>();
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeleteUserConfirmDialog(
        user: user,
        onConfirm: (reason) => settingsCubit.deleteUser(
          userId: user.id,
          fullName: user.fullName,
          reason: reason,
        ),
      ),
    );
  }

  Future<void> _confirmPermissionChange(
    AdminUserEntity user,
    bool grant,
  ) async {
    final action = grant ? 'منح' : 'سحب';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text('$action صلاحية عكس الصرف'),
          content: Text(
            'هل تريد $action صلاحية عكس مستندات الصرف للمستخدم "${user.fullName}"؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('تأكيد $action'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await context.read<SettingsCubit>().toggleDispatchReversalPermission(
      user: user,
      grant: grant,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.select<AuthCubit, String?>(
      (cubit) => cubit.state.user?.id,
    );

    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (prev, curr) =>
          prev.isUsersLoading != curr.isUsersLoading ||
          prev.usersInitialized != curr.usersInitialized ||
          prev.usersData != curr.usersData ||
          prev.usersFilter != curr.usersFilter ||
          prev.updatingUserIds != curr.updatingUserIds ||
          prev.usersFailure != curr.usersFailure,
      builder: (context, state) {
        final cubit = context.read<SettingsCubit>();
        final pageData = state.usersData.page;
        final summary = state.usersData.summary;
        final filter = state.usersFilter;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryNavy.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.zoneC2Blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      LucideIcons.shieldCheck,
                      color: AppColors.zoneC2Blue,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إدارة المستخدمين والصلاحيات',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'إضافة أو حذف الموظفين وإدارة صلاحية عكس الصرف',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.isDesktop)
                    IconButton.filledTonal(
                      tooltip: 'تحديث القائمة',
                      onPressed: state.isUsersLoading
                          ? null
                          : () => cubit.loadAdminUsers(),
                      icon: const Icon(LucideIcons.refreshCw, size: 16),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // ملخص سريع من قاعدة البيانات
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _statPill('${summary.totalUsers} موظف', AppColors.primaryNavy),
                  _statPill('${summary.activeCount} نشط', AppColors.successGreen),
                  if (summary.inactiveCount > 0)
                    _statPill(
                      '${summary.inactiveCount} موقوف',
                      AppColors.dangerRed,
                    ),
                  _statPill(
                    'عكس الصرف: ${summary.dispatchReversalCount}',
                    AppColors.zoneC2Blue,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // زر إضافة مستخدم جديد
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openAddUserDialog,
                  icon: const Icon(LucideIcons.plus, size: 17),
                  label: const Text(
                    'إضافة مستخدم جديد',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // البحث على السيرفر
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (_, val, _) => TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'بحث بالاسم أو الكود أو البريد أو الدور...',
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    suffixIcon: val.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                            icon: const Icon(LucideIcons.x, size: 16),
                          ),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.borderLight,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.borderLight,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // فلاتر الحالة والدور الوظيفي
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _filterChip(
                    label: 'الكل',
                    selected: filter.activeOnly == null && filter.role == null,
                    onTap: () => _clearFilters(cubit),
                  ),
                  _filterChip(
                    label: 'نشط',
                    selected: filter.activeOnly == true,
                    onTap: () => cubit.updateUsersFilter(
                      filter.activeOnly == true
                          ? filter.copyWith(clearActiveOnly: true)
                          : filter.copyWith(activeOnly: true),
                    ),
                  ),
                  _filterChip(
                    label: 'موقوف',
                    selected: filter.activeOnly == false,
                    onTap: () => cubit.updateUsersFilter(
                      filter.activeOnly == false
                          ? filter.copyWith(clearActiveOnly: true)
                          : filter.copyWith(activeOnly: false),
                    ),
                  ),
                  _filterChip(
                    label: 'مدير',
                    selected: filter.role == 'admin',
                    onTap: () => cubit.updateUsersFilter(
                      filter.role == 'admin'
                          ? filter.copyWith(clearRole: true)
                          : filter.copyWith(role: 'admin'),
                    ),
                  ),
                  _filterChip(
                    label: 'مشغل',
                    selected: filter.role == 'operator',
                    onTap: () => cubit.updateUsersFilter(
                      filter.role == 'operator'
                          ? filter.copyWith(clearRole: true)
                          : filter.copyWith(role: 'operator'),
                    ),
                  ),
                  if (filter.hasActiveFilters)
                    TextButton.icon(
                      onPressed: () => _clearFilters(cubit),
                      icon: const Icon(LucideIcons.rotateCcw, size: 13),
                      label: const Text('مسح', style: TextStyle(fontSize: 11.5)),
                    ),
                ],
              ),

              if (state.isUsersLoading && state.usersInitialized) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(minHeight: 2.5),
              ],
              const SizedBox(height: 12),

              // قائمة المستخدمين
              _buildUsersContent(state, cubit, currentUserId),

              if (pageData.totalCount > 0) ...[
                const SizedBox(height: 10),
                AppPaginationBar(
                  pageData: pageData,
                  isLoading: state.isUsersLoading,
                  pageSizeOptions: const [10, 20, 50],
                  onPageChanged: cubit.goToUsersPage,
                  onPageSizeChanged: cubit.changeUsersPageSize,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _statPill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    ),
  );

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) => ChoiceChip(
    label: Text(label),
    selected: selected,
    showCheckmark: false,
    visualDensity: VisualDensity.compact,
    selectedColor: AppColors.primaryNavy,
    backgroundColor: const Color(0xFFF8FAFC),
    side: BorderSide(
      color: selected ? AppColors.primaryNavy : AppColors.borderLight,
    ),
    labelStyle: TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w800,
      color: selected ? Colors.white : AppColors.primaryNavy,
    ),
    onSelected: (_) => onTap(),
  );

  Widget _buildUsersContent(
    SettingsState state,
    SettingsCubit cubit,
    String? currentUserId,
  ) {
    if (!state.usersInitialized && state.isUsersLoading) {
      return const SizedBox(
        height: 220,
        child: ResponsiveColdStorageShimmer(
          mode: ShimmerLayoutMode.tableList,
          itemCountOverride: 3,
        ),
      );
    }

    if (state.usersFailure != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تعذر تحميل المستخدمين: ${state.usersFailure!.message}',
            style: const TextStyle(color: AppColors.dangerRed, fontSize: 12),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => cubit.loadAdminUsers(),
            icon: const Icon(LucideIcons.refreshCw, size: 15),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      );
    }

    final visibleUsers = state.usersData.page.items;
    if (visibleUsers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text(
            'لا يوجد موظفون مطابقون للبحث.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: List.generate(visibleUsers.length, (idx) {
          final user = visibleUsers[idx];
          final isBusy = state.updatingUserIds.contains(user.id);
          final isSelf = user.id == currentUserId;

          return Column(
            children: [
              _UserManagementTile(
                user: user,
                isBusy: isBusy,
                canDelete: !isSelf && user.isActive,
                onToggleDispatchReversal: (val) =>
                    _confirmPermissionChange(user, val),
                onDeletePressed: () => _openDeleteUserDialog(user),
              ),
              if (idx < visibleUsers.length - 1) const Divider(height: 1),
            ],
          );
        }),
      ),
    );
  }
}

class _UserManagementTile extends StatelessWidget {
  final AdminUserEntity user;
  final bool isBusy;
  final bool canDelete;
  final ValueChanged<bool> onToggleDispatchReversal;
  final VoidCallback onDeletePressed;

  const _UserManagementTile({
    required this.user,
    required this.isBusy,
    required this.canDelete,
    required this.onToggleDispatchReversal,
    required this.onDeletePressed,
  });

  @override
  Widget build(BuildContext context) {
    final isAdminUser = user.role == 'admin';
    final codePart = user.employeeCode != null ? ' • #${user.employeeCode}' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: !user.isActive
                ? AppColors.dangerRed.withValues(alpha: 0.12)
                : isAdminUser
                ? AppColors.primaryNavy
                : AppColors.zoneC2Blue.withValues(alpha: 0.12),
            child: Icon(
              isAdminUser ? LucideIcons.shield : LucideIcons.user,
              size: 15,
              color: !user.isActive
                  ? AppColors.dangerRed
                  : isAdminUser
                  ? AppColors.accentCyan
                  : AppColors.zoneC2Blue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: user.isActive
                        ? AppColors.primaryNavy
                        : AppColors.textSecondary,
                    decoration: user.isActive
                        ? null
                        : TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_adminRoleLabelAr(user.role)}$codePart • ${user.isActive ? "نشط" : "موقوف"}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: user.isActive
                        ? AppColors.textSecondary
                        : AppColors.dangerRed,
                    fontSize: 11,
                    fontWeight: user.isActive
                        ? FontWeight.w500
                        : FontWeight.w700,
                  ),
                ),
                if (user.email.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    user.email,
                    textDirection: TextDirection.ltr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isBusy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch.adaptive(
                  value: user.canReverseDispatch,
                  activeThumbColor: AppColors.zoneC2Blue,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: user.isActive ? onToggleDispatchReversal : null,
                ),
              Text(
                user.canReverseDispatch ? 'مسموح' : 'غير مسموح',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: user.canReverseDispatch
                      ? AppColors.successGreen
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (canDelete) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'حذف حساب الموظف',
              visualDensity: VisualDensity.compact,
              onPressed: isBusy ? null : onDeletePressed,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.dangerRed.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              icon: const Icon(
                LucideIcons.trash2,
                size: 16,
                color: AppColors.dangerRed,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// نافذة إضافة مستخدم جديد
// =============================================================================
class _AddUserDialog extends StatefulWidget {
  final Future<String?> Function(CreateUserParams params) onSubmit;

  const _AddUserDialog({required this.onSubmit});

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  AppUserRole _selectedRole = AppUserRole.operator;
  bool _grantDispatchReversal = false;
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _serverError;

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _serverError = null;
    });

    final errorMessage = await widget.onSubmit(
      CreateUserParams(
        fullName: _nameCtrl.text.trim(),
        employeeCode: _codeCtrl.text.trim(),
        email: _emailCtrl.text.trim().toLowerCase(),
        password: _passwordCtrl.text,
        role: _selectedRole,
        grantDispatchReversal: _grantDispatchReversal,
      ),
    );

    if (!mounted) {
      return;
    }
    if (errorMessage == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _submitting = false;
        _serverError = errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_submitting,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
          contentPadding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.zoneC2Blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.userCheck,
                  color: AppColors.zoneC2Blue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'إضافة مستخدم جديد',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ),
              IconButton(
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop(),
                icon: const Icon(LucideIcons.x, size: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_serverError != null) ...[
                      _DialogErrorBanner(message: _serverError!),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'الاسم بالكامل',
                        hintText: 'مثال: أحمد محمود',
                        prefixIcon: Icon(LucideIcons.user, size: 18),
                        isDense: true,
                      ),
                      validator: (v) {
                        if ((v?.trim().length ?? 0) < 2) {
                          return 'يرجى إدخال اسم الموظف بالكامل';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 11),
                    TextFormField(
                      controller: _codeCtrl,
                      textInputAction: TextInputAction.next,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      decoration: const InputDecoration(
                        labelText: 'كود الموظف',
                        hintText: '11707',
                        hintTextDirection: TextDirection.ltr,
                        prefixIcon: Icon(LucideIcons.hash, size: 18),
                        isDense: true,
                      ),
                      validator: (v) {
                        if ((v?.trim() ?? '').isEmpty) {
                          return 'يرجى إدخال كود الموظف';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 11),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        hintText: 'employee@beyti.com',
                        hintTextDirection: TextDirection.ltr,
                        prefixIcon: Icon(LucideIcons.atSign, size: 18),
                        isDense: true,
                      ),
                      validator: (v) {
                        if (!_emailRegex.hasMatch(v?.trim() ?? '')) {
                          return 'يرجى إدخال بريد إلكتروني صحيح';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 11),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور (6 أحرف على الأقل)',
                        hintText: '••••••••',
                        hintTextDirection: TextDirection.ltr,
                        prefixIcon: const Icon(LucideIcons.keyRound, size: 18),
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? LucideIcons.eyeOff
                                : LucideIcons.eye,
                            size: 18,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (v) {
                        final val = v ?? '';
                        if (val.length < 6) {
                          return 'كلمة المرور يجب ألا تقل عن 6 أحرف';
                        }
                        if (val.length > 72) {
                          return 'كلمة المرور يجب ألا تزيد عن 72 حرفاً';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 11),
                    TextFormField(
                      controller: _confirmPasswordCtrl,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'تأكيد كلمة المرور',
                        hintText: '••••••••',
                        hintTextDirection: TextDirection.ltr,
                        prefixIcon: Icon(LucideIcons.lock, size: 18),
                        isDense: true,
                      ),
                      validator: (v) {
                        if (v != _passwordCtrl.text) {
                          return 'كلمتا المرور غير متطابقتين';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<AppUserRole>(
                      initialValue: _selectedRole,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'الصلاحية (الدور الوظيفي)',
                        prefixIcon: Icon(LucideIcons.shield, size: 18),
                        isDense: true,
                      ),
                      items: AppUserRole.values
                          .map(
                            (role) => DropdownMenuItem<AppUserRole>(
                              value: role,
                              child: Text(
                                role.arLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _submitting
                          ? null
                          : (val) {
                              if (val != null) {
                                setState(() => _selectedRole = val);
                              }
                            },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedRole.description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: SwitchListTile.adaptive(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        value: _grantDispatchReversal,
                        activeThumbColor: AppColors.zoneC2Blue,
                        title: const Text(
                          'منح صلاحية عكس مستندات الصرف',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                        subtitle: const Text(
                          'يمكن تعديلها لاحقاً في أي وقت من قائمة الصلاحيات',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        onChanged: _submitting
                            ? null
                            : (v) =>
                                  setState(() => _grantDispatchReversal = v),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _submitting ? null : () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            AppActionButton(
              label: 'إنشاء المستخدم',
              icon: LucideIcons.check,
              isLoading: _submitting,
              variant: AppButtonVariant.success,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// نافذة تأكيد حذف حساب موظف
// =============================================================================
class _DeleteUserConfirmDialog extends StatefulWidget {
  final AdminUserEntity user;
  final Future<String?> Function(String reason) onConfirm;

  const _DeleteUserConfirmDialog({
    required this.user,
    required this.onConfirm,
  });

  @override
  State<_DeleteUserConfirmDialog> createState() =>
      _DeleteUserConfirmDialogState();
}

class _DeleteUserConfirmDialogState extends State<_DeleteUserConfirmDialog> {
  final TextEditingController _reasonCtrl = TextEditingController(
    text: 'حذف حساب موظف',
  );
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final cleanReason = _reasonCtrl.text.trim();
    if (cleanReason.isEmpty) {
      setState(() => _errorMessage = 'يرجى كتابة سبب حذف الحساب.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final err = await widget.onConfirm(cleanReason);
    if (!mounted) {
      return;
    }
    if (err == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _submitting = false;
        _errorMessage = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final codeText = widget.user.employeeCode != null
        ? ' (#${widget.user.employeeCode})'
        : '';

    return PopScope(
      canPop: !_submitting,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              const Icon(LucideIcons.triangleAlert, color: AppColors.dangerRed),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'تأكيد حذف حساب الموظف',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ),
              IconButton(
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop(),
                icon: const Icon(LucideIcons.x, size: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: AppColors.dangerRed.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.dangerRed.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    'أنت على وشك حذف حساب الموظف "${widget.user.fullName}"$codeText — (${_adminRoleLabelAr(widget.user.role)}).\n'
                    '• إذا لم يسجل حركات مخزنية: سيتم حذف الحساب نهائياً.\n'
                    '• إذا كان له حركات سابقة: سيتم إيقاف الحساب وسحب صلاحياته ومنعه من الدخول نهائياً مع حفظ اسمه في سجل الحركات والتقارير.',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.55,
                      color: AppColors.primaryNavy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reasonCtrl,
                  enabled: !_submitting,
                  maxLines: 2,
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'سبب الحذف (يُوثّق في سجل التدقيق)',
                    prefixIcon: const Icon(LucideIcons.fileText, size: 18),
                    errorText: _errorMessage,
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _submitting ? null : () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            AppActionButton(
              label: 'تأكيد الحذف',
              icon: LucideIcons.trash2,
              isLoading: _submitting,
              variant: AppButtonVariant.danger,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogErrorBanner extends StatelessWidget {
  final String message;

  const _DialogErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.dangerRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.circleAlert,
            color: AppColors.dangerRed,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.dangerRed,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/responsive_shimmer.dart';
import '../../../auth/domain/entities/auth_user_entity.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _globalDaysCtrl = TextEditingController();
  final TextEditingController _userDaysCtrl = TextEditingController();
  final TextEditingController _newPasswordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  bool _notificationsEnabled = true;
  bool _receiveMondayAlert = true;
  bool _obscurePassword = true;
  bool _controllersSynced = false;
  int _activeMobileSection = 0;

  @override
  void dispose() {
    _globalDaysCtrl.dispose();
    _userDaysCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _syncControllersWithState(SettingsState state) {
    if (!_controllersSynced && !state.isLoading) {
      _globalDaysCtrl.text = state.settings.globalThresholdDays.toString();
      _userDaysCtrl.text = state.settings.userCustomAlertDays.toString();
      _notificationsEnabled = state.settings.notificationsEnabled;
      _receiveMondayAlert = state.settings.receiveMondayAlert;
      _controllersSynced = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = context.watch<AuthCubit>().state.user;
    final isAdmin = authUser?.role == 'admin';

    return BlocConsumer<SettingsCubit, SettingsState>(
      listener: (context, state) {
        _syncControllersWithState(state);
        if (state.failure != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.failure!.message),
                backgroundColor: AppColors.dangerRed,
                behavior: SnackBarBehavior.floating,
              ),
            );
        } else if (state.successMessage != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: AppColors.successGreen,
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      },
      builder: (context, state) {
        if (state.isLoading) {
          return const ResponsiveColdStorageShimmer(
            mode: ShimmerLayoutMode.dashboardCards,
            itemCountOverride: 3,
          );
        }

        _syncControllersWithState(state);

        return RepaintBoundary(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 960;
              final pad = isDesktop ? 24.0 : 14.0;

              final maxSectionIndex = isAdmin ? 2 : 1;
              final effectiveSection = _activeMobileSection.clamp(
                0,
                maxSectionIndex,
              );

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(pad, 14, pad, 28),
                    children: [
                      // 1. بطاقة الملف الشخصي العلوية المدمجة
                      _CompactProfileBanner(
                        user: authUser,
                        onSignOut: () => context.read<AuthCubit>().signOut(),
                      ),
                      const SizedBox(height: 14),

                      // 2. على الموبايل: شريط أقسام متناسق يمنع التكدس الطولي
                      if (!isDesktop) ...[
                        _SettingsSectionSwitcher(
                          isAdmin: isAdmin,
                          selectedIndex: effectiveSection,
                          onSelect: (idx) =>
                              setState(() => _activeMobileSection = idx),
                        ),
                        const SizedBox(height: 14),
                        if (effectiveSection == 0)
                          _buildNotificationsCard(context, state)
                        else if (isAdmin && effectiveSection == 1)
                          const _AdminPermissionsSection()
                        else
                          _buildPasswordCard(context),
                      ] else ...[
                        // على الكمبيوتر: توزيع شبكي متوازن من عمودين
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: Column(
                                children: [
                                  _buildNotificationsCard(context, state),
                                  const SizedBox(height: 16),
                                  _buildPasswordCard(context),
                                ],
                              ),
                            ),
                            if (isAdmin) ...[
                              const SizedBox(width: 16),
                              const Expanded(
                                flex: 5,
                                child: _AdminPermissionsSection(),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ===========================================================================
  // بطاقة إعدادات التنبيهات قبل الإعدامات (متناسقة ومدمجة)
  // ===========================================================================
  Widget _buildNotificationsCard(BuildContext context, SettingsState state) {
    const presetDays = [3, 4, 7, 10, 14];
    final selectedDays = int.tryParse(_userDaysCtrl.text.trim());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.zoneC2Blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.bellRing,
                  color: AppColors.zoneC2Blue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إعدادات التنبيهات والصلاحية',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    Text(
                      'تحديد مهلة التنبيه قبل انتهاء صلاحية الأصناف بالراكات',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 22),

          // اختيار سريع لأيام التنبيه في صف واحد متناسق (5 كبسولات متساوية)
          const Text(
            'اختيار سريع للمهلة الشخصية (بالأيام):',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: presetDays.map((days) {
              final isSelected = selectedDays == days;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: days == 14 ? 0 : 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () =>
                        setState(() => _userDaysCtrl.text = days.toString()),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.zoneC2Blue
                            : AppColors.scaffoldBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.zoneC2Blue
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$days',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.primaryNavy,
                            ),
                          ),
                          Text(
                            'أيام',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white70
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // الحقول الرقمية متجاورة في صف واحد مع عناوين واضحة وغير مقطوعة
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تنبيهي الشخصي (يوم)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _userDaysCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.primaryNavy,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(LucideIcons.calendarClock, size: 18),
                        suffixText: 'يوم',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الحد العام للثلاجة (يوم)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _globalDaysCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.primaryNavy,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(LucideIcons.building, size: 18),
                        suffixText: 'يوم',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // المفاتيح داخل حاوية موحدة أنيقة
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  value: _notificationsEnabled,
                  activeColor: AppColors.zoneC2Blue,
                  title: const Text(
                    'تفعيل إشعارات الصلاحية لحسابي',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  subtitle: const Text(
                    'إظهار تنبيهات الأصناف المقتربة من الانتهاء',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  onChanged: (v) => setState(() => _notificationsEnabled = v),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  value: _receiveMondayAlert,
                  activeColor: AppColors.zoneC2Blue,
                  title: const Text(
                    'التقرير الأسبوعي (يوم الإثنين 8 ص)',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  subtitle: const Text(
                    'ملخص تلقائي بحالة إشغال الثلاجة والصلاحيات',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  onChanged: (v) => setState(() => _receiveMondayAlert = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          AppActionButton(
            label: 'حفظ إعدادات التنبيهات',
            icon: LucideIcons.save,
            fullWidth: true,
            isLoading: state.isSubmitting,
            variant: AppButtonVariant.success,
            onPressed: () async {
              final gDays =
                  int.tryParse(_globalDaysCtrl.text.trim()) ??
                  state.settings.globalThresholdDays;
              final uDays =
                  int.tryParse(_userDaysCtrl.text.trim()) ??
                  state.settings.userCustomAlertDays;
              await context.read<SettingsCubit>().saveNotificationSettings(
                globalThresholdDays: gDays,
                userCustomAlertDays: uDays,
                notificationsEnabled: _notificationsEnabled,
                receiveMondayAlert: _receiveMondayAlert,
              );
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // بطاقة تغيير كلمة المرور (متناسقة وبدون قطع لعناوين الحقول)
  // ===========================================================================
  Widget _buildPasswordCard(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, authState) {
        if (authState.successMessage != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(authState.successMessage!),
                backgroundColor: AppColors.successGreen,
                behavior: SnackBarBehavior.floating,
              ),
            );
          _newPasswordCtrl.clear();
          _confirmPasswordCtrl.clear();
        } else if (authState.failure != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(authState.failure!.message),
                backgroundColor: AppColors.dangerRed,
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      },
      builder: (context, authState) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.keyRound,
                      color: AppColors.primaryNavy,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الأمان وتغيير كلمة المرور',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                        Text(
                          'تحديث كلمة المرور الخاصة بحسابك (6 أحرف على الأقل)',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 22),
              const Text(
                'كلمة المرور الجديدة',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _newPasswordCtrl,
                obscureText: _obscurePassword,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                decoration: InputDecoration(
                  hintText: '••••••••',
                  hintTextDirection: TextDirection.ltr,
                  prefixIcon: const Icon(LucideIcons.lock, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 18,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'تأكيد كلمة المرور الجديدة',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _confirmPasswordCtrl,
                obscureText: _obscurePassword,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                decoration: const InputDecoration(
                  hintText: '••••••••',
                  hintTextDirection: TextDirection.ltr,
                  prefixIcon: Icon(LucideIcons.lock, size: 18),
                ),
              ),
              const SizedBox(height: 16),
              AppActionButton(
                label: 'تحديث كلمة المرور',
                icon: LucideIcons.check,
                fullWidth: true,
                isLoading: authState.isSubmitting,
                variant: AppButtonVariant.primary,
                onPressed: () async {
                  final pass = _newPasswordCtrl.text.trim();
                  final confirm = _confirmPasswordCtrl.text.trim();
                  if (pass.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'كلمة المرور الجديدة يجب ألا تقل عن 6 أحرف.',
                        ),
                        backgroundColor: AppColors.dangerRed,
                      ),
                    );
                    return;
                  }
                  if (pass != confirm) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('كلمتا المرور غير متطابقتين!'),
                        backgroundColor: AppColors.dangerRed,
                      ),
                    );
                    return;
                  }
                  await context.read<AuthCubit>().changePassword(
                    newPassword: pass,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// 1. بطاقة الحساب الشخصي العلوية المدمجة (Compact Profile Banner)
// =============================================================================
class _CompactProfileBanner extends StatelessWidget {
  final AuthUserEntity? user;
  final VoidCallback onSignOut;

  const _CompactProfileBanner({required this.user, required this.onSignOut});

  String _roleAr(String? role) {
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

  @override
  Widget build(BuildContext context) {
    final isAdmin = user?.role == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.primaryNavy, Color(0xFF17366B)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryNavy.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Icon(
              LucideIcons.userCheck,
              color: AppColors.accentCyan,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user?.fullName ?? 'مشغل النظام',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isAdmin
                            ? AppColors.accentCyan.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _roleAr(user?.role),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: isAdmin ? AppColors.accentCyan : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  user?.employeeCode != null && user!.employeeCode!.isNotEmpty
                      ? 'كود: ${user!.employeeCode} • ${user?.email ?? ""}'
                      : (user?.email ?? '-'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: onSignOut,
            icon: const Icon(LucideIcons.logOut, size: 15),
            label: const Text(
              'خروج',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 2. شريط التبديل بين أقسام الإعدادات على الموبايل (يمنع الزحمة الطولية)
// =============================================================================
class _SettingsSectionSwitcher extends StatelessWidget {
  final bool isAdmin;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _SettingsSectionSwitcher({
    required this.isAdmin,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (label: 'التنبيهات', icon: LucideIcons.bellRing),
      if (isAdmin) (label: 'الصلاحيات', icon: LucideIcons.shieldCheck),
      (label: 'كلمة المرور', icon: LucideIcons.keyRound),
    ];

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: List.generate(tabs.length, (idx) {
          final item = tabs[idx];
          final active = selectedIndex == idx;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onSelect(idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                decoration: BoxDecoration(
                  color: active ? AppColors.primaryNavy : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.icon,
                      size: 15,
                      color: active
                          ? AppColors.accentCyan
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: active
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// =============================================================================
// 3. قسم إدارة المستخدمين وصلاحية عكس الصرف (صفوف مدمجة وأنيقة)
// =============================================================================
class _AdminPermissionsSection extends StatefulWidget {
  const _AdminPermissionsSection();

  @override
  State<_AdminPermissionsSection> createState() =>
      _AdminPermissionsSectionState();
}

class _AdminPermissionsSectionState extends State<_AdminPermissionsSection> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  List<_PermissionUser> _users = [];
  bool _loading = true;
  String? _error;
  final Set<String> _updatingIds = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final profiles = await _supabase
          .from('profiles')
          .select('id, full_name, employee_code, role, is_active')
          .order('role')
          .order('full_name');
      final permissions = await _supabase
          .from('profile_permissions')
          .select('profile_id, permission_code')
          .eq('permission_code', 'dispatch_reversal');

      final grantedIds = <String>{
        for (final row in permissions) (row['profile_id'] as String).toString(),
      };
      final users = profiles.map((row) {
        final map = Map<String, dynamic>.from(row);
        return _PermissionUser(
          id: map['id'].toString(),
          name: (map['full_name'] as String?)?.trim().isNotEmpty == true
              ? (map['full_name'] as String).trim()
              : 'مستخدم بدون اسم',
          employeeCode: (map['employee_code'] as String?)?.trim(),
          role: (map['role'] as String?) ?? 'operator',
          isActive: map['is_active'] as bool? ?? false,
          canReverseDispatch: grantedIds.contains(map['id'].toString()),
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _changePermission(_PermissionUser user, bool grant) async {
    final action = grant ? 'منح' : 'سحب';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('$action صلاحية عكس الصرف'),
          content: Text(
            'هل تريد $action صلاحية عكس مستندات الصرف للمستخدم "${user.name}"؟',
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
    if (confirmed != true || !mounted) return;

    setState(() => _updatingIds.add(user.id));
    try {
      await _supabase.rpc(
        grant
            ? 'rpc_grant_profile_permission'
            : 'rpc_revoke_profile_permission',
        params: {'p_profile_id': user.id},
      );
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم $action صلاحية عكس الصرف للمستخدم ${user.name}'),
          backgroundColor: AppColors.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر $action الصلاحية: $e'),
          backgroundColor: AppColors.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingIds.remove(user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final visibleUsers = _users.where((user) {
      return user.name.toLowerCase().contains(query) ||
          (user.employeeCode ?? '').toLowerCase().contains(query) ||
          user.role.toLowerCase().contains(query);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.zoneC2Blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.shieldCheck,
                  color: AppColors.zoneC2Blue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'صلاحيات عكس الصرف للموظفين',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    Text(
                      'تفعيل أو إيقاف صلاحية التراجع عن مستندات الصرف',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'تحديث القائمة',
                onPressed: _loading ? null : _loadUsers,
                icon: const Icon(LucideIcons.refreshCw, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'بحث باسم الموظف أو الكود...',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const SizedBox(
              height: 220,
              child: ResponsiveColdStorageShimmer(
                mode: ShimmerLayoutMode.tableList,
                itemCountOverride: 3,
              ),
            )
          else if (_error != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تعذر تحميل المستخدمين: $_error',
                  style: const TextStyle(
                    color: AppColors.dangerRed,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _loadUsers,
                  icon: const Icon(LucideIcons.refreshCw, size: 15),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            )
          else if (visibleUsers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'لا يوجد موظفون مطابقون للبحث.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: List.generate(visibleUsers.length, (idx) {
                  final user = visibleUsers[idx];
                  final busy = _updatingIds.contains(user.id);
                  final isAdminUser = user.role == 'admin';

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 17,
                              backgroundColor: isAdminUser
                                  ? AppColors.primaryNavy
                                  : AppColors.zoneC2Blue.withValues(
                                      alpha: 0.12,
                                    ),
                              child: Icon(
                                isAdminUser
                                    ? LucideIcons.shield
                                    : LucideIcons.user,
                                size: 15,
                                color: isAdminUser
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
                                    user.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: AppColors.primaryNavy,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_roleLabel(user.role)}${user.employeeCode != null ? " • #${user.employeeCode}" : ""} • ${user.isActive ? "نشط" : "موقوف"}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (busy)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                else
                                  Switch.adaptive(
                                    value: user.canReverseDispatch,
                                    activeColor: AppColors.zoneC2Blue,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    onChanged: user.isActive
                                        ? (value) =>
                                              _changePermission(user, value)
                                        : null,
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
                          ],
                        ),
                      ),
                      if (idx < visibleUsers.length - 1)
                        const Divider(height: 1),
                    ],
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
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
}

class _PermissionUser {
  final String id;
  final String name;
  final String? employeeCode;
  final String role;
  final bool isActive;
  final bool canReverseDispatch;

  const _PermissionUser({
    required this.id,
    required this.name,
    this.employeeCode,
    required this.role,
    required this.isActive,
    required this.canReverseDispatch,
  });
}
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/responsive_shimmer.dart';
import '../../../auth/domain/entities/auth_user_entity.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../domain/entities/notification_settings_entity.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';
import '../widgets/admin_users_section.dart';

// =============================================================================
// أدوات مساعدة مشتركة داخل شاشة الإعدادات
// =============================================================================
String _roleLabelAr(String? role) {
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

void _showFeedbackSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.dangerRed : AppColors.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

// =============================================================================
// 1. الشاشة الرئيسية للإعدادات (تخطيط متجاوب نظيف بدون تكرار)
// =============================================================================
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _activeMobileSection = 0;

  @override
  Widget build(BuildContext context) {
    final authUser = context.watch<AuthCubit>().state.user;
    final isAdmin = authUser?.role == 'admin';

    return BlocConsumer<SettingsCubit, SettingsState>(
      listenWhen: (prev, curr) =>
          prev.failure != curr.failure ||
          prev.successMessage != curr.successMessage,
      listener: (context, state) {
        final isOffstage =
            context.findAncestorWidgetOfExactType<Offstage>()?.offstage ??
            false;
        if (isOffstage) {
          return;
        }
        if (state.failure != null) {
          _showFeedbackSnackBar(context, state.failure!.message, isError: true);
        } else if (state.successMessage != null) {
          _showFeedbackSnackBar(context, state.successMessage!);
        }
      },
      buildWhen: (prev, curr) =>
          prev.isLoading != curr.isLoading ||
          prev.isSubmitting != curr.isSubmitting ||
          prev.settings != curr.settings,
      builder: (context, state) {
        if (state.isLoading) {
          return const ResponsiveColdStorageShimmer(
            mode: ShimmerLayoutMode.dashboardCards,
            itemCountOverride: 3,
          );
        }

        return RepaintBoundary(
          child: RefreshIndicator(
            onRefresh: () async {
              final cubit = context.read<SettingsCubit>();
              await Future.wait([
                cubit.loadSettings(),
                if (isAdmin) cubit.loadAdminUsers(),
              ]);
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 960;
                final pad = isDesktop ? 24.0 : 14.0;
                final effectiveSection = _activeMobileSection.clamp(
                  0,
                  isAdmin ? 2 : 1,
                );

                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(pad, 14, pad, 28),
                      children: [
                        _CompactProfileBanner(
                          user: authUser,
                          onSignOut: () => context.read<AuthCubit>().signOut(),
                        ),
                        const SizedBox(height: 14),
                        if (!isDesktop)
                          _buildMobileBody(state, isAdmin, effectiveSection)
                        else
                          _buildDesktopBody(state, isAdmin),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileBody(
    SettingsState state,
    bool isAdmin,
    int effectiveSection,
  ) {
    return Column(
      children: [
        _SettingsSectionSwitcher(
          isAdmin: isAdmin,
          selectedIndex: effectiveSection,
          onSelect: (idx) => setState(() => _activeMobileSection = idx),
        ),
        const SizedBox(height: 14),
        if (effectiveSection == 0)
          _NotificationsSettingsCard(
            settings: state.settings,
            isSubmitting: state.isSubmitting,
            isAdmin: isAdmin,
          )
        else if (isAdmin && effectiveSection == 1)
          const AdminUsersSection(isDesktop: false)
        else
          const _ChangePasswordCard(),
      ],
    );
  }

  Widget _buildDesktopBody(SettingsState state, bool isAdmin) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: Column(
            children: [
              _NotificationsSettingsCard(
                settings: state.settings,
                isSubmitting: state.isSubmitting,
                isAdmin: isAdmin,
              ),
              const SizedBox(height: 16),
              const _ChangePasswordCard(),
            ],
          ),
        ),
        if (isAdmin) ...[
          const SizedBox(width: 16),
          const Expanded(flex: 5, child: AdminUsersSection(isDesktop: true)),
        ],
      ],
    );
  }
}

// =============================================================================
// 2. مكونات التصميم المشتركة للبطاقات (Shared Card Primitives)
// =============================================================================
class _SettingsCardContainer extends StatelessWidget {
  final Widget child;

  const _SettingsCardContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: child,
    );
  }
}

class _SectionCardHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;

  const _SectionCardHeader({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 3. بطاقة الملف الشخصي العلوية وشريط التبديل للموبايل
// =============================================================================
class _CompactProfileBanner extends StatelessWidget {
  final AuthUserEntity? user;
  final VoidCallback onSignOut;

  const _CompactProfileBanner({required this.user, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final isAdmin = user?.role == 'admin';
    final hasCode =
        user?.employeeCode != null && user!.employeeCode!.trim().isNotEmpty;

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
                        _roleLabelAr(user?.role),
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
                  hasCode
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
      if (isAdmin) (label: 'المستخدمون', icon: LucideIcons.shieldCheck),
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
// 4. بطاقة إعدادات التنبيهات والصلاحية (مستقلة بدورة حياة حقولها)
// =============================================================================
class _NotificationsSettingsCard extends StatefulWidget {
  final NotificationSettingsEntity settings;
  final bool isSubmitting;
  final bool isAdmin;

  const _NotificationsSettingsCard({
    required this.settings,
    required this.isSubmitting,
    required this.isAdmin,
  });

  @override
  State<_NotificationsSettingsCard> createState() =>
      _NotificationsSettingsCardState();
}

class _NotificationsSettingsCardState
    extends State<_NotificationsSettingsCard> {
  static const List<int> _presetDays = [3, 4, 7, 10, 14];

  late final TextEditingController _globalDaysCtrl;
  late final TextEditingController _userDaysCtrl;
  late bool _notificationsEnabled;
  late bool _receiveMondayAlert;

  @override
  void initState() {
    super.initState();
    _globalDaysCtrl = TextEditingController(
      text: widget.settings.globalThresholdDays.toString(),
    );
    _userDaysCtrl = TextEditingController(
      text: widget.settings.userCustomAlertDays.toString(),
    );
    _notificationsEnabled = widget.settings.notificationsEnabled;
    _receiveMondayAlert = widget.settings.receiveMondayAlert;
  }

  @override
  void didUpdateWidget(covariant _NotificationsSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _globalDaysCtrl.text = widget.settings.globalThresholdDays.toString();
      _userDaysCtrl.text = widget.settings.userCustomAlertDays.toString();
      _notificationsEnabled = widget.settings.notificationsEnabled;
      _receiveMondayAlert = widget.settings.receiveMondayAlert;
    }
  }

  @override
  void dispose() {
    _globalDaysCtrl.dispose();
    _userDaysCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final gDays =
        int.tryParse(_globalDaysCtrl.text.trim()) ??
        widget.settings.globalThresholdDays;
    final uDays =
        int.tryParse(_userDaysCtrl.text.trim()) ??
        widget.settings.userCustomAlertDays;

    await context.read<SettingsCubit>().saveNotificationSettings(
      globalThresholdDays: gDays,
      userCustomAlertDays: uDays,
      notificationsEnabled: _notificationsEnabled,
      receiveMondayAlert: _receiveMondayAlert,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDays = int.tryParse(_userDaysCtrl.text.trim());

    return _SettingsCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionCardHeader(
            icon: LucideIcons.bellRing,
            iconColor: AppColors.zoneC2Blue,
            iconBackground: AppColors.zoneC2Blue.withValues(alpha: 0.1),
            title: 'إعدادات التنبيهات والصلاحية',
            subtitle: 'تحديد مهلة التنبيه قبل انتهاء صلاحية الأصناف بالراكات',
          ),
          const Divider(height: 22),
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
            children: _presetDays.map((days) {
              final isSelected = selectedDays == days;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: days == _presetDays.last ? 0 : 6,
                  ),
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
          Row(
            children: [
              Expanded(
                child: _buildDaysField(
                  label: 'تنبيهي الشخصي (يوم)',
                  controller: _userDaysCtrl,
                  icon: LucideIcons.calendarClock,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDaysField(
                  label: widget.isAdmin
                      ? 'الحد العام للثلاجة (يوم)'
                      : 'الحد العام (للمدير فقط)',
                  controller: _globalDaysCtrl,
                  icon: LucideIcons.building,
                  enabled: widget.isAdmin,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
                  activeThumbColor: AppColors.zoneC2Blue,
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
                  activeThumbColor: AppColors.zoneC2Blue,
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
            isLoading: widget.isSubmitting,
            variant: AppButtonVariant.success,
            onPressed: _saveSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildDaysField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool enabled = true,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          onChanged: onChanged,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: enabled ? AppColors.primaryNavy : AppColors.textSecondary,
          ),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: Icon(icon, size: 18),
            suffixText: 'يوم',
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 5. بطاقة الأمان وتغيير كلمة المرور (مستقلة بدورة حياة حقولها)
// =============================================================================
class _ChangePasswordCard extends StatefulWidget {
  const _ChangePasswordCard();

  @override
  State<_ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends State<_ChangePasswordCard> {
  final TextEditingController _newPasswordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitPasswordChange() async {
    final pass = _newPasswordCtrl.text.trim();
    final confirm = _confirmPasswordCtrl.text.trim();

    if (pass.length < 6) {
      _showFeedbackSnackBar(
        context,
        'كلمة المرور الجديدة يجب ألا تقل عن 6 أحرف.',
        isError: true,
      );
      return;
    }
    if (pass != confirm) {
      _showFeedbackSnackBar(
        context,
        'كلمتا المرور غير متطابقتين!',
        isError: true,
      );
      return;
    }
    await context.read<AuthCubit>().changePassword(newPassword: pass);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listenWhen: (prev, curr) =>
          prev.successMessage != curr.successMessage ||
          prev.failure != curr.failure,
      listener: (context, authState) {
        final isOffstage =
            context.findAncestorWidgetOfExactType<Offstage>()?.offstage ??
            false;
        if (isOffstage) {
          return;
        }
        if (authState.successMessage != null) {
          _showFeedbackSnackBar(context, authState.successMessage!);
          _newPasswordCtrl.clear();
          _confirmPasswordCtrl.clear();
        } else if (authState.failure != null) {
          _showFeedbackSnackBar(
            context,
            authState.failure!.message,
            isError: true,
          );
        }
      },
      builder: (context, authState) {
        return _SettingsCardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionCardHeader(
                icon: LucideIcons.keyRound,
                iconColor: AppColors.primaryNavy,
                iconBackground: AppColors.primaryNavy.withValues(alpha: 0.08),
                title: 'الأمان وتغيير كلمة المرور',
                subtitle: 'تحديث كلمة المرور الخاصة بحسابك (6 أحرف على الأقل)',
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
                onPressed: _submitPasswordChange,
              ),
            ],
          ),
        );
      },
    );
  }
}
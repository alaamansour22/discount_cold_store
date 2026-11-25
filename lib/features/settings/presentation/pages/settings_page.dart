import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../widgets/admin_users_section.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/responsive_shimmer.dart';
import '../../../auth/domain/entities/auth_user_entity.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../domain/entities/create_user_params.dart';
import '../../domain/entities/notification_settings_entity.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';

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
// 1. الشاشة الرئيسية للإعدادات (تخطيط متجاوب فقط بدون تكدس منطق داخلي)
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
  final Widget? trailing;

  const _SectionCardHeader({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    this.trailing,
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
        ?trailing,
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

  const _NotificationsSettingsCard({
    required this.settings,
    required this.isSubmitting,
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
                  padding: EdgeInsets.only(left: days == _presetDays.last ? 0 : 6),
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
                  label: 'الحد العام للثلاجة (يوم)',
                  controller: _globalDaysCtrl,
                  icon: LucideIcons.building,
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
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          onChanged: onChanged,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: AppColors.primaryNavy,
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


// ignore: unused_element
class _UserManagementTile extends StatelessWidget {
  final _PermissionUser user;
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
                  user.name,
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
                  '${_roleLabelAr(user.role)}$codePart • ${user.isActive ? "نشط" : "موقوف"}',
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
                  activeColor: AppColors.zoneC2Blue,
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
// 7. نافذة إضافة مستخدم جديد
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
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

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

    if (!mounted) return;
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
                        activeColor: AppColors.zoneC2Blue,
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
// 8. نافذة تأكيد حذف حساب موظف
// =============================================================================
class _DeleteUserConfirmDialog extends StatefulWidget {
  final _PermissionUser user;
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
    if (_submitting) return;
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
    if (!mounted) return;
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
                    'أنت على وشك حذف حساب الموظف "${widget.user.name}"$codeText — (${_roleLabelAr(widget.user.role)}).\n'
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

// =============================================================================
// 9. نموذج العرض الداخلي لقائمة الموظفين
// =============================================================================
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
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/responsive_shimmer.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';

/// شاشة الموديول السادس (الإعدادات فقط):
/// 1. ضبط التنبيهات قبل الإعدامات (مدة تنبيه اليوزر 4 أو 7 أيام + الحد العام + تقرير الإثنين)
/// 2. تغيير كلمة المرور الخاصة بالمستخدم
/// 3. بيانات الحساب وتسجيل الخروج
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

    return BlocConsumer<SettingsCubit, SettingsState>(
      listener: (context, state) {
        _syncControllersWithState(state);
        if (state.failure != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.failure!.message),
              backgroundColor: AppColors.dangerRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
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
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. بطاقة بيانات الحساب الشخصي وتسجيل الخروج
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 12,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor:
                                AppColors.zoneC2Blue.withValues(alpha: 0.14),
                            child: const Icon(
                              LucideIcons.userCheck,
                              color: AppColors.zoneC2Blue,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                authUser?.fullName ?? 'مشغل النظام',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryNavy,
                                ),
                              ),
                              Text(
                                'البريد: ${authUser?.email ?? "-"} | الصلاحية: ${authUser?.role ?? "operator"}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      AppActionButton(
                        label: 'تسجيل الخروج من الحساب',
                        icon: LucideIcons.logOut,
                        variant: AppButtonVariant.danger,
                        onPressed: () => context.read<AuthCubit>().signOut(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. بطاقة إعدادات التنبيهات قبل الإعدامات (توقيت مصر)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(LucideIcons.bellRing, color: AppColors.zoneC2Blue),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'إعدادات التنبيهات قبل الإعدامات (بتوقيت مصر)',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'حدد عدد الأيام التي تريد أن ينبهك النظام قبلها عند اقتراب انتهاء صلاحية أي صنف في الراكات (C2 & C3).',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Divider(height: 24),

                      // أزرار اختيار سريعة لأيام التنبيه الشخصي (3، 4، 7، 10، 14 يوم)
                      const Text(
                        'اختيار سريع لمدة تنبيهك الشخصي:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [3, 4, 7, 10, 14].map((days) {
                          final isSelected =
                              int.tryParse(_userDaysCtrl.text.trim()) == days;
                          return ChoiceChip(
                            selected: isSelected,
                            selectedColor: AppColors.zoneC2Blue,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                            label: Text('قبل $days أيام'),
                            onSelected: (_) {
                              setState(() {
                                _userDaysCtrl.text = days.toString();
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 600;
                          final fields = [
                            TextField(
                              controller: _userDaysCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText:
                                    'مدة تنبيهك الشخصي قبل الإعدام (بالأيام)',
                                prefixIcon: Icon(LucideIcons.calendarClock),
                              ),
                            ),
                            TextField(
                              controller: _globalDaysCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText:
                                    'الحد العام لحساب الإعدامات بالثلاجة (بالأيام)',
                                prefixIcon: Icon(LucideIcons.building),
                              ),
                            ),
                          ];

                          if (isWide) {
                            return Row(
                              children: [
                                Expanded(child: fields[0]),
                                const SizedBox(width: 12),
                                Expanded(child: fields[1]),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              fields[0],
                              const SizedBox(height: 12),
                              fields[1],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _notificationsEnabled,
                        title: const Text(
                          'تفعيل إشعارات وتنبيهات الصلاحية لحسابي',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        onChanged: (v) =>
                            setState(() => _notificationsEnabled = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _receiveMondayAlert,
                        title: const Text(
                          'استلام التقرير الأسبوعي التلقائي كل يوم إثنين الساعة 8 صباحاً',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        onChanged: (v) =>
                            setState(() => _receiveMondayAlert = v),
                      ),
                      const SizedBox(height: 12),
                      AppActionButton(
                        label: 'حفظ إعدادات التنبيهات وتحديث الفحص فوراً',
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
                          await context
                              .read<SettingsCubit>()
                              .saveNotificationSettings(
                                globalThresholdDays: gDays,
                                userCustomAlertDays: uDays,
                                notificationsEnabled: _notificationsEnabled,
                                receiveMondayAlert: _receiveMondayAlert,
                              );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. بطاقة تغيير كلمة المرور (Change Password)
              BlocConsumer<AuthCubit, AuthState>(
                listener: (context, authState) {
                  if (authState.successMessage != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(authState.successMessage!),
                        backgroundColor: AppColors.successGreen,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    _newPasswordCtrl.clear();
                    _confirmPasswordCtrl.clear();
                  } else if (authState.failure != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(authState.failure!.message),
                        backgroundColor: AppColors.dangerRed,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                builder: (context, authState) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                LucideIcons.keyRound,
                                color: AppColors.primaryNavy,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'تغيير كلمة المرور الخاصة بحسابك',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryNavy,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 600;
                              final passFields = [
                                TextField(
                                  controller: _newPasswordCtrl,
                                  obscureText: _obscurePassword,
                                  textDirection: TextDirection.ltr,
                                  decoration: InputDecoration(
                                    labelText: 'كلمة المرور الجديدة (6 أحرف على الأقل)',
                                    prefixIcon: const Icon(LucideIcons.lock),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? LucideIcons.eyeOff
                                            : LucideIcons.eye,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                  ),
                                ),
                                TextField(
                                  controller: _confirmPasswordCtrl,
                                  obscureText: _obscurePassword,
                                  textDirection: TextDirection.ltr,
                                  decoration: const InputDecoration(
                                    labelText: 'تأكيد كلمة المرور الجديدة',
                                    prefixIcon: Icon(LucideIcons.lock),
                                  ),
                                ),
                              ];

                              if (isWide) {
                                return Row(
                                  children: [
                                    Expanded(child: passFields[0]),
                                    const SizedBox(width: 12),
                                    Expanded(child: passFields[1]),
                                  ],
                                );
                              }
                              return Column(
                                children: [
                                  passFields[0],
                                  const SizedBox(height: 12),
                                  passFields[1],
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          AppActionButton(
                            label: 'تحديث كلمة المرور الآن',
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
                                    content: Text(
                                      'كلمتا المرور غير متطابقتين!',
                                    ),
                                    backgroundColor: AppColors.dangerRed,
                                  ),
                                );
                                return;
                              }
                              await context
                                  .read<AuthCubit>()
                                  .changePassword(newPassword: pass);
                            },
                          ),
                        ],
                      ),
                    ),
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
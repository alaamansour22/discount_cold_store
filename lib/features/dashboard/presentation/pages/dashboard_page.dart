import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/responsive_shimmer.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';

/// شاشة الموديول الأول (الرئيسية):
/// - معزولة بـ RepaintBoundary و LayoutBuilder لمنع أي Lag أو إعادة رسم عند ظهور الكيبورد
/// - تستخدم ResponsiveColdStorageShimmer للتحميل المتجاوب
/// - تستخدم AppActionButton الموحد لمنع الضغط المتكرر
class DashboardPage extends StatelessWidget {
  final ValueChanged<int> onQuickNavigateToTab;

  const DashboardPage({
    super.key,
    required this.onQuickNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      buildWhen: (previous, current) =>
          previous.isLoading != current.isLoading ||
          previous.stats != current.stats,
      builder: (context, state) {
        if (state.isLoading) {
          return const ResponsiveColdStorageShimmer(
            mode: ShimmerLayoutMode.dashboardCards,
          );
        }

        final s = state.stats;

        return RepaintBoundary(
          child: RefreshIndicator(
            onRefresh: () => context.read<DashboardCubit>().loadDashboard(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. البانر العلوي لملخص الثلاجة + زر التحديث الموحد من Core
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryNavy, AppColors.zoneC2Blue],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 12,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.snowflake, color: AppColors.accentCyan),
                              SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'ثلاجة مخفض (رمز C) — نظرة عامة لحظية',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'إجمالي البالتات المسكنة: ${s.occupiedSlots} من ${s.totalSlots} بنة | المتاح للتسكين الفوري: ${s.emptySlots} بنة فارغة',
                            style: const TextStyle(color: Colors.white70, fontSize: 13.5),
                          ),
                        ],
                      ),
                      AppActionButton(
                        label: 'تحديث الإحصائيات الآن',
                        icon: LucideIcons.refreshCw,
                        variant: AppButtonVariant.secondary,
                        onPressed: () =>
                            context.read<DashboardCubit>().loadDashboard(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 2. الأزرار السريعة للانتقال الفوري للموديولات (مبنية على AppActionButton + كروت سريعة)
                const Text(
                  'الوصول السريع للموديولات',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = constraints.maxWidth >= 850
                        ? 4
                        : constraints.maxWidth >= 500
                            ? 2
                            : 1;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: cols,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 126,
                      children: [
                        _QuickModuleCard(
                          title: 'الاستلام والصرف والراكات',
                          subtitle: 'تسكين الموحد والميكس (C2 & C3)',
                          buttonLabel: 'فتح الراكات',
                          icon: LucideIcons.grid3x3,
                          variant: AppButtonVariant.secondary,
                          onPressed: () => onQuickNavigateToTab(1),
                        ),
                        _QuickModuleCard(
                          title: 'تحويل بين الراكات',
                          subtitle: 'نقل بالتة من راك لراك آخر',
                          buttonLabel: 'تحويل بالتة',
                          icon: LucideIcons.arrowLeftRight,
                          variant: AppButtonVariant.success,
                          onPressed: () => onQuickNavigateToTab(2),
                        ),
                        _QuickModuleCard(
                          title: 'سجل وبحث الإعدامات',
                          subtitle: 'بحث بالفترة (${s.nearExpiryAlertsCount} تنبيه)',
                          buttonLabel: 'فحص الإعدامات',
                          icon: LucideIcons.flame,
                          variant: AppButtonVariant.danger,
                          onPressed: () => onQuickNavigateToTab(3),
                        ),
                        _QuickModuleCard(
                          title: 'الإعدادات وسجل اليوزرات',
                          subtitle: 'تغيير الباسورد وحركات الـ 40 يوزر',
                          buttonLabel: 'فتح الإعدادات',
                          icon: LucideIcons.userCog,
                          variant: AppButtonVariant.primary,
                          onPressed: () => onQuickNavigateToTab(4),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),

                // 3. بطاقات الإحصائيات التفصيلية المتجاوبة
                const Text(
                  'المؤشرات الإحصائية للثلاجة (بتوقيت مصر)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = constraints.maxWidth >= 900
                        ? 3
                        : constraints.maxWidth >= 550
                            ? 2
                            : 1;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: cols,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 132,
                      children: [
                        _StatCard(
                          title: 'إشغال منطقة C2 (راكات A - M)',
                          value: '${s.zoneC2Occupied} / ${s.zoneC2Total} بالتة',
                          subtitle: '13 راك × 16 بالتة',
                          icon: LucideIcons.warehouse,
                          color: AppColors.zoneC2Blue,
                          progress: s.zoneC2OccupancyRate,
                        ),
                        _StatCard(
                          title: 'إشغال منطقة C3 (راكات N - Z)',
                          value: '${s.zoneC3Occupied} / ${s.zoneC3Total} بالتة',
                          subtitle: '7 راكات × 16 بالتة',
                          icon: LucideIcons.boxes,
                          color: AppColors.zoneC3Teal,
                          progress: s.zoneC3OccupancyRate,
                        ),
                        _StatCard(
                          title: 'البالتات الميكس (متعددة الأصناف)',
                          value: '${s.mixedPalletsCount} بالتة ميكس',
                          subtitle:
                              'إجمالي الأصناف النشطة: ${s.activeItemsCount} صنف',
                          icon: LucideIcons.layers,
                          color: AppColors.mixedPurple,
                          progress: s.occupiedSlots == 0
                              ? 0
                              : s.mixedPalletsCount / s.occupiedSlots,
                        ),
                        _StatCard(
                          title: 'أصناف مقتربة/مستحقة للإعدام',
                          value: '${s.nearExpiryAlertsCount} صنف',
                          subtitle:
                              'منتهي فعلياً: ${s.expiredItemsCount} | حد تنبيهك: ${s.userAlertDays} يوم',
                          icon: LucideIcons.triangleAlert,
                          color: AppColors.dangerRed,
                          progress: s.activeItemsCount == 0
                              ? 0
                              : s.nearExpiryAlertsCount / s.activeItemsCount,
                        ),
                        _StatCard(
                          title: 'إجمالي عمليات الإعدام المعتمدة',
                          value: '${s.totalCondemnedRecordsCount} عملية إعدام',
                          subtitle: 'موثقة في سجل الإعدامات',
                          icon: LucideIcons.trash2,
                          color: AppColors.warningAmber,
                          progress: 1.0,
                        ),
                        _StatCard(
                          title: 'حركات اليوم (استلام وصرف وتحويل)',
                          value: '${s.todayMovementsCount} حركة اليوم',
                          subtitle: 'إنتاج + نتيجة فحص الجودة',
                          icon: LucideIcons.activity,
                          color: AppColors.successGreen,
                          progress: 1.0,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickModuleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonLabel;
  final IconData icon;
  final AppButtonVariant variant;
  final VoidCallback onPressed;

  const _QuickModuleCard({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.icon,
    required this.variant,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            AppActionButton(
              label: buttonLabel,
              icon: icon,
              variant: variant,
              fullWidth: true,
              onPressed: onPressed,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double progress;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 18.5,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: color.withValues(alpha: 0.12),
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
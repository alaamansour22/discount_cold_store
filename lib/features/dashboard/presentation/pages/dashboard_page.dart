import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_pagination_bar.dart';
import '../../../../core/widgets/responsive_shimmer.dart';
import '../../domain/entities/dashboard_stats_entity.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';

class DashboardPage extends StatefulWidget {
  final ValueChanged<int> onQuickNavigateToTab;

  const DashboardPage({super.key, required this.onQuickNavigateToTab});

  static const int tabReceiving = 1;
  static const int tabTransfer = 3;
  static const int tabCondemnations = 5;
  static const int tabMovementsLog = 6;
  static const int tabDispatch = 7;
  static const int tabReports = 9;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // للتبديل على الموبايل بين أحدث الحركات (0) وأقرب الصلاحيات (1) لمنع زحمة الشاشة
  int _mobileFeedTab = 0;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DashboardCubit, DashboardState>(
      listenWhen: (prev, curr) =>
          prev.failure != curr.failure && curr.failure != null,
      listener: (context, state) {
        final isOffstage =
            context.findAncestorWidgetOfExactType<Offstage>()?.offstage ??
            false;
        if (isOffstage || state.failure == null) {
          return;
        }
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(state.failure!.message),
              backgroundColor: AppColors.dangerRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
      },
      buildWhen: (previous, current) =>
          previous.isLoading != current.isLoading ||
          previous.isRefreshing != current.isRefreshing ||
          previous.stats != current.stats ||
          previous.unreadNotificationsCount != current.unreadNotificationsCount,
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isDesktop = width >= 960;
                final pad = isDesktop ? 24.0 : 14.0;

                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1360),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(pad, 14, pad, 24),
                      children: [
                        // 1. بطاقة الملخص العلوية المدمجة
                        _CompactSummaryBanner(
                          stats: s,
                          isDesktop: isDesktop,
                          unreadNotifications: state.unreadNotificationsCount,
                          isRefreshing: state.isRefreshing,
                          onOpenNotifications: () =>
                              _openNotificationsDialog(context),
                          onRefresh: () =>
                              context.read<DashboardCubit>().loadDashboard(),
                          onReceiveTap: () => widget.onQuickNavigateToTab(
                            DashboardPage.tabReceiving,
                          ),
                          onDispatchTap: () => widget.onQuickNavigateToTab(
                            DashboardPage.tabDispatch,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 2. شبكة المؤشرات الرباعية المختصرة (2×2 على الموبايل، 4×1 على الكمبيوتر)
                        _CompactKpiGrid(
                          stats: s,
                          isDesktop: isDesktop,
                          onTapZone: () => widget.onQuickNavigateToTab(
                            DashboardPage.tabReceiving,
                          ),
                          onTapAlerts: () => widget.onQuickNavigateToTab(
                            DashboardPage.tabCondemnations,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // 3. الوصول السريع للأقسام
                        _CleanQuickActionsGrid(
                          stats: s,
                          width: width,
                          onNavigate: widget.onQuickNavigateToTab,
                        ),
                        const SizedBox(height: 18),

                        // 4. المتابعة السريعة (جنباً إلى جنب على الكمبيوتر، وتبويب مدمج على الموبايل)
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _RecentMovementsCard(
                                  movements: s.recentMovements,
                                  onViewAll: () => widget.onQuickNavigateToTab(
                                    DashboardPage.tabMovementsLog,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _NearestExpiryCard(
                                  items: s.criticalItems,
                                  userAlertDays: s.userAlertDays,
                                  onViewAll: () => widget.onQuickNavigateToTab(
                                    DashboardPage.tabCondemnations,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          _MobileUnifiedFeedCard(
                            selectedIndex: _mobileFeedTab,
                            onTabChanged: (idx) =>
                                setState(() => _mobileFeedTab = idx),
                            movements: s.recentMovements,
                            criticalItems: s.criticalItems,
                            userAlertDays: s.userAlertDays,
                            onViewMovements: () => widget.onQuickNavigateToTab(
                              DashboardPage.tabMovementsLog,
                            ),
                            onViewCondemnations: () =>
                                widget.onQuickNavigateToTab(
                                  DashboardPage.tabCondemnations,
                                ),
                          ),
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

  void _openNotificationsDialog(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    cubit.loadNotifications(
      filter: cubit.state.notificationsFilter.copyWith(page: 1),
    );
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const _NotificationsModalDialog(),
      ),
    );
  }
}

// =============================================================================
// 1. البانر العلوي المدمج (Compact Summary Banner)
// =============================================================================
class _CompactSummaryBanner extends StatelessWidget {
  final DashboardStatsEntity stats;
  final bool isDesktop;
  final int unreadNotifications;
  final bool isRefreshing;
  final VoidCallback onOpenNotifications;
  final VoidCallback onRefresh;
  final VoidCallback onReceiveTap;
  final VoidCallback onDispatchTap;

  const _CompactSummaryBanner({
    required this.stats,
    required this.isDesktop,
    required this.unreadNotifications,
    required this.isRefreshing,
    required this.onOpenNotifications,
    required this.onRefresh,
    required this.onReceiveTap,
    required this.onDispatchTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (stats.overallOccupancyRate * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
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
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // الصف العلوي: العنوان + زر الإشعارات (وزر التحديث على الكمبيوتر فقط)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentCyan.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.snowflake,
                  color: AppColors.accentCyan,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ثلاجة المخفض (C)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'نسبة الإشغال الكلية $pct% • حركات اليوم: ${stats.todayMovementsCount}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              _MiniHeaderIconButton(
                icon: LucideIcons.bell,
                badgeCount: unreadNotifications,
                onTap: onOpenNotifications,
              ),
              if (isDesktop) ...[
                const SizedBox(width: 8),
                _MiniHeaderIconButton(
                  icon: LucideIcons.refreshCw,
                  isSpinning: isRefreshing,
                  onTap: onRefresh,
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // شريط الأرقام الثلاثة في كبسولة زجاجية موحدة
          Container(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _BannerCounterItem(
                    label: 'المشغول حالياً',
                    value: '${stats.occupiedSlots}',
                    unit: 'بالتة',
                    valueColor: AppColors.accentCyan,
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.white.withValues(alpha: 0.14),
                ),
                Expanded(
                  child: _BannerCounterItem(
                    label: 'المتاح للتسكين',
                    value: '${stats.emptySlots}',
                    unit: 'موقع',
                    valueColor: const Color(0xFF4ADE80),
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.white.withValues(alpha: 0.14),
                ),
                Expanded(
                  child: _BannerCounterItem(
                    label: 'إجمالي السعة',
                    value: '${stats.totalSlots}',
                    unit: 'بنة',
                    valueColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // زرا العمليات الرئيسية متساويان في العرض
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onReceiveTap,
                  icon: const Icon(LucideIcons.plus, size: 17),
                  label: const Text(
                    'استلام وتسكين',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.zoneC2Blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onDispatchTap,
                  icon: const Icon(LucideIcons.packageOpen, size: 17),
                  label: const Text(
                    'إنشاء إذن صرف',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.successGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerCounterItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color valueColor;

  const _BannerCounterItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}

class _MiniHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final bool isSpinning;
  final VoidCallback onTap;

  const _MiniHeaderIconButton({
    required this.icon,
    this.badgeCount = 0,
    this.isSpinning = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Center(
            child: isSpinning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accentCyan,
                    ),
                  )
                : Badge(
                    isLabelVisible: badgeCount > 0,
                    backgroundColor: AppColors.dangerRed,
                    label: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: Icon(icon, color: Colors.white, size: 17),
                  ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 2. شبكة المؤشرات المختصرة (2×2 على الموبايل، 4×1 على الكمبيوتر)
// =============================================================================
class _CompactKpiGrid extends StatelessWidget {
  final DashboardStatsEntity stats;
  final bool isDesktop;
  final VoidCallback onTapZone;
  final VoidCallback onTapAlerts;

  const _CompactKpiGrid({
    required this.stats,
    required this.isDesktop,
    required this.onTapZone,
    required this.onTapAlerts,
  });

  @override
  Widget build(BuildContext context) {
    final c2Empty = (stats.zoneC2Total - stats.zoneC2Occupied).clamp(
      0,
      stats.zoneC2Total,
    );
    final c3Empty = (stats.zoneC3Total - stats.zoneC3Occupied).clamp(
      0,
      stats.zoneC3Total,
    );
    final hasAlerts = stats.nearExpiryAlertsCount > 0;

    final items = [
      _CompactKpiTile(
        title: 'منطقة C2 (A-M)',
        value: '${stats.zoneC2Occupied} / ${stats.zoneC2Total}',
        subtitle: 'متاح $c2Empty موقع',
        icon: LucideIcons.warehouse,
        color: AppColors.zoneC2Blue,
        progress: stats.zoneC2OccupancyRate,
        onTap: onTapZone,
      ),
      _CompactKpiTile(
        title: 'منطقة C3 (N-Z)',
        value: '${stats.zoneC3Occupied} / ${stats.zoneC3Total}',
        subtitle: 'متاح $c3Empty موقع',
        icon: LucideIcons.boxes,
        color: AppColors.zoneC3Teal,
        progress: stats.zoneC3OccupancyRate,
        onTap: onTapZone,
      ),
      _CompactKpiTile(
        title: 'الأصناف النشطة',
        value: '${stats.activeItemsCount} صنف',
        subtitle: 'منها ${stats.mixedPalletsCount} بالتة ميكس',
        icon: LucideIcons.layers,
        color: AppColors.mixedPurple,
        progress: stats.occupiedSlots == 0
            ? 0
            : stats.mixedPalletsCount / stats.occupiedSlots,
        onTap: onTapZone,
      ),
      _CompactKpiTile(
        title: 'تنبيهات الصلاحية',
        value: '${stats.nearExpiryAlertsCount} صنف',
        subtitle: stats.expiredItemsCount > 0
            ? '${stats.expiredItemsCount} منتهي فعلياً'
            : 'آمن (حد ${stats.userAlertDays} يوم)',
        icon: LucideIcons.shieldAlert,
        color: hasAlerts ? AppColors.dangerRed : AppColors.successGreen,
        progress: stats.activeItemsCount == 0
            ? 0
            : stats.nearExpiryAlertsCount / stats.activeItemsCount,
        onTap: onTapAlerts,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 4 : 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 112,
      ),
      itemBuilder: (_, i) => items[i],
    );
  }
}

class _CompactKpiTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double progress;
  final VoidCallback onTap;

  const _CompactKpiTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 15, color: color),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: color.withValues(alpha: 0.1),
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 3. الوصول السريع للأقسام (Clean Quick Actions Grid — بدون أي Overflow)
// =============================================================================
class _CleanQuickActionsGrid extends StatelessWidget {
  final DashboardStatsEntity stats;
  final double width;
  final ValueChanged<int> onNavigate;

  const _CleanQuickActionsGrid({
    required this.stats,
    required this.width,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        title: 'خريطة الراكات',
        sub: '${stats.emptySlots} متاح',
        icon: LucideIcons.grid3x3,
        color: AppColors.zoneC2Blue,
        tab: DashboardPage.tabReceiving,
      ),
      (
        title: 'إنشاء صرف',
        sub: '${stats.occupiedSlots} بالتة',
        icon: LucideIcons.packageOpen,
        color: AppColors.successGreen,
        tab: DashboardPage.tabDispatch,
      ),
      (
        title: 'تحويل راكات',
        sub: 'نقل بالتة',
        icon: LucideIcons.arrowLeftRight,
        color: AppColors.zoneC3Teal,
        tab: DashboardPage.tabTransfer,
      ),
      (
        title: 'الإعدامات',
        sub: '${stats.nearExpiryAlertsCount} تنبيه',
        icon: LucideIcons.flame,
        color: AppColors.dangerRed,
        tab: DashboardPage.tabCondemnations,
      ),
      (
        title: 'سجل الحركات',
        sub: '${stats.todayMovementsCount} اليوم',
        icon: LucideIcons.history,
        color: AppColors.primaryNavy,
        tab: DashboardPage.tabMovementsLog,
      ),
      (
        title: 'التقارير PDF',
        sub: 'طباعة شاملة',
        icon: LucideIcons.chartNoAxesCombined,
        color: AppColors.mixedPurple,
        tab: DashboardPage.tabReports,
      ),
    ];

    final cols = width >= 1100 ? 6 : 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الأقسام السريعة',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryNavy,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 98,
          ),
          itemBuilder: (_, idx) {
            final item = actions[idx];
            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => onNavigate(item.tab),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(item.icon, color: item.color, size: 17),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.15,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// =============================================================================
// 4. بطاقة المتابعة المدمجة للموبايل (تبديل بين الحركات والصلاحيات بدون زحمة)
// =============================================================================
class _MobileUnifiedFeedCard extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;
  final List<DashboardRecentMovementEntity> movements;
  final List<DashboardCriticalItemEntity> criticalItems;
  final int userAlertDays;
  final VoidCallback onViewMovements;
  final VoidCallback onViewCondemnations;

  const _MobileUnifiedFeedCard({
    required this.selectedIndex,
    required this.onTabChanged,
    required this.movements,
    required this.criticalItems,
    required this.userAlertDays,
    required this.onViewMovements,
    required this.onViewCondemnations,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _FeedSwitchButton(
                  label: 'أحدث الحركات (${movements.length})',
                  icon: LucideIcons.history,
                  isSelected: selectedIndex == 0,
                  onTap: () => onTabChanged(0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FeedSwitchButton(
                  label: 'أقرب الصلاحيات (${criticalItems.length})',
                  icon: LucideIcons.clockAlert,
                  isSelected: selectedIndex == 1,
                  onTap: () => onTabChanged(1),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          if (selectedIndex == 0)
            _MovementsListBody(
              movements: movements.take(4).toList(),
              onViewAll: onViewMovements,
            )
          else
            _ExpiryListBody(
              items: criticalItems.take(4).toList(),
              userAlertDays: userAlertDays,
              onViewAll: onViewCondemnations,
            ),
        ],
      ),
    );
  }
}

class _FeedSwitchButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FeedSwitchButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryNavy
              : AppColors.scaffoldBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? AppColors.accentCyan : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : AppColors.primaryNavy,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 5. قوائم الحركات والصلاحيات للكمبيوتر والموبايل
// =============================================================================
class _RecentMovementsCard extends StatelessWidget {
  final List<DashboardRecentMovementEntity> movements;
  final VoidCallback onViewAll;

  const _RecentMovementsCard({
    required this.movements,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.history,
                color: AppColors.zoneC2Blue,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'أحدث الحركات المخزنية',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                child: const Text('عرض الكل'),
              ),
            ],
          ),
          const Divider(height: 14),
          _MovementsListBody(
            movements: movements.take(5).toList(),
            onViewAll: null,
          ),
        ],
      ),
    );
  }
}

class _NearestExpiryCard extends StatelessWidget {
  final List<DashboardCriticalItemEntity> items;
  final int userAlertDays;
  final VoidCallback onViewAll;

  const _NearestExpiryCard({
    required this.items,
    required this.userAlertDays,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.clockAlert,
                color: AppColors.warningAmber,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'أقرب الأصناف انتهاءً للصلاحية',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                child: const Text('عرض الكل'),
              ),
            ],
          ),
          const Divider(height: 14),
          _ExpiryListBody(
            items: items.take(5).toList(),
            userAlertDays: userAlertDays,
            onViewAll: null,
          ),
        ],
      ),
    );
  }
}

class _MovementsListBody extends StatelessWidget {
  final List<DashboardRecentMovementEntity> movements;
  final VoidCallback? onViewAll;

  const _MovementsListBody({required this.movements, this.onViewAll});

  (String, Color, IconData) _movementMeta(String type) {
    switch (type) {
      case 'receive_new':
      case 'receive':
        return ('استلام', AppColors.successGreen, LucideIcons.packagePlus);
      case 'add_item_to_pallet':
      case 'add_to_pallet':
        return ('تزويد', AppColors.zoneC2Blue, LucideIcons.package);
      case 'dispatch':
        return ('صرف', AppColors.primaryNavy, LucideIcons.truck);
      case 'dispatch_reversal':
        return ('عكس صرف', AppColors.warningAmber, LucideIcons.rotateCcw);
      case 'relocate':
        return ('تحويل', AppColors.zoneC3Teal, LucideIcons.arrowLeftRight);
      case 'condemn':
        return ('إعدام', AppColors.dangerRed, LucideIcons.flame);
      case 'adjust_quantity':
        return ('تعديل', AppColors.warningAmber, LucideIcons.slidersHorizontal);
      default:
        return ('حركة', AppColors.primaryNavy, LucideIcons.activity);
    }
  }

  String _cleanSlot(String? slot) {
    if (slot == null || slot.isEmpty) {
      return '';
    }
    if (slot == 'employee_sales_outlet') {
      return 'منفذ البيع';
    }
    return slot;
  }

  String _unitAr(String u) {
    switch (u) {
      case 'shrink':
        return 'شرنك';
      case 'gallon':
        return 'جالون';
      default:
        return 'كرتونة';
    }
  }

  String _qtyFmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    if (movements.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'لا توجد حركات مسجلة حتى الآن',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      children: [
        ...movements.map((mov) {
          final (label, color, icon) = _movementMeta(mov.movementType);
          final from = _cleanSlot(mov.fromSlotCode);
          final to = _cleanSlot(mov.toSlotCode);
          final slotText = (from.isNotEmpty && to.isNotEmpty)
              ? '$from ← $to'
              : (to.isNotEmpty ? to : (from.isNotEmpty ? from : '—'));
          final timeStr = intl.DateFormat('HH:mm').format(mov.createdAt);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: color, size: 15),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mov.itemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      Text(
                        '$label • $slotText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_qtyFmt(mov.quantityChanged)} ${_unitAr(mov.unit)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        if (onViewAll != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onViewAll,
              icon: const Icon(LucideIcons.arrowLeft, size: 14),
              label: const Text('فتح سجل الحركات الكامل'),
            ),
          ),
      ],
    );
  }
}

class _ExpiryListBody extends StatelessWidget {
  final List<DashboardCriticalItemEntity> items;
  final int userAlertDays;
  final VoidCallback? onViewAll;

  const _ExpiryListBody({
    required this.items,
    required this.userAlertDays,
    this.onViewAll,
  });

  String _unitAr(String u) {
    switch (u) {
      case 'shrink':
        return 'شرنك';
      case 'gallon':
        return 'جالون';
      default:
        return 'كرتونة';
    }
  }

  String _qtyFmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'لا توجد أصناف مسكنة حالياً',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      children: [
        ...items.map((item) {
          final isExpired = item.isExpired;
          final isWarn = !isExpired && item.daysUntilExpiry <= userAlertDays;
          final color = isExpired
              ? AppColors.dangerRed
              : isWarn
              ? AppColors.warningAmber
              : AppColors.successGreen;
          final badgeText = item.daysUntilExpiry <= 0
              ? 'منتهي'
              : '${item.daysUntilExpiry} يوم';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryNavy.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    item.slotCode,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.itemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      Text(
                        'الكمية: ${_qtyFmt(item.quantity)} ${_unitAr(item.unit)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        if (onViewAll != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onViewAll,
              icon: const Icon(LucideIcons.arrowLeft, size: 14),
              label: const Text('فتح شاشة الإعدامات'),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// 6. نافذة الإشعارات والتنبيهات (Server-Side Pagination + Unread Filter)
// =============================================================================
class _NotificationsModalDialog extends StatelessWidget {
  const _NotificationsModalDialog();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 600),
          child: BlocBuilder<DashboardCubit, DashboardState>(
            buildWhen: (prev, curr) =>
                prev.isNotificationsLoading != curr.isNotificationsLoading ||
                prev.notificationsInitialized != curr.notificationsInitialized ||
                prev.notificationsData != curr.notificationsData ||
                prev.notificationsFilter != curr.notificationsFilter ||
                prev.unreadNotificationsCount != curr.unreadNotificationsCount,
            builder: (context, state) {
              final cubit = context.read<DashboardCubit>();
              final pageData = state.notificationsData.page;
              final items = pageData.items;
              final unreadOnly = state.notificationsFilter.unreadOnly;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.bellRing,
                          color: AppColors.primaryNavy,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'الإشعارات (${state.unreadNotificationsCount} غير مقروء)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                        ),
                        if (state.unreadNotificationsCount > 0)
                          TextButton(
                            onPressed: state.isNotificationsLoading
                                ? null
                                : () => cubit.markAllNotificationsRead(),
                            child: const Text('قراءة الكل'),
                          ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(LucideIcons.x, size: 18),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: Text(
                            'الكل (${state.notificationsData.summary.totalNotifications})',
                          ),
                          selected: !unreadOnly,
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                          selectedColor: AppColors.primaryNavy,
                          labelStyle: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: !unreadOnly
                                ? Colors.white
                                : AppColors.primaryNavy,
                          ),
                          onSelected: (_) => cubit.toggleUnreadOnly(false),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(
                            'غير مقروء فقط (${state.unreadNotificationsCount})',
                          ),
                          selected: unreadOnly,
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                          selectedColor: AppColors.dangerRed,
                          labelStyle: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: unreadOnly
                                ? Colors.white
                                : AppColors.primaryNavy,
                          ),
                          onSelected: (_) => cubit.toggleUnreadOnly(true),
                        ),
                      ],
                    ),
                  ),
                  if (state.isNotificationsLoading)
                    const LinearProgressIndicator(minHeight: 2.5)
                  else
                    const Divider(height: 1),
                  Expanded(
                    child:
                        !state.notificationsInitialized &&
                            state.isNotificationsLoading
                        ? const Center(child: CircularProgressIndicator())
                        : items.isEmpty
                        ? Center(
                            child: Text(
                              unreadOnly
                                  ? 'لا توجد إشعارات غير مقروءة'
                                  : 'لا توجد إشعارات حالياً',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(14),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, idx) {
                              final n = items[idx];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: n.isRead
                                      ? const Color(0xFFF8FAFC)
                                      : AppColors.zoneC2Blue.withValues(
                                          alpha: 0.06,
                                        ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: n.isRead
                                        ? AppColors.borderLight
                                        : AppColors.zoneC2Blue.withValues(
                                            alpha: 0.3,
                                          ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            n.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12.5,
                                              color: AppColors.primaryNavy,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          intl.DateFormat(
                                            'MM-dd HH:mm',
                                          ).format(n.createdAt),
                                          textDirection: TextDirection.ltr,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      n.body,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  if (pageData.totalCount > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                      child: AppPaginationBar(
                        pageData: pageData,
                        isLoading: state.isNotificationsLoading,
                        onPageChanged: cubit.goToNotificationsPage,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
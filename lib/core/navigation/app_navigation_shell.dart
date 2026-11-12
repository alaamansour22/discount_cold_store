import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../constants/app_assets.dart';
import '../theme/app_theme.dart';

class AppShellTabItem {
  final String label;
  final IconData icon;
  final Widget page;
  final int badgeCount;

  const AppShellTabItem({
    required this.label,
    required this.icon,
    required this.page,
    this.badgeCount = 0,
  });
}

/// غلاف التنقل الذكي:
/// - يستخدم resizeToAvoidBottomInset: false و LayoutBuilder بدلاً من MediaQuery.of(context)
///   حتى لا يعيد رسم الشاشات الخلفية أبداً عند فتح أو قفل الكيبورد (Zero Keyboard Lag!)
class AppNavigationShell extends StatefulWidget {
  final List<AppShellTabItem> tabs;
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final String title;
  final String? userRoleBadge;
  final int unreadNotificationsCount;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onRefreshTap;
  final List<Widget>? actions;

  const AppNavigationShell({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTabSelected,
    required this.title,
    this.userRoleBadge,
    this.unreadNotificationsCount = 0,
    this.onNotificationsTap,
    this.onRefreshTap,
    this.actions,
  });

  @override
  State<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<AppNavigationShell> {
  final List<int> _navigationHistory = [0];

  void _selectTab(int newIndex) {
    if (newIndex == widget.currentIndex) return;
    FocusManager.instance.primaryFocus?.unfocus(); // إغلاق الكيبورد بسلاسة عند التنقل
    setState(() {
      _navigationHistory.add(newIndex);
    });
    widget.onTabSelected(newIndex);
  }

  Future<void> _handleBackAttempt(bool didPop) async {
    if (didPop) return;

    if (_navigationHistory.length > 1) {
      setState(() {
        _navigationHistory.removeLast();
      });
      widget.onTabSelected(_navigationHistory.last);
      return;
    }

    if (widget.currentIndex != 0) {
      setState(() {
        _navigationHistory
          ..clear()
          ..add(0);
      });
      widget.onTabSelected(0);
      return;
    }

    final shouldExit = await _showExitDialog(context);
    if (shouldExit == true) {
      await SystemNavigator.pop();
    }
  }

  Future<bool?> _showExitDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(LucideIcons.circleAlert, color: AppColors.warningAmber),
              SizedBox(width: 10),
              Text(
                'تأكيد الخروج من التطبيق',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ],
          ),
          content: const Text(
            'هل أنت متأكد أنك تريد إغلاق تطبيق ثلاجة مخفض (رمز C)؟',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('البقاء في التطبيق'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dangerRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('خروج'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) => _handleBackAttempt(didPop),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              // منع إعادة رسم الشبكة والكروت الخلفية عند صعود الكيبورد لمنع اللاج تماماً
              resizeToAvoidBottomInset: false,
              backgroundColor: AppColors.scaffoldBackground,
              appBar: AppBar(
                backgroundColor: AppColors.primaryNavy,
                elevation: 2,
                leading: widget.currentIndex != 0
                    ? IconButton(
                        tooltip: 'رجوع للشاشة السابقة',
                        icon: const Icon(LucideIcons.arrowRight, color: Colors.white),
                        onPressed: () => _handleBackAttempt(false),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(10),
                        child: Image.asset(
                          AppAssets.logoSq,
                          errorBuilder: (_, __, ___) => const Icon(
                            LucideIcons.snowflake,
                            color: AppColors.accentCyan,
                          ),
                        ),
                      ),
                title: Text(
                  widget.title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5),
                ),
                actions: [
                  if (widget.onNotificationsTap != null)
                    IconButton(
                      tooltip: 'الإشعارات والتنبيهات',
                      onPressed: widget.onNotificationsTap,
                      icon: Badge(
                        isLabelVisible: widget.unreadNotificationsCount > 0,
                        backgroundColor: AppColors.dangerRed,
                        label: Text(
                          widget.unreadNotificationsCount.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                        child: const Icon(LucideIcons.bell),
                      ),
                    ),
                  if (widget.onRefreshTap != null)
                    IconButton(
                      tooltip: 'تحديث البيانات لحظياً',
                      onPressed: widget.onRefreshTap,
                      icon: const Icon(LucideIcons.refreshCw),
                    ),
                  if (widget.actions != null) ...widget.actions!,
                  const SizedBox(width: 8),
                ],
              ),
              body: Row(
                children: [
                  if (isDesktop)
                    RepaintBoundary(
                      child: _ModernDesktopSidebar(
                        tabs: widget.tabs,
                        currentIndex: widget.currentIndex,
                        onSelect: _selectTab,
                      ),
                    ),
                  Expanded(
                    child: RepaintBoundary(
                      child: IndexedStack(
                        index: widget.currentIndex,
                        children: widget.tabs.map((t) => t.page).toList(),
                      ),
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: isDesktop
                  ? null
                  : RepaintBoundary(
                      child: _FacebookStyleBottomBar(
                        tabs: widget.tabs,
                        currentIndex: widget.currentIndex,
                        onSelect: _selectTab,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _FacebookStyleBottomBar extends StatelessWidget {
  final List<AppShellTabItem> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const _FacebookStyleBottomBar({
    required this.tabs,
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(tabs.length, (idx) {
            final item = tabs[idx];
            final isSelected = idx == currentIndex;
            const activeColor = AppColors.zoneC2Blue;

            return Expanded(
              child: InkWell(
                onTap: () => onSelect(idx),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 220),
                      top: 0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        height: 3.5,
                        width: isSelected ? 42 : 0,
                        decoration: const BoxDecoration(
                          color: activeColor,
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Badge(
                          isLabelVisible: item.badgeCount > 0,
                          backgroundColor: AppColors.dangerRed,
                          label: Text(
                            item.badgeCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? activeColor.withValues(alpha: 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              item.icon,
                              size: isSelected ? 22 : 20,
                              color: isSelected
                                  ? activeColor
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected
                                ? activeColor
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _ModernDesktopSidebar extends StatelessWidget {
  final List<AppShellTabItem> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const _ModernDesktopSidebar({
    required this.tabs,
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 255,
      decoration: const BoxDecoration(
        color: AppColors.primaryNavy,
        border: Border(
          left: BorderSide(color: AppColors.secondarySlate, width: 1),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            decoration: const BoxDecoration(
              color: AppColors.secondarySlate,
            ),
            child: Row(
              children: [
                Image.asset(
                  AppAssets.logoSq,
                  height: 38,
                  errorBuilder: (_, __, ___) => const Icon(
                    LucideIcons.snowflake,
                    color: AppColors.accentCyan,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ثلاجة مخفض (C)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'نظام إدارة المناطق C2 & C3',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: tabs.length,
              itemBuilder: (context, idx) {
                final item = tabs[idx];
                final isSelected = idx == currentIndex;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelect(idx),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.zoneC2Blue
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            size: 20,
                            color: isSelected
                                ? Colors.white
                                : Colors.white70,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white70,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          if (item.badgeCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.dangerRed,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                item.badgeCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
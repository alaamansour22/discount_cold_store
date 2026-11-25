import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../constants/app_assets.dart';
import '../theme/app_theme.dart';

class AppShellTabItem {
  final String label;
  final String? subtitle;
  final String? section;
  final IconData icon;
  final Widget page;
  final int badgeCount;

  const AppShellTabItem({
    required this.label,
    this.subtitle,
    this.section,
    required this.icon,
    required this.page,
    this.badgeCount = 0,
  });
}

/// غلاف التنقل الاحترافي (Zero Overflow):
/// 1. شريط سفلي أنيق يعرض أهم 3 موديولات فقط + زر "كل الأقسام" الذي يفتح Bottom Sheet قابل للتمرير
/// 2. قائمة جانبية احترافية قابلة للطي على الكمبيوتر + Drawer للموبايل
/// 3. حماية كاملة لزر الرجوع PopScope وتحميل كسول للشاشات وعزل الكيبورد
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<int> _navigationHistory = [0];
  late final Set<int> _visitedTabIndices = {widget.currentIndex};
  bool _isSidebarCollapsed = false;

  @override
  void didUpdateWidget(covariant AppNavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      _visitedTabIndices.add(widget.currentIndex);
    }
  }

  void _selectTab(int newIndex) {
    if (newIndex < 0 || newIndex >= widget.tabs.length) return;
    if (newIndex == widget.currentIndex) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _visitedTabIndices.add(newIndex);
      _navigationHistory.add(newIndex);
    });
    widget.onTabSelected(newIndex);
  }

  Future<void> _handleBackAttempt(bool didPop) async {
    if (didPop) return;

    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
      return;
    }

    if (_navigationHistory.length > 1) {
      setState(() {
        _navigationHistory.removeLast();
        _visitedTabIndices.add(_navigationHistory.last);
      });
      widget.onTabSelected(_navigationHistory.last);
      return;
    }

    if (widget.currentIndex != 0) {
      setState(() {
        _navigationHistory
          ..clear()
          ..add(0);
        _visitedTabIndices.add(0);
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
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
            'هل أنت متأكد أنك تريد إغلاق تطبيق ثلاجة المخفض (رمز C)؟',
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

  /// نافذة سفلية احترافية قابلة للتمرير لعرض كافة أقسام النظام (12 قسماً) بدون Overflow
  void _showModulesBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryNavy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          LucideIcons.layoutGrid,
                          color: AppColors.primaryNavy,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'قائمة موديولات ثلاجة المخفض (C)',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                            Text(
                              'اختر القسم المطلوب للانتقال السريع',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(LucideIcons.x, size: 20),
                      ),
                    ],
                  ),
                  const Divider(height: 22),
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 6),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            mainAxisExtent: 76,
                          ),
                      itemCount: widget.tabs.length,
                      itemBuilder: (_, idx) {
                        final item = widget.tabs[idx];
                        final isSelected = idx == widget.currentIndex;

                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _selectTab(idx);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.zoneC2Blue.withValues(alpha: 0.1)
                                  : AppColors.scaffoldBackground,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.zoneC2Blue
                                    : AppColors.borderLight,
                                width: isSelected ? 1.8 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Badge(
                                  isLabelVisible: item.badgeCount > 0,
                                  backgroundColor: AppColors.dangerRed,
                                  label: Text(
                                    item.badgeCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 19,
                                    backgroundColor: isSelected
                                        ? AppColors.zoneC2Blue
                                        : Colors.white,
                                    child: Icon(
                                      item.icon,
                                      size: 18,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.primaryNavy,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.2,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w700,
                                      color: isSelected
                                          ? AppColors.zoneC2Blue
                                          : AppColors.primaryNavy,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        final currentTabTitle = widget.tabs[widget.currentIndex].label;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) => _handleBackAttempt(didPop),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              key: _scaffoldKey,
              resizeToAvoidBottomInset: false,
              backgroundColor: AppColors.scaffoldBackground,
              drawer: isDesktop
                  ? null
                  : Drawer(
                      width: 288,
                      backgroundColor: AppColors.primaryNavy,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(24),
                        ),
                      ),
                      child: _ProfessionalSidebarContent(
                        tabs: widget.tabs,
                        currentIndex: widget.currentIndex,
                        userRoleBadge: widget.userRoleBadge,
                        isDesktop: false,
                        isCollapsed: false,
                        onSelect: (idx) {
                          Navigator.of(context).pop();
                          _selectTab(idx);
                        },
                      ),
                    ),
appBar: AppBar(
                backgroundColor: AppColors.primaryNavy,
                elevation: 2,
                centerTitle: true,
                leading: !isDesktop
                    ? IconButton(
                        tooltip: 'القائمة الجانبية',
                        icon: const Icon(LucideIcons.menu, color: Colors.white),
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(10),
                        child: Image.asset(
                          AppAssets.logoSq,
                          errorBuilder: (_, _, _) => const Icon(
                            LucideIcons.snowflake,
                            color: AppColors.accentCyan,
                          ),
                        ),
                      ),
                title: Text(
                  isDesktop
                      ? '${widget.title} — $currentTabTitle'
                      : currentTabTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                        child: const Icon(LucideIcons.bell),
                      ),
                    ),
                  if (widget.onRefreshTap != null)
                    IconButton(
                      tooltip: 'تحديث البيانات',
                      onPressed: widget.onRefreshTap,
                      icon: const Icon(LucideIcons.refreshCw),
                    ),
                  if (widget.actions != null) ...widget.actions!,
                  if (!isDesktop)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 12),
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            AppAssets.logoSq,
                            height: 28,
                            width: 28,
                            errorBuilder: (_, _, _) => const Icon(
                              LucideIcons.snowflake,
                              color: AppColors.accentCyan,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 6),
                ],
              ),
              body: Row(
                children: [
                  if (isDesktop)
                    RepaintBoundary(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: _isSidebarCollapsed ? 80 : 272,
                        child: _ProfessionalSidebarContent(
                          tabs: widget.tabs,
                          currentIndex: widget.currentIndex,
                          userRoleBadge: widget.userRoleBadge,
                          isDesktop: true,
                          isCollapsed: _isSidebarCollapsed,
                          onToggleCollapse: () => setState(
                            () => _isSidebarCollapsed = !_isSidebarCollapsed,
                          ),
                          onSelect: _selectTab,
                        ),
                      ),
                    ),
                 Expanded(
                    child: RepaintBoundary(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isDesktop ? 1240 : double.infinity,
                          ),
                          child: IndexedStack(
                            index: widget.currentIndex,
                            children: List.generate(widget.tabs.length, (i) {
                              final isVisited =
                                  i == widget.currentIndex ||
                                  _visitedTabIndices.contains(i);
                              return isVisited
                                  ? widget.tabs[i].page
                                  : const SizedBox.shrink();
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: isDesktop
                  ? null
                  : RepaintBoundary(
                      child: _CompactPrimaryBottomBar(
                        tabs: widget.tabs,
                        currentIndex: widget.currentIndex,
                        onSelect: _selectTab,
                        onOpenMoreSheet: () => _showModulesBottomSheet(context),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// شريط سفلي مدمج وأنيق بدون أي Overflow
class _CompactPrimaryBottomBar extends StatelessWidget {
  final List<AppShellTabItem> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onOpenMoreSheet;

  const _CompactPrimaryBottomBar({
    required this.tabs,
    required this.currentIndex,
    required this.onSelect,
    required this.onOpenMoreSheet,
  });

  @override
  Widget build(BuildContext context) {
    final primaryIndices = <int>[
      0,
      if (tabs.length > 1) 1,
      if (tabs.length > 3) 3,
    ];

    final isSecondarySelected = !primaryIndices.contains(currentIndex);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              ...primaryIndices.map((tabIdx) {
                final item = tabs[tabIdx];
                final isSelected = currentIndex == tabIdx;
                return Expanded(
                  child: _BottomBarButton(
                    label: item.label,
                    icon: item.icon,
                    badgeCount: item.badgeCount,
                    isSelected: isSelected,
                    onTap: () => onSelect(tabIdx),
                  ),
                );
              }),
              Expanded(
                child: _BottomBarButton(
                  label: isSecondarySelected
                      ? tabs[currentIndex].label
                      : 'كل الأقسام',
                  icon: isSecondarySelected
                      ? tabs[currentIndex].icon
                      : LucideIcons.layoutGrid,
                  badgeCount: 0,
                  isSelected: isSecondarySelected,
                  onTap: onOpenMoreSheet,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBarButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final int badgeCount;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomBarButton({
    required this.label,
    required this.icon,
    required this.badgeCount,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.zoneC2Blue;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Badge(
                isLabelVisible: badgeCount > 0,
                backgroundColor: AppColors.dangerRed,
                label: Text(
                  badgeCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 9),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected ? activeColor : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? activeColor : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// محتوى السايد بار الجانبي الاحترافي (Drawer للموبايل + Sidebar قابل للطي للكمبيوتر)
class _ProfessionalSidebarContent extends StatelessWidget {
  final List<AppShellTabItem> tabs;
  final int currentIndex;
  final String? userRoleBadge;
  final bool isDesktop;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;
  final ValueChanged<int> onSelect;

  const _ProfessionalSidebarContent({
    required this.tabs,
    required this.currentIndex,
    this.userRoleBadge,
    required this.isDesktop,
    required this.isCollapsed,
    this.onToggleCollapse,
    required this.onSelect,
  });

  String? _sectionHeaderForIndex(int idx) {
    final customSection = tabs[idx].section;
    if (customSection != null && customSection.isNotEmpty) {
      if (idx == 0 || tabs[idx - 1].section != customSection) {
        return customSection;
      }
      return null;
    }

    // تقسيم ذكي افتراضي في حال عدم تمرير section صراحةً
    if (tabs.length >= 11) {
      return switch (idx) {
        0 => 'نظرة عامة',
        1 => 'العمليات والرقابة',
        7 => 'الصرف والتقارير',
        10 => 'النظام',
        _ => null,
      };
    }
    if (tabs.length >= 9) {
      return switch (idx) {
        0 => 'نظرة عامة',
        1 => 'العمليات والرقابة',
        6 => 'الصرف والتقارير',
        9 => 'النظام',
        _ => null,
      };
    }
    return idx == 0 ? 'أقسام النظام الأساسية' : null;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryNavy,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.secondarySlate,
              AppColors.primaryNavy,
              Color(0xFF0A1324),
            ],
            stops: [0.0, 0.35, 1.0],
          ),
          border: isDesktop
              ? const Border(
                  left: BorderSide(color: Colors.white10, width: 1),
                )
              : null,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==================== Brand Header ====================
              _buildSidebarHeader(),

              // ==================== Navigation Items ====================
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    isCollapsed ? 10 : 12,
                    10,
                    isCollapsed ? 10 : 12,
                    12,
                  ),
                  itemCount: tabs.length,
                  itemBuilder: (context, idx) {
                    final item = tabs[idx];
                    final isSelected = idx == currentIndex;
                    final sectionTitle = _sectionHeaderForIndex(idx);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (sectionTitle != null)
                          _buildSectionHeader(sectionTitle, isFirst: idx == 0),
                        _buildNavTile(
                          item: item,
                          isSelected: isSelected,
                          onTap: () => onSelect(idx),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // ==================== Stylish Signature Footer ====================
              _buildSignatureFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isCollapsed ? 12 : 16,
        18,
        isCollapsed ? 12 : 16,
        16,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        border: const Border(
          bottom: BorderSide(color: Colors.white12, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accentCyan.withValues(alpha: 0.7),
                      AppColors.zoneC2Blue.withValues(alpha: 0.4),
                    ],
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.5),
                  child: Image.asset(
                    AppAssets.logoSq,
                    height: isCollapsed ? 38 : 42,
                    width: isCollapsed ? 38 : 42,
                    errorBuilder: (_, _, _) => Container(
                      height: isCollapsed ? 38 : 42,
                      width: isCollapsed ? 38 : 42,
                      color: AppColors.primaryNavy,
                      child: const Icon(
                        LucideIcons.snowflake,
                        color: AppColors.accentCyan,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ثلاجة المخفض',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentCyan.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.accentCyan.withValues(alpha: 0.30),
                          ),
                        ),
                        child: const Text(
                          'مخازن المنتج التام',
                          style: TextStyle(
                            color: AppColors.accentCyan,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDesktop && onToggleCollapse != null)
                  IconButton(
                    tooltip: 'طي القائمة الجانبية',
                    onPressed: onToggleCollapse,
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    icon: const Icon(
                      LucideIcons.chevronRight,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
              ],
            ],
          ),
          if (isCollapsed && isDesktop && onToggleCollapse != null) ...[
            const SizedBox(height: 10),
            IconButton(
              tooltip: 'توسيع القائمة الجانبية',
              onPressed: onToggleCollapse,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              icon: const Icon(
                LucideIcons.chevronLeft,
                color: Colors.white70,
                size: 18,
              ),
            ),
          ],
          if (!isCollapsed &&
              userRoleBadge != null &&
              userRoleBadge!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.shieldCheck,
                    size: 14,
                    color: AppColors.accentCyan,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      userRoleBadge!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {required bool isFirst}) {
    if (isCollapsed) {
      return isFirst
          ? const SizedBox(height: 4)
          : const Padding(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Divider(height: 1, color: Colors.white12),
            );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(10, isFirst ? 4 : 14, 10, 6),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile({
    required AppShellTabItem item,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final tile = Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        hoverColor: Colors.white.withValues(alpha: 0.06),
        splashColor: AppColors.accentCyan.withValues(alpha: 0.16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 0 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      AppColors.zoneC2Blue,
                      AppColors.zoneC2Blue.withValues(alpha: 0.78),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: isSelected
                  ? AppColors.accentCyan.withValues(alpha: 0.45)
                  : Colors.transparent,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.zoneC2Blue.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: isCollapsed
              ? Center(
                  child: Badge(
                    isLabelVisible: item.badgeCount > 0,
                    backgroundColor: AppColors.dangerRed,
                    label: Text(
                      item.badgeCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 9),
                    ),
                    child: Icon(
                      item.icon,
                      size: 20,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                )
              : Row(
                  children: [
                    // شريط مؤشر نشط على الجانب الأيمن
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 3.5,
                      height: isSelected ? 22 : 0,
                      margin: EdgeInsets.only(left: isSelected ? 9 : 0),
                      decoration: BoxDecoration(
                        color: AppColors.accentCyan,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.16)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item.icon,
                        size: 18,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                          if (item.subtitle != null &&
                              item.subtitle!.trim().isNotEmpty)
                            Text(
                              item.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : Colors.white38,
                                fontSize: 10.5,
                              ),
                            ),
                        ],
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
                          borderRadius: BorderRadius.circular(10),
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

    if (isCollapsed) {
      return Tooltip(
        message: item.label,
        preferBelow: false,
        child: tile,
      );
    }
    return tile;
  }

  Widget _buildSignatureFooter() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isCollapsed ? 10 : 14,
        10,
        isCollapsed ? 10 : 14,
        14,
      ),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white10, width: 1),
        ),
      ),
      child: isCollapsed
          ? Tooltip(
              message: 'By Alaa Mansour',
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: AppColors.accentCyan.withValues(alpha: 0.25),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.code,
                    size: 16,
                    color: AppColors.accentCyan,
                  ),
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    Colors.white.withValues(alpha: 0.06),
                    AppColors.accentCyan.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.09),
                ),
              ),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4.5),
                      decoration: BoxDecoration(
                        color: AppColors.accentCyan.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(
                        LucideIcons.code,
                        size: 10,
                        color: AppColors.accentCyan,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'By ',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.4,
                              ),
                            ),
                            TextSpan(
                              text: 'Alaa Mansour',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.accentCyan,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
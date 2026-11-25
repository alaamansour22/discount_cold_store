import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../pagination/paged_result.dart';
import '../theme/app_theme.dart';

/// شريط ترقيم صفحات موحد (مضغوط في سطر واحد على الموبايل ومفصّل على الكمبيوتر)
class AppPaginationBar extends StatelessWidget {
  final PagedResult<dynamic> pageData;
  final bool isLoading;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int>? onPageSizeChanged;
  final List<int> pageSizeOptions;

  const AppPaginationBar({
    super.key,
    required this.pageData,
    required this.onPageChanged,
    this.isLoading = false,
    this.onPageSizeChanged,
    this.pageSizeOptions = const [15, 20, 50],
  });

  List<int> _visiblePages() {
    final total = pageData.totalPages;
    final current = pageData.page;
    if (total <= 5) {
      return List.generate(total, (i) => i + 1);
    }
    final start = (current - 2).clamp(1, total - 4);
    return List.generate(5, (i) => start + i);
  }

  @override
  Widget build(BuildContext context) {
    if (pageData.totalCount == 0) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        if (compact) {
          return _buildCompactMobileBar();
        }
        return _buildDesktopBar();
      },
    );
  }

  /// شريط موبايل رشيق في سطر واحد بدون إهدار للارتفاع
  Widget _buildCompactMobileBar() {
    final hasMultiplePages = pageData.totalPages > 1;
    final showSizePicker =
        onPageSizeChanged != null &&
        pageData.totalCount > pageSizeOptions.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    hasMultiplePages
                        ? '${pageData.fromItemIndex}-${pageData.toItemIndex} من ${pageData.totalCount}'
                        : 'إجمالي النتائج: ${pageData.totalCount}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (isLoading) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ),
          if (showSizePicker) ...[
            _buildCompactSizeDropdown(),
            if (hasMultiplePages) const SizedBox(width: 8),
          ],
          if (hasMultiplePages)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _navBtn(
                  tooltip: 'السابقة',
                  icon: LucideIcons.chevronRight,
                  size: 30,
                  enabled: !isLoading && pageData.hasPrev,
                  onTap: () => onPageChanged(pageData.page - 1),
                ),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryNavy,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${pageData.page}/${pageData.totalPages}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                _navBtn(
                  tooltip: 'التالية',
                  icon: LucideIcons.chevronLeft,
                  size: 30,
                  enabled: !isLoading && pageData.hasNext,
                  onTap: () => onPageChanged(pageData.page + 1),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopBar() {
    final pages = _visiblePages();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Text(
            'عرض ${pageData.fromItemIndex} - ${pageData.toItemIndex} من أصل ${pageData.totalCount}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
          if (isLoading) ...[
            const SizedBox(width: 10),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
          const Spacer(),
          if (onPageSizeChanged != null) ...[
            const Text(
              'لكل صفحة:',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            _buildCompactSizeDropdown(),
            const SizedBox(width: 16),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _navBtn(
                tooltip: 'الصفحة السابقة',
                icon: LucideIcons.chevronRight,
                enabled: !isLoading && pageData.hasPrev,
                onTap: () => onPageChanged(pageData.page - 1),
              ),
              const SizedBox(width: 6),
              ...pages.map((p) {
                final active = p == pageData.page;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: (isLoading || active)
                        ? null
                        : () => onPageChanged(p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      constraints: const BoxConstraints(minWidth: 34),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primaryNavy
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: active
                              ? AppColors.primaryNavy
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Text(
                        '$p',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: active ? Colors.white : AppColors.primaryNavy,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 6),
              _navBtn(
                tooltip: 'الصفحة التالية',
                icon: LucideIcons.chevronLeft,
                enabled: !isLoading && pageData.hasNext,
                onTap: () => onPageChanged(pageData.page + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSizeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: pageSizeOptions.contains(pageData.pageSize)
              ? pageData.pageSize
              : pageSizeOptions.first,
          isDense: true,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryNavy,
          ),
          items: pageSizeOptions
              .map((s) => DropdownMenuItem<int>(value: s, child: Text('$s')))
              .toList(),
          onChanged: isLoading
              ? null
              : (val) {
                  if (val != null) {
                    onPageSizeChanged?.call(val);
                  }
                },
        ),
      ),
    );
  }

  Widget _navBtn({
    required String tooltip,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    double size = 34,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onTap : null,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Icon(
            icon,
            size: size * 0.48,
            color: enabled ? AppColors.primaryNavy : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}
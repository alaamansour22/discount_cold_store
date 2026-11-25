import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// تعريف عمود واحد داخل جدول الكمبيوتر الاحترافي
class AppProTableColumn<T> {
  final String label;
  final int flex;
  final double? fixedWidth;
  final AlignmentGeometry alignment;
  final Widget Function(BuildContext context, T item, int index) cellBuilder;

  const AppProTableColumn({
    required this.label,
    required this.cellBuilder,
    this.flex = 1,
    this.fixedWidth,
    this.alignment = AlignmentDirectional.centerStart,
  });
}

/// جدول بيانات احترافي متجاوب للكمبيوتر:
/// - يملأ 100% من عرض البطاقة بدون قصّ للأعمدة
/// - ارتفاع صفوف ديناميكي (لا يقصّ البالتات الميكس أبداً)
/// - تظليل متبادل للصفوف + Hover + شريط تمرير سلس عند الشاشات الأضيق
class AppProDataTable<T> extends StatefulWidget {
  final List<AppProTableColumn<T>> columns;
  final List<T> items;
  final double minTableWidth;
  final bool expandHeight;
  final bool darkHeader;
  final void Function(T item)? onRowTap;
  final String? footerLabel;

  const AppProDataTable({
    super.key,
    required this.columns,
    required this.items,
    this.minTableWidth = 920,
    this.expandHeight = true,
    this.darkHeader = false,
    this.onRowTap,
    this.footerLabel,
  });

  @override
  State<AppProDataTable<T>> createState() => _AppProDataTableState<T>();
}

class _AppProDataTableState<T> extends State<AppProDataTable<T>> {
  final ScrollController _hController = ScrollController();
  final ScrollController _vController = ScrollController();

  @override
  void dispose() {
    _hController.dispose();
    _vController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final headerBg = widget.darkHeader
        ? AppColors.primaryNavy
        : const Color(0xFFF3F6FB);
    final headerFg = widget.darkHeader ? Colors.white : AppColors.primaryNavy;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableW = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : widget.minTableWidth;
            final tableWidth = availableW > widget.minTableWidth
                ? availableW
                : widget.minTableWidth;
            final needsHorizontalScroll = tableWidth > availableW + 1;

            final tableColumn = SizedBox(
              width: tableWidth,
              child: Column(
                mainAxisSize: widget.expandHeight
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                children: [
                  // رأس الجدول
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: headerBg,
                      border: Border(
                        bottom: BorderSide(
                          color: widget.darkHeader
                              ? Colors.white12
                              : AppColors.borderLight,
                        ),
                      ),
                    ),
                    child: Row(
                      children: widget.columns.map((col) {
                        final cell = Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Align(
                            alignment: col.alignment,
                            child: Text(
                              col.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: headerFg,
                              ),
                            ),
                          ),
                        );
                        return col.fixedWidth != null
                            ? SizedBox(width: col.fixedWidth, child: cell)
                            : Expanded(flex: col.flex, child: cell);
                      }).toList(),
                    ),
                  ),

                  // جسم الجدول
                  if (widget.expandHeight)
                    Expanded(
                      child: Scrollbar(
                        controller: _vController,
                        thumbVisibility: true,
                        child: ListView.separated(
                          controller: _vController,
                          itemCount: widget.items.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            color: Color(0xFFEEF2F6),
                          ),
                          itemBuilder: (ctx, index) => _ProTableRow<T>(
                            columns: widget.columns,
                            item: widget.items[index],
                            index: index,
                            onTap: widget.onRowTap,
                          ),
                        ),
                      ),
                    )
                  else
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(widget.items.length, (index) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ProTableRow<T>(
                              columns: widget.columns,
                              item: widget.items[index],
                              index: index,
                              onTap: widget.onRowTap,
                            ),
                            if (index < widget.items.length - 1)
                              const Divider(
                                height: 1,
                                color: Color(0xFFEEF2F6),
                              ),
                          ],
                        );
                      }),
                    ),

                  // شريط أسفل الجدول
                  if (widget.footerLabel != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        border: Border(
                          top: BorderSide(color: AppColors.borderLight),
                        ),
                      ),
                      child: Text(
                        widget.footerLabel!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            );

            if (!needsHorizontalScroll) return tableColumn;

            return Scrollbar(
              controller: _hController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _hController,
                scrollDirection: Axis.horizontal,
                child: tableColumn,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProTableRow<T> extends StatefulWidget {
  final List<AppProTableColumn<T>> columns;
  final T item;
  final int index;
  final void Function(T item)? onTap;

  const _ProTableRow({
    required this.columns,
    required this.item,
    required this.index,
    this.onTap,
  });

  @override
  State<_ProTableRow<T>> createState() => _ProTableRowState<T>();
}

class _ProTableRowState<T> extends State<_ProTableRow<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final baseBg = widget.index.isOdd ? const Color(0xFFFAFBFD) : Colors.white;
    final bgColor = _hovered ? const Color(0xFFEFF6FF) : baseBg;

    final rowContent = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: widget.columns.map((col) {
          final cell = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Align(
              alignment: col.alignment,
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                ),
                child: col.cellBuilder(context, widget.item, widget.index),
              ),
            ),
          );
          return col.fixedWidth != null
              ? SizedBox(width: col.fixedWidth, child: cell)
              : Expanded(flex: col.flex, child: cell);
        }).toList(),
      ),
    );

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.onTap != null
          ? InkWell(
              onTap: () => widget.onTap!(widget.item),
              child: rowContent,
            )
          : rowContent,
    );
  }
}
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// أوضاع عرض الشيمر المتجاوب (يدعم جميع الأسماء القياسية في المشروع)
enum ShimmerLayoutMode { rackGrid, tableList, dashboardCards }

/// شيمر متجاوب يقرأ أبعاد الشاشة تلقائياً عبر LayoutBuilder فقط (بدون MediaQuery لمنع إعادة الرسم مع الكيبورد)
class ResponsiveColdStorageShimmer extends StatelessWidget {
  final ShimmerLayoutMode mode;
  final int? itemCountOverride;

  const ResponsiveColdStorageShimmer({
    super.key,
    this.mode = ShimmerLayoutMode.rackGrid,
    this.itemCountOverride,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          if (mode == ShimmerLayoutMode.tableList) {
            final rowsCount = itemCountOverride ?? 7;
            return Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: rowsCount,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, __) => Container(
                  height: 78,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            );
          }

          // rackGrid or dashboardCards: يحسب عدد الأعمدة تلقائياً حسب عرض الشاشة
          final int crossAxisCount = width >= 1150
              ? 4
              : width >= 750
              ? 3
              : width >= 500
              ? 2
              : 1;

          final int count =
              itemCountOverride ??
              (mode == ShimmerLayoutMode.dashboardCards ? 6 : 12);

          final double cardHeight = mode == ShimmerLayoutMode.dashboardCards
              ? 132.0
              : 182.0;

          return Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: cardHeight,
              ),
              itemCount: count,
              itemBuilder: (_, __) => Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

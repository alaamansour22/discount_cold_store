import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_pagination_bar.dart';
import '../../../../core/widgets/responsive_shimmer.dart';
import '../../../receiving/domain/entities/receiving_entities.dart';
import '../../domain/entities/dispatch_entities.dart';
import '../cubit/dispatch_cubit.dart';
import '../cubit/dispatch_state.dart';
import 'dispatch_history_view.dart';

const _kPageBg = Color(0xFFF3F6FB);
const _kBorder = Color(0xFFE3E8EF);
const _kMuted = Color(0xFF64748B);

String _fmtQty(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

/// الشاشة الرئيسية للصرف: إنشاء مستند صرف جديد أو عرض السجل عبر DispatchHistoryView
class DispatchPage extends StatefulWidget {
  final bool historyOnly;

  const DispatchPage({super.key, this.historyOnly = false});

  @override
  State<DispatchPage> createState() => _DispatchPageState();
}

class _DispatchPageState extends State<DispatchPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Map<String, ReceivingPalletItemEntity> _selectedItems = {};
  final Map<String, int> _palletTotalItemsCount = {};
  final Map<String, TextEditingController> _qtyControllers = {};
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    if (!widget.historyOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<DispatchCubit>().ensureAvailablePalletsLoaded();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      final cubit = context.read<DispatchCubit>();
      cubit.updatePalletsFilter(
        cubit.state.palletsFilter.copyWith(search: value.trim()),
      );
    });
  }

  void _clearFilters(DispatchCubit cubit) {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    cubit.clearPalletsFilters();
  }

  void _clearSelections() {
    setState(() {
      _selectedItems.clear();
      _palletTotalItemsCount.clear();
    });
  }

  TextEditingController _controllerFor(ReceivingPalletItemEntity item) {
    return _qtyControllers.putIfAbsent(
      item.palletItemId,
      () => TextEditingController(text: _fmtQty(item.quantity)),
    );
  }

  void _toggleItem(
    DispatchAvailablePalletEntity pallet,
    ReceivingPalletItemEntity item,
    bool selected,
  ) {
    setState(() {
      _palletTotalItemsCount[pallet.palletId] = pallet.itemsCount;
      if (selected) {
        _selectedItems[item.palletItemId] = item;
        _controllerFor(item);
      } else {
        _selectedItems.remove(item.palletItemId);
      }
    });
  }

  void _toggleWholePallet(DispatchAvailablePalletEntity pallet) {
    final allSelected = pallet.items.every(
      (i) => _selectedItems.containsKey(i.palletItemId),
    );
    setState(() {
      _palletTotalItemsCount[pallet.palletId] = pallet.itemsCount;
      for (final item in pallet.items) {
        if (allSelected) {
          _selectedItems.remove(item.palletItemId);
        } else {
          _selectedItems[item.palletItemId] = item;
          final ctrl = _controllerFor(item);
          ctrl.text = _fmtQty(item.quantity);
        }
      }
    });
  }

  Future<void> _submit() async {
    if (_selectedItems.isEmpty) {
      return;
    }

    final byPallet = <String, List<ReceivingPalletItemEntity>>{};
    for (final item in _selectedItems.values) {
      byPallet.putIfAbsent(item.palletId, () => []).add(item);
    }

    final lines = <DispatchDraftLine>[];
    for (final entry in byPallet.entries) {
      final palletId = entry.key;
      final chosenItems = entry.value;
      final totalItemsOnPallet = _palletTotalItemsCount[palletId] ?? 0;

      final parsedQty = <String, double>{};
      var allFullQty = true;

      for (final item in chosenItems) {
        final rawText = _qtyControllers[item.palletItemId]?.text.trim() ?? '';
        final qty = double.tryParse(rawText);
        if (qty == null || qty <= 0 || qty > item.quantity) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  'راجع كمية الصرف للصنف (${item.itemName}) — المتاح: ${_fmtQty(item.quantity)}',
                ),
                backgroundColor: AppColors.dangerRed,
                behavior: SnackBarBehavior.floating,
              ),
            );
          return;
        }
        parsedQty[item.palletItemId] = qty;
        if (qty < item.quantity) {
          allFullQty = false;
        }
      }

      final palletFullySelected =
          totalItemsOnPallet > 0 &&
          chosenItems.length == totalItemsOnPallet &&
          allFullQty;

      for (final item in chosenItems) {
        final qty = parsedQty[item.palletItemId]!;
        lines.add(
          DispatchDraftLine(
            item: item,
            quantity: qty,
            method: palletFullySelected ? 'full_pallet' : 'custom_quantity',
            palletFullySelected: palletFullySelected,
          ),
        );
      }
    }

    FocusScope.of(context).unfocus();
    await context.read<DispatchCubit>().create(lines);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _kPageBg,
      child: BlocConsumer<DispatchCubit, DispatchState>(
        listenWhen: (prev, curr) =>
            prev.failure != curr.failure || prev.success != curr.success,
        listener: (context, state) {
          final isOffstage =
              context.findAncestorWidgetOfExactType<Offstage>()?.offstage ??
              false;
          if (isOffstage) {
            return;
          }

          if (state.failure != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.failure!.message),
                  backgroundColor: AppColors.dangerRed,
                  behavior: SnackBarBehavior.floating,
                ),
              );
          } else if (state.success != null) {
            if (!widget.historyOnly && _selectedItems.isNotEmpty) {
              _clearSelections();
            }
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.success!),
                  backgroundColor: AppColors.successGreen,
                  behavior: SnackBarBehavior.floating,
                ),
              );
          }
        },
        buildWhen: (prev, curr) {
          if (widget.historyOnly) {
            return false;
          }
          return prev.isPalletsLoading != curr.isPalletsLoading ||
              prev.palletsInitialized != curr.palletsInitialized ||
              prev.palletsData != curr.palletsData ||
              prev.palletsFilter != curr.palletsFilter ||
              prev.submitting != curr.submitting;
        },
        builder: (context, state) {
          if (widget.historyOnly) {
            return const DispatchHistoryView();
          }
          return _buildCreateView(context, state);
        },
      ),
    );
  }

  Widget _buildCreateView(BuildContext context, DispatchState state) {
    if (!state.palletsInitialized && state.isPalletsLoading) {
      return const ResponsiveColdStorageShimmer(
        mode: ShimmerLayoutMode.tableList,
        itemCountOverride: 5,
      );
    }

    final cubit = context.read<DispatchCubit>();
    final pageData = state.palletsData.page;
    final summary = state.palletsData.summary;
    final filter = state.palletsFilter;
    final pallets = pageData.items;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 900;
          final pad = desktop ? 24.0 : 12.0;

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => cubit.loadAvailablePallets(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          pad,
                          desktop ? 18 : 10,
                          pad,
                          10,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (desktop) ...[
                                _buildDesktopHeader(cubit, summary),
                                const SizedBox(height: 12),
                              ],
                              _buildFiltersCard(cubit, filter, desktop),
                              if (!desktop) ...[
                                const SizedBox(height: 9),
                                _buildMobileStatsRow(summary),
                              ],
                              if (state.isPalletsLoading) ...[
                                const SizedBox(height: 8),
                                const LinearProgressIndicator(minHeight: 2.5),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (pallets.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(cubit, filter),
                        )
                      else ...[
                        if (desktop)
                          _buildDesktopPalletPairs(pallets, pad)
                        else
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(pad, 0, pad, 10),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => Padding(
                                  padding: EdgeInsets.only(
                                    bottom: i == pallets.length - 1 ? 0 : 10,
                                  ),
                                  child: _buildPalletCard(pallets[i]),
                                ),
                                childCount: pallets.length,
                              ),
                            ),
                          ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(pad, 0, pad, 16),
                          sliver: SliverToBoxAdapter(
                            child: AppPaginationBar(
                              pageData: pageData,
                              isLoading: state.isPalletsLoading,
                              pageSizeOptions: const [15, 20, 50],
                              onPageChanged: cubit.goToPalletsPage,
                              onPageSizeChanged: cubit.changePalletsPageSize,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _buildSubmitBar(state, desktop),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDesktopHeader(
    DispatchCubit cubit,
    DispatchAvailablePalletsSummaryEntity summary,
  ) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إنشاء مستند صرف',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryNavy,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'حدد البالتات أو الأصناف والكميات المطلوب صرفها لمنفذ البيع',
                style: TextStyle(fontSize: 12, color: _kMuted),
              ),
            ],
          ),
        ),
        _statPill('${summary.totalPallets} بالتة متاحة', AppColors.primaryNavy),
        const SizedBox(width: 8),
        _statPill(summary.totalsByUnitSummary, AppColors.successGreen),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'تحديث',
          onPressed: () => cubit.loadAvailablePallets(),
          icon: const Icon(LucideIcons.refreshCw, size: 16),
        ),
      ],
    );
  }

  Widget _buildMobileStatsRow(DispatchAvailablePalletsSummaryEntity summary) {
    return Row(
      children: [
        _statPill('${summary.totalPallets} بالتة متاحة', AppColors.primaryNavy),
        const SizedBox(width: 6),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _statPill(
              summary.totalsByUnitSummary,
              AppColors.successGreen,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statPill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    ),
  );

  Widget _buildFiltersCard(
    DispatchCubit cubit,
    DispatchAvailablePalletsFilter filter,
    bool desktop,
  ) {
    final searchField = ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchCtrl,
      builder: (_, val, _) => TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'بحث بالصنف، رقم البالتة أو موقع الراك',
          hintStyle: const TextStyle(fontSize: 12.5),
          prefixIcon: const Icon(LucideIcons.search, size: 17),
          suffixIcon: val.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearchChanged('');
                  },
                  icon: const Icon(LucideIcons.x, size: 16),
                ),
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: _kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: _kBorder),
          ),
        ),
      ),
    );

    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) => ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      selectedColor: AppColors.primaryNavy,
      backgroundColor: const Color(0xFFF8FAFC),
      side: BorderSide(color: selected ? AppColors.primaryNavy : _kBorder),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        color: selected ? Colors.white : AppColors.primaryNavy,
      ),
      onSelected: (_) => onTap(),
    );

    final chips = Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        chip(
          label: 'كل المناطق',
          selected: filter.zone == null,
          onTap: () =>
              cubit.updatePalletsFilter(filter.copyWith(clearZone: true)),
        ),
        chip(
          label: 'C2',
          selected: filter.zone == 'C2',
          onTap: () => cubit.updatePalletsFilter(filter.copyWith(zone: 'C2')),
        ),
        chip(
          label: 'C3',
          selected: filter.zone == 'C3',
          onTap: () => cubit.updatePalletsFilter(filter.copyWith(zone: 'C3')),
        ),
        chip(
          label: 'موحدة',
          selected: filter.palletKind == 'single',
          onTap: () => cubit.updatePalletsFilter(
            filter.palletKind == 'single'
                ? filter.copyWith(clearPalletKind: true)
                : filter.copyWith(palletKind: 'single'),
          ),
        ),
        chip(
          label: 'ميكس',
          selected: filter.palletKind == 'mixed',
          onTap: () => cubit.updatePalletsFilter(
            filter.palletKind == 'mixed'
                ? filter.copyWith(clearPalletKind: true)
                : filter.copyWith(palletKind: 'mixed'),
          ),
        ),
        if (filter.hasActiveFilters)
          TextButton.icon(
            onPressed: () => _clearFilters(cubit),
            icon: const Icon(LucideIcons.rotateCcw, size: 13),
            label: const Text('مسح', style: TextStyle(fontSize: 11.5)),
          ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(desktop ? 14 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: desktop
          ? Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 12),
                chips,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: 8),
                chips,
              ],
            ),
    );
  }

  /// عرض شبكي مرن للكمبيوتر (بطاقتان في الصف بارتفاع طبيعي بدون قص أو مساحات فارغة)
  Widget _buildDesktopPalletPairs(
    List<DispatchAvailablePalletEntity> pallets,
    double pad,
  ) {
    final rowCount = (pallets.length / 2).ceil();
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(pad, 0, pad, 12),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((_, rowIndex) {
          final firstIdx = rowIndex * 2;
          final secondIdx = firstIdx + 1;
          return Padding(
            padding: EdgeInsets.only(
              bottom: rowIndex == rowCount - 1 ? 0 : 12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildPalletCard(pallets[firstIdx])),
                const SizedBox(width: 14),
                Expanded(
                  child: secondIdx < pallets.length
                      ? _buildPalletCard(pallets[secondIdx])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
        }, childCount: rowCount),
      ),
    );
  }

  Widget _buildPalletCard(DispatchAvailablePalletEntity pallet) {
    final anySelected = pallet.items.any(
      (i) => _selectedItems.containsKey(i.palletItemId),
    );
    final allSelected =
        pallet.items.isNotEmpty &&
        pallet.items.every((i) => _selectedItems.containsKey(i.palletItemId));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: anySelected ? AppColors.zoneC2Blue : _kBorder,
          width: anySelected ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. رأس البطاقة: كود البالتة + الموقع + نوع البالتة + زر تحديد الكل
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color:
                        (pallet.isMixed
                                ? AppColors.mixedPurple
                                : AppColors.zoneC2Blue)
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    pallet.isMixed ? LucideIcons.boxes : LucideIcons.package,
                    size: 18,
                    color: pallet.isMixed
                        ? AppColors.mixedPurple
                        : AppColors.zoneC2Blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              pallet.palletReference,
                              textDirection: TextDirection.ltr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (pallet.hasCondemnationAlert)
                            const Icon(
                              LucideIcons.triangleAlert,
                              size: 14,
                              color: AppColors.dangerRed,
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              pallet.slotCode,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                          ),
                          Text(
                            pallet.isMixed
                                ? 'ميكس (${pallet.itemsCount} أصناف)'
                                : 'موحدة',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: pallet.isMixed
                                  ? AppColors.mixedPurple
                                  : _kMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _toggleWholePallet(pallet),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: allSelected
                        ? AppColors.dangerRed
                        : AppColors.zoneC2Blue,
                  ),
                  child: Text(
                    allSelected ? 'إلغاء' : 'تحديد الكل',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 18, color: Color(0xFFEDF1F5)),

            // 2. قائمة الأصناف داخل البالتة (ارتفاع طبيعي تماماً)
            ...List.generate(pallet.items.length, (index) {
              final item = pallet.items[index];
              final checked = _selectedItems.containsKey(item.palletItemId);
              final controller = _controllerFor(item);
              final expired = item.daysUntilExpiry <= 0;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == pallet.items.length - 1 ? 0 : 8,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: checked
                        ? AppColors.zoneC2Blue.withValues(alpha: 0.05)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: checked
                          ? AppColors.zoneC2Blue.withValues(alpha: 0.35)
                          : const Color(0xFFEAEEF4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: checked,
                        activeColor: AppColors.zoneC2Blue,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (val) =>
                            _toggleItem(pallet, item, val == true),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.itemName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              expired
                                  ? 'منتهي الصلاحية • المتاح ${_fmtQty(item.quantity)} ${item.unit.arLabel}'
                                  : 'متبقي ${item.daysUntilExpiry} يوم • المتاح ${_fmtQty(item.quantity)} ${item.unit.arLabel}',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: expired ? AppColors.dangerRed : _kMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (checked)
                        SizedBox(
                          width: 78,
                          child: TextField(
                            controller: controller,
                            textAlign: TextAlign.center,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_fmtQty(item.quantity)} ${item.unit.arLabel}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: AppColors.successGreen,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),

            const Divider(height: 18, color: Color(0xFFEDF1F5)),

            // 3. إجمالي البالتة (محسوب من PostgreSQL)
            Row(
              children: [
                const Text(
                  'إجمالي البالتة:',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: _kMuted,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    pallet.totalSummary,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.successGreen,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitBar(DispatchState state, bool desktop) {
    final selectedCount = _selectedItems.length;
    final selectedPalletsCount = _selectedItems.values
        .map((e) => e.palletId)
        .toSet()
        .length;

    return Container(
      padding: EdgeInsets.fromLTRB(
        desktop ? 24 : 12,
        10,
        desktop ? 24 : 12,
        12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _kBorder)),
        boxShadow: [
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selectedCount == 0
                      ? 'لم يتم تحديد أصناف'
                      : '$selectedCount بند ($selectedPalletsCount بالتة)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'جهة الصرف: منفذ بيع العاملين',
                  style: TextStyle(fontSize: 11, color: _kMuted),
                ),
              ],
            ),
          ),
          if (selectedCount > 0) ...[
            TextButton(
              onPressed: state.submitting ? null : _clearSelections,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.dangerRed,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text(
                'إلغاء',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 6),
          ],
          FilledButton.icon(
            onPressed: (state.submitting || selectedCount == 0)
                ? null
                : _submit,
            icon: state.submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(LucideIcons.truck, size: 16),
            label: Text(
              desktop ? 'إنشاء مستند الصرف' : 'اعتماد الصرف',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.zoneC2Blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: desktop ? 18 : 14,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    DispatchCubit cubit,
    DispatchAvailablePalletsFilter filter,
  ) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF0F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.packageOpen,
              size: 26,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'لا توجد بالتات متاحة للصرف',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'تأكد من كلمة البحث أو الفلاتر المحددة أو اسحب للأسفل للتحديث.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _kMuted),
          ),
          if (filter.hasActiveFilters) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _clearFilters(cubit),
              icon: const Icon(LucideIcons.rotateCcw, size: 15),
              label: const Text('مسح الفلاتر'),
            ),
          ],
        ],
      ),
    ),
  );
}
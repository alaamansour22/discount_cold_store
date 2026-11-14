import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/responsive_shimmer.dart';
import '../../domain/entities/dispatch_entities.dart';
import '../cubit/dispatch_cubit.dart';
import '../cubit/dispatch_state.dart';

class DispatchPage extends StatefulWidget {
  final bool historyOnly;

  const DispatchPage({super.key, this.historyOnly = false});

  @override
  State<DispatchPage> createState() => _DispatchPageState();
}

class _DispatchPageState extends State<DispatchPage> {
  final Map<String, TextEditingController> quantities = {};
  final Set<String> selected = {};
  final search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DispatchCubit>().load();
    });
  }

  @override
  void dispose() {
    search.dispose();
    for (final controller in quantities.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: const Color(0xfff3f6fb),
      body: BlocConsumer<DispatchCubit, DispatchState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: const Color(0xffb42318),
              ),
            );
          }
          if (state.success != null) {
            selected.clear();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.success!),
                backgroundColor: const Color(0xff16834a),
              ),
            );
          }
        },
        builder: (context, state) =>
            widget.historyOnly ? _historyScreen(state) : _createScreen(state),
      ),
    ),
  );

  Widget _pageFrame({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: desktop ? 1440 : 760),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    desktop ? 28 : 16,
                    desktop ? 24 : 16,
                    desktop ? 28 : 16,
                    12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xffe8efff),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: const Color(0xff2454d7)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Color(0xff14213d),
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: Color(0xff718096),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (desktop)
                        Text(
                          widget.historyOnly
                              ? 'DISPATCH HISTORY'
                              : 'NEW DISPATCH',
                          style: const TextStyle(
                            color: Color(0xff8a97ab),
                            fontSize: 10,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _createScreen(DispatchState state) => _pageFrame(
    title: 'إنشاء مستند صرف',
    subtitle: 'حدد الأصناف والكميات المطلوبة ثم أنشئ مستند الصرف',
    icon: Icons.outbox_rounded,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: desktop ? 28 : 16),
              child: _searchField('ابحث باسم الصنف أو رقم البالتة أو الموقع'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: search,
                builder: (context, searchVal, _) {
                  final query = searchVal.text.trim().toLowerCase();
                  final filtered = state.availableItems.where((item) {
                    return query.isEmpty ||
                        item.itemName.toLowerCase().contains(query) ||
                        item.palletReference.toLowerCase().contains(query) ||
                        item.slotCode.toLowerCase().contains(query);
                  }).toList();

                  if (state.loading && state.availableItems.isEmpty) {
                    return const ResponsiveColdStorageShimmer(
                      mode: ShimmerLayoutMode.tableList,
                      itemCountOverride: 6,
                    );
                  }
                  if (filtered.isEmpty) {
                    return _emptyState(
                      'لا توجد أصناف متاحة للصرف',
                      'جرّب تغيير عبارة البحث أو راجع المخزون المتاح',
                      Icons.inventory_2_outlined,
                    );
                  }
                  return desktop
                      ? _desktopItems(filtered)
                      : _mobileItems(filtered);
                },
              ),
            ),
            _submitBar(state, desktop),
          ],
        );
      },
    ),
  );

  Widget _searchField(String hint) => TextField(
    controller: search,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search_rounded),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xffe0e7f0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xffe0e7f0)),
      ),
    ),
  );

  String _palletLabel(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return '—';
    if (clean.length > 18) return '${clean.substring(0, 14)}…';
    return clean;
  }

  Map<String, List<dynamic>> _groupByPallet(List<dynamic> items) {
    final groups = <String, List<dynamic>>{};
    for (final item in items) {
      groups.putIfAbsent(item.palletId as String, () => <dynamic>[]).add(item);
    }
    return groups;
  }

  Widget _mobileItems(List<dynamic> items) =>
      _palletCards(items, desktop: false);

  Widget _desktopItems(List<dynamic> items) =>
      _palletCards(items, desktop: true);

  Widget _palletCards(List<dynamic> items, {required bool desktop}) {
    final groups = _groupByPallet(items);
    final cards = groups.entries.toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = desktop ? (constraints.maxWidth >= 1200 ? 3 : 2) : 1;
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
            desktop ? 28 : 16,
            4,
            desktop ? 28 : 16,
            18,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 12,
            mainAxisExtent: _palletCardHeight(cards, desktop),
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final entry = cards[index];
            final palletItems = entry.value;
            final first = palletItems.first;
            final palletSelected = palletItems.any(
              (item) => selected.contains(item.palletItemId),
            );
            final totals = <String, double>{};
            for (final item in palletItems) {
              final unit = item.unit.arLabel as String;
              totals[unit] = (totals[unit] ?? 0) + (item.quantity as double);
            }
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: palletSelected
                      ? const Color(0xff315bdc)
                      : const Color(0xffe3eaf3),
                  width: palletSelected ? 1.5 : 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x080d2345),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xffedf2ff),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            color: Color(0xff315bdc),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _palletLabel(first.palletReference as String),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xff17243b),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${first.slotCode}  •  ${palletItems.length} ${palletItems.length == 1 ? 'صنف' : 'أصناف'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xff8290a4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            final allSelected = palletItems.every(
                              (item) => selected.contains(item.palletItemId),
                            );
                            for (final item in palletItems) {
                              if (allSelected) {
                                selected.remove(item.palletItemId);
                              } else {
                                selected.add(item.palletItemId);
                                quantities.putIfAbsent(
                                  item.palletItemId,
                                  () => TextEditingController(
                                    text: item.quantity.toString(),
                                  ),
                                );
                              }
                            }
                          }),
                          child: Text(
                            palletItems.every(
                                  (item) =>
                                      selected.contains(item.palletItemId),
                                )
                                ? 'إلغاء تحديد'
                                : 'تحديد الكل',
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Expanded(
                      child: ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: palletItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 9),
                        itemBuilder: (context, itemIndex) {
                          final item = palletItems[itemIndex];
                          final id = item.palletItemId as String;
                          final checked = selected.contains(id);
                          final controller = quantities.putIfAbsent(
                            id,
                            () => TextEditingController(
                              text: item.quantity.toString(),
                            ),
                          );
                          return Row(
                            children: [
                              Checkbox(
                                value: checked,
                                activeColor: const Color(0xff315bdc),
                                visualDensity: VisualDensity.compact,
                                onChanged: (value) => setState(() {
                                  if (value == true) {
                                    selected.add(id);
                                  } else {
                                    selected.remove(id);
                                  }
                                }),
                              ),
                              Expanded(
                                child: Text(
                                  item.itemName as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xff25344d),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (checked)
                                SizedBox(
                                  width: 76,
                                  height: 36,
                                  child: TextField(
                                    controller: controller,
                                    textAlign: TextAlign.center,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 8,
                                      ),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  '${item.quantity} ${item.unit.arLabel}',
                                  style: const TextStyle(
                                    color: Color(0xff16834a),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    const Divider(height: 18),
                    Row(
                      children: [
                        const Text(
                          'إجمالي البالتة',
                          style: TextStyle(
                            color: Color(0xff75849a),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Text(
                            totals.entries
                                .map((e) => '${e.value} ${e.key}')
                                .join('  •  '),
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              color: Color(0xff16834a),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  double _palletCardHeight(
    List<MapEntry<String, List<dynamic>>> cards,
    bool desktop,
  ) {
    // Give mixed pallets room for all their item rows while keeping a consistent card grid.
    final maxItems = cards.fold<int>(
      1,
      (max, entry) => entry.value.length > max ? entry.value.length : max,
    );
    return (desktop ? 210.0 : 225.0) +
        (maxItems - 1).clamp(0, 5).toDouble() * 42.0;
  }

  Widget _metaPill(IconData icon, String text) => Flexible(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xfff3f6fb),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xff75849a)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xff65748a)),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _submitBar(DispatchState state, bool desktop) => Container(
    padding: EdgeInsets.fromLTRB(desktop ? 28 : 16, 10, desktop ? 28 : 16, 14),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Color(0xffe6ebf2))),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${selected.length} بند محدد',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xff17243b),
                ),
              ),
              const Text(
                'راجع الكميات قبل اعتماد المستند',
                style: TextStyle(fontSize: 11, color: Color(0xff8491a4)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xff173d9b),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            onPressed: state.submitting || selected.isEmpty
                ? null
                : () => _submit(state),
            icon: state.submitting
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.outbox_rounded, size: 18),
            label: const Text('إنشاء مستند الصرف'),
          ),
        ),
      ],
    ),
  );

  Widget _historyScreen(DispatchState state) => _pageFrame(
    title: 'سجل مستندات الصرف',
    subtitle: 'راجع المستندات السابقة وتفاصيل الأصناف وحالات العكس',
    icon: Icons.receipt_long_rounded,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        return RefreshIndicator(
          onRefresh: () => context.read<DispatchCubit>().load(),
          child: state.loading && state.documents.isEmpty
              ? const ResponsiveColdStorageShimmer(
                  mode: ShimmerLayoutMode.tableList,
                  itemCountOverride: 5,
                )
              : state.documents.isEmpty
              ? _emptyState(
                  'لا توجد مستندات صرف حتى الآن',
                  'ستظهر هنا المستندات التي يتم إنشاؤها',
                  Icons.receipt_long_outlined,
                )
              : desktop
              ? _desktopHistory(state)
              : _mobileHistory(state),
        );
      },
    ),
  );

  Widget _mobileHistory(DispatchState state) => ListView.separated(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
    itemCount: state.documents.length,
    separatorBuilder: (_, __) => const SizedBox(height: 10),
    itemBuilder: (context, index) =>
        _documentCard(state, state.documents[index]),
  );

  Widget _desktopHistory(DispatchState state) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(28, 4, 28, 20),
    children: [
      Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xffe4eaf2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'رقم المستند',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'التاريخ',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'الحالة',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'التفاصيل',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ...state.documents.map((doc) => _desktopDocumentRow(state, doc)),
          ],
        ),
      ),
    ],
  );

  Widget _desktopDocumentRow(DispatchState state, dynamic doc) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      title: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              doc.palletReferences.isEmpty
                  ? doc.number
                  : doc.palletReferences.map((e) => _palletLabel(e)).join('، '),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(flex: 2, child: Text(_date(doc.createdAt))),
          Expanded(flex: 2, child: _statusChip(doc.status == 'reversed')),
          const Expanded(flex: 1, child: Text('عرض البنود')),
        ],
      ),
      onExpansionChanged: (open) {
        if (open) context.read<DispatchCubit>().loadDetails(doc.id);
      },
      children: _documentDetails(state, doc),
    ),
  );

  Widget _documentCard(DispatchState state, dynamic doc) {
    final reversed = doc.status == 'reversed';
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: const Color(0x140d2345),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: const BorderSide(color: Color(0xffe6ebf2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: reversed
                  ? const Color(0xfffff1df)
                  : const Color(0xffe9f7ef),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              reversed ? Icons.undo_rounded : Icons.receipt_long_rounded,
              color: reversed
                  ? const Color(0xffb76b12)
                  : const Color(0xff16834a),
            ),
          ),
          title: Text(
            doc.palletReferences.isEmpty
                ? doc.number
                : doc.palletReferences.map((e) => _palletLabel(e)).join('، '),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Color(0xff17243b),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Text(
                  _date(doc.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xff8793a5),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    doc.number,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xffa0aaba),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _statusChip(reversed),
              ],
            ),
          ),
          onExpansionChanged: (open) {
            if (open) context.read<DispatchCubit>().loadDetails(doc.id);
          },
          children: _documentDetails(state, doc),
        ),
      ),
    );
  }

  List<Widget> _documentDetails(DispatchState state, dynamic doc) {
    final reversed = doc.status == 'reversed';
    final lines = state.details[doc.id] ?? [];
    return [
      if (lines.isEmpty)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'جارٍ تحميل تفاصيل المستند أو لا توجد بنود',
            style: TextStyle(color: Color(0xff8793a5)),
          ),
        )
      else
        ...lines.map(
          (line) => Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xffedf0f5))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.itemName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_palletLabel(line.palletReference)} • ${line.slotCode}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xff8793a5),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${line.quantity} ${line.unit}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xff173d9b),
                  ),
                ),
              ],
            ),
          ),
        ),
      if (!reversed)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _askReverse(doc.id),
            icon: const Icon(Icons.undo_rounded, color: Color(0xffb42318)),
            label: const Text(
              'عكس المستند',
              style: TextStyle(
                color: Color(0xffb42318),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
    ];
  }

  Widget _statusChip(bool reversed) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: reversed ? const Color(0xfffff1df) : const Color(0xffe9f7ef),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      reversed ? 'معكوس' : 'مكتمل',
      style: TextStyle(
        color: reversed ? const Color(0xffa45d0a) : const Color(0xff16834a),
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Widget _emptyState(String title, String subtitle, IconData icon) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: const Color(0xffa8b4c5)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xff344054),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xff8793a5), fontSize: 12),
          ),
        ],
      ),
    ),
  );

  Future<void> _submit(DispatchState state) async {
    final lines = <DispatchDraftLine>[];
    for (final item in state.availableItems.where(
      (e) => selected.contains(e.palletItemId),
    )) {
      final quantity = double.tryParse(
        quantities[item.palletItemId]?.text.trim() ?? '',
      );
      if (quantity == null || quantity <= 0 || quantity > item.quantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('راجع كمية الصرف للصنف ${item.itemName}')),
        );
        return;
      }
      lines.add(
        DispatchDraftLine(
          item: item,
          quantity: quantity,
          method: quantity == item.quantity ? 'full_pallet' : 'custom_quantity',
        ),
      );
    }
    await context.read<DispatchCubit>().create(lines);
  }

  Future<void> _askReverse(String id) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('عكس مستند الصرف'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'سبب العكس',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, controller.text.trim().isNotEmpty),
              child: const Text('تأكيد العكس'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      await context.read<DispatchCubit>().reverse(id, controller.text);
    }
    controller.dispose();
  }
}
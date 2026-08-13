import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/api_milling_repository.dart';
import '../../data/milling_repository.dart';
import '../../models/milling_order.dart';
import '../widgets/milling_widgets.dart';
import 'milling_create_order_screen.dart';
import 'rice_weighing_screen.dart';

class MillingPreparationScreen extends StatefulWidget {
  const MillingPreparationScreen({this.repository, super.key});

  final MillingRepository? repository;

  @override
  State<MillingPreparationScreen> createState() =>
      _MillingPreparationScreenState();
}

class _MillingPreparationScreenState extends State<MillingPreparationScreen> {
  late final MillingRepository _repository;
  final TextEditingController _searchController = TextEditingController();
  Future<MillingOrderPage>? _pageFuture;
  Timer? _debounce;
  String _search = '';
  int? _statusId;
  int? _warehouseId;
  Map<int, String> _knownStatuses = const {};
  Map<int, String> _knownWarehouses = const {};

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiMillingRepository();
    _pageFuture = _loadPage();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _pageFuture = _loadPage();
    });
  }

  Future<MillingOrderPage> _loadPage() {
    return _repository
        .getMillingOrderPage(
          search: _search,
          statusId: _statusId,
          warehouseId: _warehouseId,
        )
        .timeout(
          const Duration(seconds: 35),
          onTimeout: () => throw const MillingApiException(
            'API tải lệnh xay phản hồi quá lâu. Vui lòng thử lại.',
          ),
        );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _search = value.trim();
      _reload();
    });
  }

  Future<void> _openDetail(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _MillingOrderDetailScreen(
          orderId: id,
          repository: _repository,
        ),
      ),
    );
  }

  Future<void> _openCreate() async {
    final createdId = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => MillingCreateOrderScreen(repository: _repository),
      ),
    );
    if (!mounted || createdId == null) return;
    _reload();
    await _openDetail(createdId);
    if (mounted) _reload();
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_MillingFilterSelection>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _MillingFilterSheet(
        statuses: _knownStatuses,
        warehouses: _knownWarehouses,
        selectedStatusId: _statusId,
        selectedWarehouseId: _warehouseId,
      ),
    );
    if (result == null || !mounted) return;
    _statusId = result.statusId;
    _warehouseId = result.warehouseId;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: millingBackground,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            AppGradientHeader(
              title: 'Lệnh xay xát',
              subtitle: 'Danh sách, lô đầu vào và kết quả xay',
              leading: IconButton(
                tooltip: 'Quay lại',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Tạo lệnh xay',
                    constraints: const BoxConstraints.tightFor(width: 40, height: 40),
                    padding: EdgeInsets.zero,
                    onPressed: _openCreate,
                    icon: const Icon(Icons.add_task_rounded, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: 'Làm mới',
                    constraints: const BoxConstraints.tightFor(width: 40, height: 40),
                    padding: EdgeInsets.zero,
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
            ),
            Expanded(
            child: FutureBuilder<MillingOrderPage>(
              future: _pageFuture,
              builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _MillingLoadingState();
          }
          if (snapshot.hasError) {
            return HErrorState(
              message: 'Không thể tải lệnh xay: ${snapshot.error}',
              onRetry: _reload,
            );
          }
          final page = snapshot.data ??
              const MillingOrderPage(
                orders: [],
                recordsTotal: 0,
                recordsFiltered: 0,
              );
          _rememberFilterOptions(page.orders);
                return RefreshIndicator(
                  onRefresh: () async {
                    _reload();
                    await _pageFuture;
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    children: [
                      _SearchAndFilters(
                        controller: _searchController,
                        statusLabel: _statusLabel(_statusId),
                        warehouseLabel: _warehouseLabel(_warehouseId),
                        selectedStatusId: _statusId,
                        selectedWarehouseId: _warehouseId,
                        onSearchChanged: _onSearchChanged,
                        onOpenFilters: _openFilters,
                        onClear: () {
                          _searchController.clear();
                          _search = '';
                          _statusId = null;
                          _warehouseId = null;
                          _reload();
                        },
                      ),
                      const SizedBox(height: 10),
                      _ResultCountText(page: page),
                      const SizedBox(height: 12),
                      if (page.orders.isEmpty)
                        HEmptyState(
                          title: _search.isEmpty &&
                                  _statusId == null &&
                                  _warehouseId == null
                              ? 'Chưa có lệnh xay'
                              : 'Không tìm thấy lệnh phù hợp',
                          description:
                              'Thử đổi từ khóa hoặc bỏ bộ lọc rồi làm mới.',
                        )
                      else
                        for (final order in page.orders) ...[
                          _MillingOrderCard(
                            order: order,
                            onTap: () => _openDetail(order.id),
                          ),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
                );
              },
            ),
            ),
          ],
        ),
      ),
    );
  }

  void _rememberFilterOptions(List<MillingOrder> orders) {
    final statuses = Map<int, String>.of(_knownStatuses);
    final warehouses = Map<int, String>.of(_knownWarehouses);
    for (final order in orders) {
      if (order.statusId > 0) {
        statuses[order.statusId] = order.statusName?.trim().isNotEmpty == true
            ? order.statusName!
            : 'Trạng thái ${order.statusId}';
      }
      if (order.warehouseId > 0) {
        warehouses[order.warehouseId] =
            order.warehouseName?.trim().isNotEmpty == true
                ? order.warehouseName!
                : 'Kho ${order.warehouseId}';
      }
    }
    _knownStatuses = statuses;
    _knownWarehouses = warehouses;
  }

  String _statusLabel(int? id) {
    if (id == null) return 'Tất cả trạng thái';
    return _knownStatuses[id] ?? 'Trạng thái $id';
  }

  String _warehouseLabel(int? id) {
    if (id == null) return 'Tất cả kho';
    return _knownWarehouses[id] ?? 'Kho $id';
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.controller,
    required this.statusLabel,
    required this.warehouseLabel,
    required this.selectedStatusId,
    required this.selectedWarehouseId,
    required this.onSearchChanged,
    required this.onOpenFilters,
    required this.onClear,
  });

  final TextEditingController controller;
  final String statusLabel;
  final String warehouseLabel;
  final int? selectedStatusId;
  final int? selectedWarehouseId;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onOpenFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasFilter = selectedStatusId != null || selectedWarehouseId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            labelText: 'Tìm mã lệnh, kho hoặc máy xay',
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Xóa tìm kiếm',
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(110, 50),
                ),
                onPressed: onOpenFilters,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Bộ lọc'),
              ),
              const SizedBox(width: 8),
              _FilterChipPill(
                label: statusLabel,
                active: selectedStatusId != null,
              ),
              const SizedBox(width: 8),
              _FilterChipPill(
                label: warehouseLabel,
                active: selectedWarehouseId != null,
              ),
              if (hasFilter) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Xóa lọc'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MillingLoadingState extends StatelessWidget {
  const _MillingLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: const [
        SkeletonPulse(height: 52, borderRadius: 14),
        SizedBox(height: 12),
        Row(
          children: [
            SkeletonPulse(width: 96, height: 40, borderRadius: 20),
            SizedBox(width: 8),
            SkeletonPulse(width: 124, height: 40, borderRadius: 20),
          ],
        ),
        SizedBox(height: 16),
        SkeletonPulse(width: 170, height: 14, borderRadius: 6),
        SizedBox(height: 12),
        SkeletonPulse(height: 190, borderRadius: 18),
        SizedBox(height: 10),
        SkeletonPulse(height: 190, borderRadius: 18),
        SizedBox(height: 10),
        SkeletonPulse(height: 190, borderRadius: 18),
      ],
    );
  }
}

class _MillingFilterSelection {
  const _MillingFilterSelection({
    required this.statusId,
    required this.warehouseId,
  });

  final int? statusId;
  final int? warehouseId;
}

class _MillingFilterSheet extends StatefulWidget {
  const _MillingFilterSheet({
    required this.statuses,
    required this.warehouses,
    required this.selectedStatusId,
    required this.selectedWarehouseId,
  });

  final Map<int, String> statuses;
  final Map<int, String> warehouses;
  final int? selectedStatusId;
  final int? selectedWarehouseId;

  @override
  State<_MillingFilterSheet> createState() => _MillingFilterSheetState();
}

class _MillingFilterSheetState extends State<_MillingFilterSheet> {
  int? _statusId;
  int? _warehouseId;

  @override
  void initState() {
    super.initState();
    _statusId = widget.selectedStatusId;
    _warehouseId = widget.selectedWarehouseId;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bộ lọc lệnh xay',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            _FilterGroup(
              title: 'Trạng thái',
              selectedId: _statusId,
              allLabel: 'Tất cả trạng thái',
              options: widget.statuses,
              onChanged: (value) => setState(() => _statusId = value),
            ),
            const SizedBox(height: 14),
            _FilterGroup(
              title: 'Kho',
              selectedId: _warehouseId,
              allLabel: 'Tất cả kho',
              options: widget.warehouses,
              onChanged: (value) => setState(() => _warehouseId = value),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _statusId = null;
                        _warehouseId = null;
                      });
                    },
                    child: const Text('Xóa lọc'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      _MillingFilterSelection(
                        statusId: _statusId,
                        warehouseId: _warehouseId,
                      ),
                    ),
                    child: const Text('Áp dụng'),
                  ),
                ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({
    required this.title,
    required this.selectedId,
    required this.allLabel,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final int? selectedId;
  final String allLabel;
  final Map<int, String> options;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(allLabel),
              selected: selectedId == null,
              onSelected: (_) => onChanged(null),
            ),
            for (final entry in options.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: selectedId == entry.key,
                onSelected: (_) => onChanged(entry.key),
              ),
          ],
        ),
      ],
    );
  }
}

class _FilterChipPill extends StatelessWidget {
  const _FilterChipPill({
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFDCFCE7) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: active ? const Color(0xFF166534) : const Color(0xFF475569),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ResultCountText extends StatelessWidget {
  const _ResultCountText({required this.page});

  final MillingOrderPage page;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Đang hiển thị ${page.orders.length} / ${page.recordsFiltered}'
      '${page.recordsFiltered == page.recordsTotal ? '' : ' · Tổng ${page.recordsTotal}'}',
      style: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _MillingOrderCard extends StatelessWidget {
  const _MillingOrderCard({
    required this.order,
    required this.onTap,
  });

  final MillingOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = MillingStatusView.fromOrder(order);
    final inputLabel = order.inputs.isEmpty
        ? order.inputLotCode
        : order.inputs
            .map((item) => item.lotCode ?? '#${item.paddyLotId}')
            .join(', ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    order.millingCode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              order.salesOrderId == null
                  ? 'Nguồn: lệnh xay độc lập · ${order.riceVarietyName ?? 'Chưa rõ giống'}'
                  : 'Nguồn: đơn bán #${order.salesOrderId} · ${order.riceVarietyName ?? 'Chưa rõ giống'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _InfoPill(
              icon: Icons.warehouse_outlined,
              text: order.warehouseName ?? order.warehouseZone,
            ),
            const SizedBox(height: 6),
            _InfoPill(
              icon: Icons.grass_outlined,
              text: 'Lô đầu vào: $inputLabel',
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _CompactStat(
                      label: 'Gạo dự kiến',
                      value: _kg(order.totalRiceOutputKg),
                      compact: true,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 34,
                    color: const Color(0xFFE2E8F0),
                  ),
                  Expanded(
                    child: _CompactStat(
                      label: 'Yield',
                      value: _percent(order.yieldRateUsed),
                      compact: true,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 34,
                    color: const Color(0xFFE2E8F0),
                  ),
                  Expanded(
                    child: _CompactStat(
                      label: 'Gạo thực tế',
                      value: _kg(order.outputsRiceKg),
                      compact: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ngày tạo: ${_date(order.createdDate)}',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: onTap,
                  icon: Icon(
                    status.canContinueWeighing
                        ? Icons.play_arrow_rounded
                        : Icons.visibility_outlined,
                  ),
                  label: Text(status.actionLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MillingOrderDetailScreen extends StatefulWidget {
  const _MillingOrderDetailScreen({
    required this.orderId,
    required this.repository,
  });

  final int orderId;
  final MillingRepository repository;

  @override
  State<_MillingOrderDetailScreen> createState() =>
      _MillingOrderDetailScreenState();
}

class _MillingOrderDetailScreenState extends State<_MillingOrderDetailScreen> {
  late Future<MillingOrder> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getMillingOrderDetail(widget.orderId);
  }

  void _reload() {
    setState(() {
      _future = widget.repository.getMillingOrderDetail(widget.orderId);
    });
  }

  void _continueWeighing(MillingOrder order) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RiceWeighingScreen(
          order: order,
          repository: widget.repository,
          includeBroken: order.brokenProductVariantId > 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: millingBackground,
      appBar: MillingAppBar(
        title: 'Chi tiết lệnh xay',
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<MillingOrder>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const FormSkeleton();
          }
          if (snapshot.hasError) {
            return HErrorState(
              message: 'Không thể tải chi tiết lệnh xay: ${snapshot.error}',
              onRetry: _reload,
            );
          }
          final order = snapshot.data;
          if (order == null) {
            return HErrorState(
              message: 'Backend không trả về dữ liệu lệnh xay.',
              onRetry: _reload,
            );
          }
          final status = MillingStatusView.fromOrder(order);
          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    _reload();
                    await _future;
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    children: [
                      _DetailHeader(order: order, status: status),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricTile(
                              label: 'Lúa đầu vào',
                              value: _kg(order.inputWeightKg),
                              icon: Icons.grass_outlined,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MetricTile(
                              label: 'Gạo dự kiến',
                              value: _kg(order.totalRiceOutputKg),
                              icon: Icons.rice_bowl_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricTile(
                              label: 'Gạo thực tế',
                              value: _kg(order.outputsRiceKg),
                              icon: Icons.inventory_2_outlined,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MetricTile(
                              label: 'Phụ phẩm/loss',
                              value:
                                  '${_kg(order.byproductKg ?? order.outputsByproductKg)} / ${_kg(order.lossKg ?? 0)}',
                              icon: Icons.scatter_plot_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _InputsSection(inputs: order.inputs),
                      const SizedBox(height: 12),
                      _OutputsSection(outputs: order.outputs),
                      const SizedBox(height: 12),
                      _MetadataCard(order: order),
                    ],
                  ),
                ),
              ),
              MillingPrimaryButton(
                label: status.canContinueWeighing
                    ? 'Tiếp tục cân/kết quả'
                    : 'Chỉ xem - ${status.label}',
                onPressed: status.canContinueWeighing
                    ? () => _continueWeighing(order)
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.order,
    required this.status,
  });

  final MillingOrder order;
  final MillingStatusView status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  order.millingCode,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 10),
          _InfoPill(
            icon: Icons.warehouse_outlined,
            text: order.warehouseName ?? order.warehouseZone,
          ),
          const SizedBox(height: 8),
          _InfoPill(
            icon: Icons.receipt_long_outlined,
            text: order.salesOrderId == null
                ? 'Lệnh xay độc lập'
                : 'Từ đơn bán #${order.salesOrderId}',
          ),
          const SizedBox(height: 8),
          _InfoPill(
            icon: Icons.grass_outlined,
            text: 'Lô đầu vào: ${order.inputLotCode} · ${_kg(order.inputWeightKg)}',
          ),
          const SizedBox(height: 8),
          _InfoPill(
            icon: Icons.grain_outlined,
            text:
                '${order.riceVarietyName ?? 'Chưa rõ giống'} · Yield ${_percent(order.yieldRateUsed)}',
          ),
          if (order.reason?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              order.reason?.trim() ?? '',
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetadataCard extends StatelessWidget {
  const _MetadataCard({required this.order});

  final MillingOrder order;

  @override
  Widget build(BuildContext context) {
    return _ExpandableSectionCard(
      title: 'Chi phí & thời gian',
      icon: Icons.schedule_rounded,
      children: [
        _KeyValue('Máy xay/cân', order.machineRef ?? order.scaleCode),
        _KeyValue('Bắt đầu', _dateTime(order.startedAt)),
        _KeyValue('Hoàn tất', _dateTime(order.completedAt)),
        _KeyValue('Chi phí xay', _money(order.millingCost)),
        _KeyValue('Chi phí phát sinh', _money(order.incidentalCost)),
        _KeyValue('Tổng chi phí', _money(order.totalCost)),
        _KeyValue('Ngày tạo', _dateTime(order.createdDate)),
        _KeyValue('Cập nhật', _dateTime(order.lastModifiedDate)),
      ],
    );
  }
}

class _InputsSection extends StatelessWidget {
  const _InputsSection({required this.inputs});

  final List<MillingOrderInput> inputs;

  @override
  Widget build(BuildContext context) {
    return _ExpandableSectionCard(
      title: 'Lô đầu vào',
      icon: Icons.grass_outlined,
      emptyText: 'Backend chưa trả lô đầu vào.',
      children: [
        for (final input in inputs)
          _MiniCard(
            title: input.lotCode ?? 'Lô #${input.paddyLotId}',
            subtitle:
                'Vị trí: ${input.locationCode ?? input.locationId ?? 'N/A'}',
            trailing: _kg(input.consumedWeightKg),
            details: [
              if (input.reservedWeightKg != null)
                'Đã giữ: ${_kg(input.reservedWeightKg!)}',
              if (input.bags.isNotEmpty) '${input.bags.length} bao đã chọn',
              if (input.note?.trim().isNotEmpty == true) input.note!,
            ],
          ),
      ],
    );
  }
}

class _OutputsSection extends StatelessWidget {
  const _OutputsSection({required this.outputs});

  final List<MillingOrderOutput> outputs;

  @override
  Widget build(BuildContext context) {
    return _ExpandableSectionCard(
      title: 'Đầu ra',
      icon: Icons.inventory_2_outlined,
      emptyText: 'Chưa có dữ liệu đầu ra từ Backend.',
      children: [
        for (final output in outputs)
          _MiniCard(
            title: output.sku ?? 'Sản phẩm #${output.productVariantId}',
            subtitle:
                '${output.outputType ?? 'OUTPUT'} · ${output.isByproduct ? 'Phụ phẩm' : 'Gạo chính'}',
            trailing: _kg(output.outputWeightKg),
            details: [
              if (output.bagCount != null) '${output.bagCount} bao',
              if (output.locationId != null) 'Vị trí #${output.locationId}',
              if (output.outputLotId != null)
                'Lô đầu ra #${output.outputLotId}',
              if (output.unitCost != null)
                'Đơn giá vốn: ${_money(output.unitCost)}',
            ],
          ),
      ],
    );
  }
}

class _ExpandableSectionCard extends StatelessWidget {
  const _ExpandableSectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.emptyText,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: title != 'Chi phí & thời gian',
          leading: Icon(icon, color: millingGreen),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          children: [
            if (children.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  emptyText ?? 'Chưa có dữ liệu.',
                  style:
                      const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
              )
            else
              ...children,
          ],
        ),
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.details = const [],
  });

  final String title;
  final String subtitle;
  final String trailing;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                trailing,
                style: const TextStyle(
                  color: millingGreen,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          for (final detail in details) ...[
            const SizedBox(height: 6),
            Text(
              detail,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: millingGreen, size: 18),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  const _CompactStat({
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
    if (compact) {
      return Padding(padding: const EdgeInsets.all(2), child: content);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: content,
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final MillingStatusView status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, color: status.foreground, size: 14),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: status.foreground,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MillingStatusView {
  const MillingStatusView({
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.actionLabel,
    required this.canContinueWeighing,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData icon;
  final String actionLabel;
  final bool canContinueWeighing;

  factory MillingStatusView.fromOrder(MillingOrder order) {
    final raw = (order.statusCode ?? order.statusName ?? '').toUpperCase();
    final label = order.statusName?.trim().isNotEmpty == true
        ? order.statusName!
        : raw.isEmpty
            ? 'Không rõ'
            : raw;
    if (raw.contains('DRAFT') || raw.contains('NHÁP')) {
      return MillingStatusView(
        label: label,
        background: const Color(0xFFFEF3C7),
        foreground: const Color(0xFF92400E),
        icon: Icons.edit_document,
        actionLabel: 'Xem',
        canContinueWeighing: false,
      );
    }
    if (raw.contains('RESERVED') || raw.contains('GIỮ')) {
      return MillingStatusView(
        label: label,
        background: const Color(0xFFDBEAFE),
        foreground: const Color(0xFF1D4ED8),
        icon: Icons.lock_clock_rounded,
        actionLabel: 'Xem',
        canContinueWeighing: false,
      );
    }
    if (raw.contains('MILLING') ||
        raw.contains('ĐANG XAY') ||
        raw.contains('STARTED') ||
        raw.contains('IN_PROGRESS') ||
        raw.contains('WAITING_RESULT') ||
        raw.contains('CHỜ NHẬP')) {
      return MillingStatusView(
        label: label,
        background: const Color(0xFFF3E8FF),
        foreground: const Color(0xFF7E22CE),
        icon: Icons.precision_manufacturing_outlined,
        actionLabel: 'Tiếp tục',
        canContinueWeighing: true,
      );
    }
    if (raw.contains('COMPLETED') ||
        raw.contains('HOÀN') ||
        raw.contains('FINISHED')) {
      return MillingStatusView(
        label: label,
        background: const Color(0xFFDCFCE7),
        foreground: const Color(0xFF166534),
        icon: Icons.check_circle_outline,
        actionLabel: 'Xem',
        canContinueWeighing: false,
      );
    }
    if (raw.contains('CANCEL') || raw.contains('HỦY')) {
      return MillingStatusView(
        label: label,
        background: const Color(0xFFFEE2E2),
        foreground: const Color(0xFFB91C1C),
        icon: Icons.cancel_outlined,
        actionLabel: 'Xem',
        canContinueWeighing: false,
      );
    }
    return MillingStatusView(
      label: label,
      background: const Color(0xFFF1F5F9),
      foreground: const Color(0xFF475569),
      icon: Icons.help_outline_rounded,
      actionLabel: 'Xem',
      canContinueWeighing: false,
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFE2E8F0)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

String _kg(double value) => '${value.toStringAsFixed(value >= 100 ? 0 : 1)} kg';

String _percent(double value) {
  final normalized = value <= 1 ? value * 100 : value;
  return '${normalized.toStringAsFixed(1)}%';
}

String _date(DateTime? value) {
  if (value == null) return 'N/A';
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String _dateTime(DateTime? value) {
  if (value == null) return 'N/A';
  return '${_date(value)} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

String _money(double? value) {
  if (value == null) return 'N/A';
  return '${value.toStringAsFixed(0)} đ';
}

extension on MillingOrder {
  double get outputsRiceKg => outputs
      .where((item) =>
          !item.isByproduct && (item.outputType ?? '').toUpperCase() == 'RICE')
      .fold<double>(0, (sum, item) => sum + item.outputWeightKg);

  double get outputsByproductKg => outputs
      .where((item) =>
          item.isByproduct || (item.outputType ?? '').toUpperCase() != 'RICE')
      .fold<double>(0, (sum, item) => sum + item.outputWeightKg);
}

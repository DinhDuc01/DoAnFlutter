import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/api_milling_repository.dart';
import '../../data/milling_repository.dart';
import '../../models/milling_order.dart';
import '../widgets/milling_widgets.dart';
import 'milling_create_order_screen.dart';
import 'milling_source_selection_screen.dart';
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

  Future<void> _openStatusFilter() async {
    final result = await showModalBottomSheet<_MillingFilterResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _MillingLookupFilterSheet(
        title: 'Chọn trạng thái',
        allLabel: 'Tất cả trạng thái',
        selectedId: _statusId,
        loader: _repository.getMillingStatuses,
      ),
    );
    if (result == null || !mounted) return;
    _statusId = result.id;
    if (result.id != null) {
      _knownStatuses = {..._knownStatuses, result.id!: result.name};
    }
    _reload();
  }

  Future<void> _openWarehouseFilter() async {
    final result = await showModalBottomSheet<_MillingFilterResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _MillingLookupFilterSheet(
        title: 'Chọn kho',
        allLabel: 'Tất cả kho',
        selectedId: _warehouseId,
        loader: _repository.getWarehouses,
      ),
    );
    if (result == null || !mounted) return;
    _warehouseId = result.id;
    if (result.id != null) {
      _knownWarehouses = {..._knownWarehouses, result.id!: result.name};
    }
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
                    constraints:
                        const BoxConstraints.tightFor(width: 40, height: 40),
                    padding: EdgeInsets.zero,
                    onPressed: _openCreate,
                    icon:
                        const Icon(Icons.add_task_rounded, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: 'Làm mới',
                    constraints:
                        const BoxConstraints.tightFor(width: 40, height: 40),
                    padding: EdgeInsets.zero,
                    onPressed: _reload,
                    icon:
                        const Icon(Icons.refresh_rounded, color: Colors.white),
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
                          onOpenStatus: _openStatusFilter,
                          onOpenWarehouse: _openWarehouseFilter,
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
    required this.onOpenStatus,
    required this.onOpenWarehouse,
    required this.onClear,
  });

  final TextEditingController controller;
  final String statusLabel;
  final String warehouseLabel;
  final int? selectedStatusId;
  final int? selectedWarehouseId;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onOpenStatus;
  final VoidCallback onOpenWarehouse;
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
                  minimumSize: const Size(0, 44),
                ),
                onPressed: onOpenStatus,
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text(statusLabel),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                ),
                onPressed: onOpenWarehouse,
                icon: const Icon(Icons.warehouse_outlined, size: 18),
                label: Text(warehouseLabel),
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

class _MillingFilterResult {
  const _MillingFilterResult(this.id, this.name);

  final int? id;
  final String name;
}

class _MillingLookupFilterSheet extends StatefulWidget {
  const _MillingLookupFilterSheet({
    required this.title,
    required this.allLabel,
    required this.selectedId,
    required this.loader,
  });

  final String title;
  final String allLabel;
  final int? selectedId;
  final Future<List<MillingFilterOption>> Function() loader;

  @override
  State<_MillingLookupFilterSheet> createState() =>
      _MillingLookupFilterSheetState();
}

class _MillingLookupFilterSheetState extends State<_MillingLookupFilterSheet> {
  late Future<List<MillingFilterOption>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  void _retry() => setState(() => _future = widget.loader());

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .62,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<MillingFilterOption>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return HErrorState(
                        message: 'Không tải được dữ liệu: ${snapshot.error}',
                        onRetry: _retry,
                      );
                    }
                    final options = snapshot.data ?? const [];
                    return ListView(
                      children: [
                        _MillingLookupTile(
                          label: widget.allLabel,
                          selected: widget.selectedId == null,
                          onTap: () => Navigator.of(context).pop(
                            _MillingFilterResult(null, widget.allLabel),
                          ),
                        ),
                        for (final option in options)
                          _MillingLookupTile(
                            label: option.name,
                            subtitle: option.code,
                            selected: widget.selectedId == option.id,
                            onTap: () => Navigator.of(context).pop(
                              _MillingFilterResult(option.id, option.name),
                            ),
                          ),
                        if (options.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(child: Text('Chưa có dữ liệu')),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MillingLookupTile extends StatelessWidget {
  const _MillingLookupTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: subtitle?.trim().isNotEmpty == true ? Text(subtitle!) : null,
      onTap: onTap,
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
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
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
  bool _actionBusy = false;

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

  Future<void> _reserve(MillingOrder order) async {
    if (_actionBusy) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MillingSourceSelectionScreen(
          order: order,
          repository: widget.repository,
        ),
      ),
    );
    if (changed == true && mounted) _reload();
  }

  Future<void> _start(MillingOrder order) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      await widget.repository.startOrder(order.id);
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã bắt đầu lệnh xay.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không bắt đầu được lệnh xay: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
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
              if (status.canReserve)
                MillingPrimaryButton(
                  label: 'Chọn bao và giữ lúa',
                  isLoading: _actionBusy,
                  onPressed: () => _reserve(order),
                )
              else if (status.canStart)
                MillingPrimaryButton(
                  label: 'Bắt đầu xay',
                  isLoading: _actionBusy,
                  onPressed: () => _start(order),
                )
              else
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
            text:
                'Lô đầu vào: ${order.inputLotCode} · ${_kg(order.inputWeightKg)}',
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
    required this.canReserve,
    required this.canStart,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData icon;
  final String actionLabel;
  final bool canContinueWeighing;
  final bool canReserve;
  final bool canStart;

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
        canReserve: true,
        canStart: false,
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
        canReserve: false,
        canStart: true,
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
        canReserve: false,
        canStart: false,
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
        canReserve: false,
        canStart: false,
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
        canReserve: false,
        canStart: false,
      );
    }
    return MillingStatusView(
      label: label,
      background: const Color(0xFFF1F5F9),
      foreground: const Color(0xFF475569),
      icon: Icons.help_outline_rounded,
      actionLabel: 'Xem',
      canContinueWeighing: false,
      canReserve: false,
      canStart: false,
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

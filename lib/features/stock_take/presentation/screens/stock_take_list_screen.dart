import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/realtime/realtime_reload_mixin.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_pagination.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/permission_guard.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../kho/data/stock_take_repository.dart' as legacy_repo;
import '../../../kho/models/inventory_stock.dart' show WarehouseOption;
import '../../data/api_stock_take_repository.dart';
import '../../data/stock_take_repository.dart';
import '../../models/stock_take.dart';
import '../widgets/stock_take_card.dart';

/// Màn hình danh sách kiểm kê kho.
///
/// Thống nhất giao diện và luồng chuẩn với toàn bộ hệ thống:
/// AppGradientHeader, search bar có debounce, ChoiceChips lọc trạng thái/kho,
/// ListSkeleton, HEmptyState, HErrorState, và AppPagination.
class StockTakeListScreen extends StatefulWidget {
  const StockTakeListScreen({
    this.repository,
    this.legacyRepository,
    this.embedded = false,
    super.key,
  });

  final StockTakeRepository? repository;
  final legacy_repo.StockTakeRepository? legacyRepository;
  final bool embedded;

  @override
  State<StockTakeListScreen> createState() => _StockTakeListScreenState();
}

class _StockTakeListScreenState extends State<StockTakeListScreen>
    with RealtimeReloadMixin {
  static const int _pageSize = 20;

  @override
  Set<String> get realtimeEntities => const {
        'StockTake',
        'StockTakeItem',
        'StockTakeStatus',
        'Inventory',
        'PaddyLotBag',
      };

  @override
  void onRealtimeChanged() => _load(showLoading: false);

  static const List<({int? id, String label})> _statusTabs = [
    (id: null, label: 'Tất cả'),
    (id: StockTakeStatusIds.draft, label: 'Bản nháp'),
    (id: StockTakeStatusIds.submitted, label: 'Chờ duyệt'),
    (id: StockTakeStatusIds.approved, label: 'Đã duyệt'),
    (id: StockTakeStatusIds.rejected, label: 'Từ chối'),
  ];

  late final StockTakeRepository _repo;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  int _requestId = 0;
  List<StockTakeSummary> _items = const [];
  int _total = 0;
  int _page = 1;
  String _keyword = '';
  int? _selectedWarehouse;
  int? _selectedStatusId;
  bool _loading = true;
  Object? _error;

  List<WarehouseOption> _apiWarehouses = const [];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ??
        (widget.legacyRepository as StockTakeRepository? ??
            ApiStockTakeRepository());
    _loadFilters();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int get _totalPages =>
      _total <= 0 ? 1 : ((_total + _pageSize - 1) ~/ _pageSize);

  Future<void> _loadFilters() async {
    try {
      final warehouses = await _repo.getWarehouses();
      if (mounted) {
        setState(() {
          _apiWarehouses = warehouses;
        });
      }
    } catch (_) {}
  }

  Future<void> _load({bool showLoading = true}) async {
    final requestId = ++_requestId;
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final start = (_page - 1) * _pageSize;
      final page = await _repo.getStockTakesPaged(
        start: start,
        length: _pageSize,
        search: _keyword.trim().isEmpty ? null : _keyword.trim(),
        warehouseId: _selectedWarehouse,
        statusId: _selectedStatusId,
      );
      if (!mounted || requestId != _requestId) return;

      if (page.items.isEmpty && page.recordsFiltered > 0 && _page > 1) {
        final lastPage = (page.recordsFiltered + _pageSize - 1) ~/ _pageSize;
        final target = lastPage < _page ? lastPage : _page - 1;
        _page = target < 1 ? 1 : target;
        await _load(showLoading: false);
        return;
      }

      setState(() {
        _items = page.items;
        _total = page.recordsFiltered;
        _loading = false;
        _error = null;
      });
      _scrollToTop();
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = error;
        _items = const [];
        _total = 0;
      });
      if (error is ApiException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${error.message} (code ${error.statusCode})'),
          ),
        );
      }
    }
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(0);
  }

  void _applyFilter(void Function() change) {
    setState(() {
      change();
      _page = 1;
    });
    _load();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final keyword = value.trim();
      if (keyword == _keyword) return;
      _applyFilter(() => _keyword = keyword);
    });
  }

  void _goToPage(int page) {
    if (page == _page) return;
    setState(() => _page = page);
    _load();
  }

  Future<void> _openDetail(int id) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.stockTakeDetail,
      arguments: id,
    );
    _load(showLoading: false);
  }

  Future<void> _createStockTake() async {
    final created = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useRootNavigator: false,
      builder: (_) => _CreateStockTakeSheet(repository: _repo),
    );
    if (created != null && created > 0 && mounted) {
      await _openDetail(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        AppGradientHeader(
          title: 'Kiểm kê kho',
          subtitle: 'Kiểm đếm theo bao, quét QR và đối soát chênh lệch',
          leading: widget.embedded
              ? null
              : IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  color: Colors.white,
                  icon: const Icon(Icons.arrow_back),
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const Key('createStockTakeTopButton'),
                icon: const Icon(Icons.add),
                color: Colors.white,
                tooltip: 'Tạo phiếu mới',
                onPressed: _createStockTake,
              ),
              IconButton(
                onPressed: _loading ? null : () => _load(),
                color: Colors.white,
                tooltip: 'Tải lại',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(child: _body()),
      ],
    );

    final createButton = PermissionBuilder(
      menuCode: 'STOCKTAKE',
      action: 'CREATE',
      child: FloatingActionButton.extended(
        onPressed: _createStockTake,
        icon: const Icon(Icons.add),
        label: const Text('Phiếu mới'),
      ),
    );

    if (widget.embedded) {
      return ColoredBox(
        color: AppColors.backgroundFor(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
            Positioned(right: 16, bottom: 16, child: createButton),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(child: content),
      floatingActionButton: createButton,
    );
  }

  Widget _body() {
    if (_loading && _items.isEmpty && _error == null) {
      return const ListSkeleton();
    }
    if (_error != null && _items.isEmpty) return _errorState(_error!);

    return RefreshIndicator(
      onRefresh: () => _load(showLoading: false),
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Tìm mã phiếu hoặc ghi chú',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 10),
          _statusChips(),
          if (_apiWarehouses.isNotEmpty) ...[
            const SizedBox(height: 8),
            _warehouseChips(),
          ],
          const SizedBox(height: 14),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_items.isEmpty)
            const HEmptyState(
              title: 'Chưa có phiếu kiểm kê',
              description:
                  'Thử đổi từ khóa hoặc bộ lọc kho/trạng thái, hoặc bấm "Phiếu mới".',
              icon: Icons.inventory_2_outlined,
            )
          else
            for (final item in _items)
              StockTakeCard(
                summary: item,
                onTap: () => _openDetail(item.id),
              ),
          if (_total > 0) ...[
            const SizedBox(height: 6),
            AppPagination(
              page: _page,
              totalPages: _totalPages,
              total: _total,
              enabled: !_loading,
              onChanged: _goToPage,
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in _statusTabs) ...[
            ChoiceChip(
              label: Text(tab.label),
              selected: _selectedStatusId == tab.id,
              onSelected: _loading
                  ? null
                  : (_) => _applyFilter(() => _selectedStatusId = tab.id),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _warehouseChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              Icons.warehouse_outlined,
              size: 18,
              color: AppColors.textSecondaryFor(context),
            ),
          ),
          ChoiceChip(
            label: const Text('Tất cả kho'),
            selected: _selectedWarehouse == null,
            onSelected: _loading
                ? null
                : (_) => _applyFilter(() => _selectedWarehouse = null),
          ),
          const SizedBox(width: 8),
          for (final wh in _apiWarehouses) ...[
            ChoiceChip(
              label: Text(wh.name),
              selected: _selectedWarehouse == wh.id,
              onSelected: _loading
                  ? null
                  : (_) => _applyFilter(() => _selectedWarehouse = wh.id),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _errorState(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 401) {
        return HErrorState(
          message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          onRetry: _load,
        );
      }
      if (error.statusCode == 403) {
        return HErrorState(
          message: 'Bạn không có quyền xem danh sách kiểm kê kho.',
          onRetry: _load,
        );
      }
      if (error.isTransient) {
        return HNetworkState(message: error.message, onRetry: _load);
      }
      return HErrorState(message: 'Lỗi: ${error.message}', onRetry: _load);
    }
    return HErrorState(
      message: 'Lỗi: $error',
      onRetry: _load,
    );
  }
}

class _CreateStockTakeSheet extends StatefulWidget {
  const _CreateStockTakeSheet({required this.repository});

  final StockTakeRepository repository;

  @override
  State<_CreateStockTakeSheet> createState() => _CreateStockTakeSheetState();
}

class _CreateStockTakeSheetState extends State<_CreateStockTakeSheet> {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _lotController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();

  List<WarehouseOption> _warehouses = const [];
  List<StockTakeLocationOption> _locations = const [];
  List<StockTakeOption> _apiLots = const [];
  List<StockTakeOption> _apiSkus = const [];

  int? _warehouseId;
  StockTakeScope _scope = StockTakeScope.warehouse;
  String? _zoneName;
  int? _locationId;
  int? _selectedLotId;
  String? _selectedLotCode;
  int? _selectedSkuId;
  String? _selectedSkuCode;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _lotController.dispose();
    _skuController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final warehouses = await widget.repository.getWarehouses();
      final lots = await widget.repository.getLots();
      final skus = await widget.repository.getSkus();
      if (!mounted) return;
      setState(() {
        _warehouses = warehouses;
        _apiLots = lots;
        _apiSkus = skus;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _loadLocations(int warehouseId) async {
    final locations = await widget.repository.getLocations(warehouseId);
    if (!mounted) return;
    setState(() {
      _locations = locations;
      _locationId = null;
      _zoneName = null;
    });
  }

  List<String> get _zones =>
      {for (final l in _locations) if (l.zoneName.isNotEmpty) l.zoneName}
          .toList()
        ..sort();

  Future<void> _submit() async {
    if (_warehouseId == null) {
      setState(() => _error = 'Vui lòng chọn kho.');
      return;
    }
    if (_scope == StockTakeScope.zone && (_zoneName ?? '').isEmpty) {
      setState(() => _error = 'Vui lòng chọn khu cần kiểm.');
      return;
    }
    if (_scope == StockTakeScope.column && _locationId == null) {
      setState(() => _error = 'Vui lòng chọn cột cần kiểm.');
      return;
    }
    final effectiveLot = _selectedLotCode ?? _lotController.text.trim();
    if (_scope == StockTakeScope.lot && effectiveLot.isEmpty) {
      setState(() => _error = 'Vui lòng chọn hoặc nhập mã lô cần kiểm.');
      return;
    }
    final effectiveSku = _selectedSkuCode ?? _skuController.text.trim();
    if (_scope == StockTakeScope.sku && effectiveSku.isEmpty) {
      setState(() => _error = 'Vui lòng chọn hoặc nhập mã SKU cần kiểm.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await widget.repository.create(
        warehouseId: _warehouseId!,
        scope: _scope,
        zoneName: _scope == StockTakeScope.zone ? _zoneName : null,
        locationId: _scope == StockTakeScope.column ? _locationId : null,
        paddyLotId: _scope == StockTakeScope.lot ? _selectedLotId : null,
        productVariantId: _scope == StockTakeScope.sku ? _selectedSkuId : null,
        lotCode: _scope == StockTakeScope.lot ? effectiveLot : null,
        skuCode: _scope == StockTakeScope.sku ? effectiveSku : null,
        note: _noteController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BƯỚC 1 - CHỤP SNAPSHOT',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Tạo phiên kiểm kê',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Backend sẽ chụp snapshot tồn kho tại thời điểm tạo phiên.',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: 'Đóng',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      key: const Key('warehouseDropdown'),
                      initialValue: _warehouseId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Kho *',
                        hintText: 'Chọn kho',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      items: [
                        for (final w in _warehouses)
                          DropdownMenuItem(value: w.id, child: Text(w.name)),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() => _warehouseId = value);
                              _loadLocations(value);
                            },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<StockTakeScope>(
                            key: const Key('scopeDropdown'),
                            initialValue: _scope,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Loại phạm vi *',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                            ),
                            items: [
                              for (final scope in StockTakeScope.values)
                                DropdownMenuItem(
                                    value: scope, child: Text(scope.label)),
                            ],
                            onChanged: _saving
                                ? null
                                : (value) => setState(() {
                                      _scope = value ?? StockTakeScope.column;
                                      _zoneName = null;
                                      _locationId = null;
                                      _selectedLotCode = null;
                                      _selectedSkuCode = null;
                                    }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _scope == StockTakeScope.warehouse
                              ? DropdownButtonFormField<String>(
                                  initialValue: null,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Giá trị phạm vi',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 14),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                        value: null, child: Text('Tất cả')),
                                  ],
                                  onChanged: null,
                                )
                              : _scope == StockTakeScope.zone
                                  ? DropdownButtonFormField<String>(
                                      key: const Key('zoneDropdown'),
                                      initialValue: _zoneName,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Giá trị phạm vi *',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 14),
                                      ),
                                      items: [
                                        for (final zone in _zones)
                                          DropdownMenuItem(
                                              value: zone, child: Text(zone)),
                                      ],
                                      onChanged: _saving
                                          ? null
                                          : (value) =>
                                              setState(() => _zoneName = value),
                                    )
                                  : _scope == StockTakeScope.column
                                      ? DropdownButtonFormField<int>(
                                          key: const Key('columnDropdown'),
                                          initialValue: _locationId,
                                          isExpanded: true,
                                          decoration: const InputDecoration(
                                            labelText: 'Giá trị phạm vi *',
                                            border: OutlineInputBorder(),
                                            contentPadding: EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 14),
                                          ),
                                          items: [
                                            for (final location in _locations)
                                              DropdownMenuItem(
                                                value: location.id,
                                                child: Text(location.label,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis),
                                              ),
                                          ],
                                          onChanged: _saving
                                              ? null
                                              : (value) => setState(
                                                  () => _locationId = value),
                                        )
                                      : _scope == StockTakeScope.lot
                                          ? (_apiLots.isNotEmpty
                                              ? DropdownButtonFormField<int>(
                                                  key: const Key('lotDropdown'),
                                                  initialValue: _selectedLotId,
                                                  isExpanded: true,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Giá trị phạm vi *',
                                                    border: OutlineInputBorder(),
                                                    contentPadding: EdgeInsets.symmetric(
                                                        horizontal: 12, vertical: 14),
                                                  ),
                                                  items: [
                                                    for (final lot in _apiLots)
                                                      DropdownMenuItem(
                                                          value: lot.id,
                                                          child: Text(lot.label,
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis)),
                                                  ],
                                                  onChanged: _saving
                                                      ? null
                                                      : (value) => setState(() {
                                                            _selectedLotId = value;
                                                            final found = _apiLots.cast<StockTakeOption?>().firstWhere(
                                                                  (l) => l?.id == value,
                                                                  orElse: () => null,
                                                                );
                                                            _selectedLotCode = found?.code;
                                                          }),
                                                )
                                              : TextFormField(
                                                  key: const Key('lotField'),
                                                  controller: _lotController,
                                                  enabled: !_saving,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Giá trị phạm vi *',
                                                    hintText: 'Nhập mã lô',
                                                    border: OutlineInputBorder(),
                                                    contentPadding: EdgeInsets.symmetric(
                                                        horizontal: 12, vertical: 14),
                                                  ),
                                                ))
                                          : (_apiSkus.isNotEmpty
                                              ? DropdownButtonFormField<int>(
                                                  key: const Key('skuDropdown'),
                                                  initialValue: _selectedSkuId,
                                                  isExpanded: true,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Giá trị phạm vi *',
                                                    border: OutlineInputBorder(),
                                                    contentPadding: EdgeInsets.symmetric(
                                                        horizontal: 12, vertical: 14),
                                                  ),
                                                  items: [
                                                    for (final sku in _apiSkus)
                                                      DropdownMenuItem(
                                                          value: sku.id,
                                                          child: Text(sku.label,
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis)),
                                                  ],
                                                  onChanged: _saving
                                                      ? null
                                                      : (value) => setState(() {
                                                            _selectedSkuId = value;
                                                            final found = _apiSkus.cast<StockTakeOption?>().firstWhere(
                                                                  (s) => s?.id == value,
                                                                  orElse: () => null,
                                                                );
                                                            _selectedSkuCode = found?.code;
                                                          }),
                                                )
                                              : TextFormField(
                                                  key: const Key('skuField'),
                                                  controller: _skuController,
                                                  enabled: !_saving,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Giá trị phạm vi *',
                                                    hintText: 'Nhập mã SKU',
                                                    border: OutlineInputBorder(),
                                                    contentPadding: EdgeInsets.symmetric(
                                                        horizontal: 12, vertical: 14),
                                                  ),
                                                )),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _noteController,
                      enabled: !_saving,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú',
                        hintText: 'Nhập ghi chú phiên kiểm kê nếu có',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      key: const Key('submitButton'),
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(_saving ? 'Đang tạo...' : 'Tạo phiên kiểm kê'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

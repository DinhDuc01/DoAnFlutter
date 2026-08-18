// Stock Take List Screen
import 'package:flutter/material.dart';
import '../../data/api_stock_take_repository.dart';
import '../../data/stock_take_repository.dart';
import '../../models/stock_take.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/api/api_client.dart';
import '../widgets/stock_take_card.dart';
import 'package:stocklite/features/kho/models/inventory_stock.dart' show WarehouseOption;
import 'package:stocklite/features/kho/data/stock_take_repository.dart' as legacy_repo;
import '../../../../core/widgets/permission_guard.dart';

class StockTakeListScreen extends StatefulWidget {
  const StockTakeListScreen({this.repository, this.legacyRepository, super.key});

  final StockTakeRepository? repository;
  final legacy_repo.StockTakeRepository? legacyRepository;

  @override
  State<StockTakeListScreen> createState() => _StockTakeListScreenState();
}

class _StockTakeListScreenState extends State<StockTakeListScreen> {
  late final StockTakeRepository _repo;
  final List<StockTakeSummary> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _start = 0;
  final int _length = 20;
  final String _search = '';
  int? _selectedWarehouse;
  String? _selectedStatus;

  List<WarehouseOption> _apiWarehouses = [];
  List<StockTakeStatusOption> _apiStatuses = [];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? (widget.legacyRepository as StockTakeRepository? ?? ApiStockTakeRepository());
    _loadFilters();
    _loadPage();
  }

  Future<void> _loadFilters() async {
    try {
      final whs = await _repo.getWarehouses();
      final sts = await _repo.getStatuses();
      if (mounted) {
        setState(() {
          _apiWarehouses = whs;
          _apiStatuses = sts;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    if (reset) {
      _start = 0;
      _items.clear();
      _hasMore = true;
    }
    try {
      final page = await _repo.getStockTakesPaged(
        start: _start,
        length: _length,
        search: _search,
        warehouseId: _selectedWarehouse,
        statusCode: _selectedStatus,
      );
      _items.addAll(page.items);
      _hasMore = _items.length < page.recordsTotal;
      _start += _length;
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${e.message} (code ${e.statusCode})')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    await _loadPage(reset: true);
  }

  Widget _buildFilters() {
    final warehouseItems = <DropdownMenuItem<int>>[
      const DropdownMenuItem(value: null, child: Text('Tất cả kho')),
      for (final wh in _apiWarehouses)
        DropdownMenuItem(value: wh.id, child: Text(wh.name)),
    ];
    final statusItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: null, child: Text('Tất cả trạng thái')),
      for (final st in _apiStatuses)
        DropdownMenuItem(value: st.code, child: Text(st.name)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<int>(
              isExpanded: true,
              value: _selectedWarehouse,
              hint: const Text('Kho'),
              items: warehouseItems,
              onChanged: (v) {
                setState(() => _selectedWarehouse = v);
                _refresh();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedStatus,
              hint: const Text('Trạng thái'),
              items: statusItems,
              onChanged: (v) {
                setState(() => _selectedStatus = v);
                _refresh();
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(int id) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.stockTakeDetail,
      arguments: id,
    );
    _refresh();
  }

  Future<void> _createStockTake() async {
    final created = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useRootNavigator: false,
      builder: (sheetContext) => _CreateStockTakeSheet(repository: _repo),
    );
    if (created != null && created > 0 && mounted) {
      await _openDetail(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách Kiểm kê kho'),
        backgroundColor: const Color(0xFF00A76F),
        actions: [
          IconButton(
            key: const Key('createStockTakeTopButton'),
            icon: const Icon(Icons.add, size: 28),
            tooltip: 'Tạo phiếu mới',
            onPressed: _createStockTake,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text('Chưa có phiếu kiểm kê'),
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      itemCount: _items.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < _items.length) {
                          final item = _items[index];
                          return StockTakeCard(
                            summary: item,
                            onTap: () => _openDetail(item.id),
                          );
                        }
                        _loadPage();
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: PermissionBuilder(
        menuCode: 'STOCKTAKE',
        action: 'CREATE',
        child: FloatingActionButton.extended(
          onPressed: _createStockTake,
          backgroundColor: const Color(0xFF00A76F),
          icon: const Icon(Icons.add),
          label: const Text('Phiếu mới'),
        ),
      ),
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
      {for (final l in _locations) if (l.zoneName.isNotEmpty) l.zoneName}.toList()
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'BƯỚC 1 - CHỤP SNAPSHOT',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF00A76F),
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
                                style: TextStyle(fontSize: 12, color: Colors.grey),
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
                      value: _warehouseId,
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
                            value: _scope,
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
                                  value: null,
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
                                      value: _zoneName,
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
                                          value: _locationId,
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
                                                  value: _selectedLotId,
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
                                                  value: _selectedSkuId,
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
                    TextField(
                      key: const Key('noteField'),
                      controller: _noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú',
                        hintText: 'Mục đích hoặc hướng dẫn kiểm kê',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF8F4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFB7E4D3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00A76F),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Snapshot do\nbackend tạo',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Các dòng tồn hợp lệ trong phạm vi sẽ được cố định tại thời điểm tạo phiếu. Phiếu trống sẽ không được tạo.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF004B36),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            child: const Text('Hủy'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            key: const Key('submitButton'),
                            onPressed: _saving ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF00A76F),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            child: _saving
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Tạo & bắt đầu kiểm'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

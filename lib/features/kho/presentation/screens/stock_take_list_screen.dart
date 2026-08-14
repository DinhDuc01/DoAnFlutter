import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_reload_mixin.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/stock_take_repository.dart';
import '../../models/inventory_stock.dart' show WarehouseOption;
import '../../models/stock_take.dart';
import 'stock_take_detail_screen.dart';

/// Danh sách phiếu kiểm kê + tạo phiếu mới theo phạm vi.
///
/// Phiếu do BACKEND chụp snapshot (gồm cả danh sách bao của từng lô tại từng
/// vị trí), app chỉ chọn phạm vi kiểm kê. Đơn vị kiểm đếm là BAO chứ không phải
/// kg: kho gạo lưu hàng theo bao nên "thiếu 50 kg" không cho biết là mất một
/// bao hay hao đều nhiều bao.
class StockTakeListScreen extends StatefulWidget {
  const StockTakeListScreen({this.repository, super.key});

  final StockTakeRepository? repository;

  @override
  State<StockTakeListScreen> createState() => _StockTakeListScreenState();
}

class _StockTakeListScreenState extends State<StockTakeListScreen>
    with RealtimeReloadMixin {
  /// Phiếu kiểm kê thường được duyệt trên web trong lúc kho vẫn đang xem danh sách.
  @override
  Set<String> get realtimeEntities => const {
        'StockTake',
        'StockTakeItem',
        'StockTakeStatus',
      };

  @override
  void onRealtimeChanged() => _load(showLoading: false);

  late final StockTakeRepository _repository;

  List<StockTakeSummaryRow> _rows = const [];
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiStockTakeRepository();
    _load(showLoading: false);
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final rows = await _repository.getStockTakes();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _openDetail(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StockTakeDetailScreen(
          stockTakeId: id,
          repository: widget.repository,
        ),
      ),
    );
    if (mounted) await _load(showLoading: false);
  }

  Future<void> _createStockTake() async {
    final created = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CreateStockTakeSheet(repository: _repository),
    );
    if (created != null && created > 0 && mounted) {
      await _openDetail(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        child: Column(
          children: [
            AppGradientHeader(
              title: 'Kiểm kê kho',
              subtitle: 'Đếm theo BAO, cân lại bao nghi ngờ, ghi nhận chất lượng',
              trailing: IconButton(
                onPressed: _load,
                color: Colors.white,
                icon: const Icon(Icons.refresh),
                tooltip: 'Tải lại',
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createStockTake,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Phiếu mới'),
      ),
    );
  }

  Widget _body() {
    if (_loading && _rows.isEmpty) return const ListSkeleton();
    if (_error != null && _rows.isEmpty) {
      final error = _error!;
      if (error is StockTakeException && error.isTransient) {
        return HNetworkState(message: error.message, onRetry: _load);
      }
      return HErrorState(message: 'Không tải được phiếu kiểm kê: $error', onRetry: _load);
    }
    if (_rows.isEmpty) {
      return const HEmptyState(
        title: 'Chưa có phiếu kiểm kê',
        description: 'Bấm "Phiếu mới" để chụp tồn kho theo kho, khu hoặc cột.',
        icon: Icons.fact_check_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(showLoading: false),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        itemCount: _rows.length,
        itemBuilder: (context, index) {
          final row = _rows[index];
          return AppCard(
            margin: const EdgeInsets.only(bottom: 8),
            onTap: () => _openDetail(row.id),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.code,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(
                        '${row.warehouseName}'
                        '${row.scopeDisplay.isEmpty ? '' : ' · ${row.scopeDisplay}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondaryFor(context)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatDate(row.createdDate, withTime: true),
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondaryFor(context)),
                      ),
                    ],
                  ),
                ),
                AppStatusChip(
                  label: row.statusName,
                  tone: switch (row.statusCode.toUpperCase()) {
                    'DRAFT' => AppTone.info,
                    'SUBMITTED' => AppTone.warning,
                    'APPROVED' => AppTone.success,
                    'REJECTED' => AppTone.danger,
                    _ => AppTone.neutral,
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Form chọn phạm vi chụp phiếu.
class _CreateStockTakeSheet extends StatefulWidget {
  const _CreateStockTakeSheet({required this.repository});

  final StockTakeRepository repository;

  @override
  State<_CreateStockTakeSheet> createState() => _CreateStockTakeSheetState();
}

class _CreateStockTakeSheetState extends State<_CreateStockTakeSheet> {
  final TextEditingController _noteController = TextEditingController();

  List<WarehouseOption> _warehouses = const [];
  List<StockTakeLocationOption> _locations = const [];
  int? _warehouseId;
  StockTakeScope _scope = StockTakeScope.column;
  String? _zoneName;
  int? _locationId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadWarehouses() async {
    try {
      final warehouses = await widget.repository.getWarehouses();
      if (!mounted) return;
      setState(() {
        _warehouses = warehouses;
        _warehouseId = warehouses.isNotEmpty ? warehouses.first.id : null;
        _loading = false;
      });
      if (_warehouseId != null) await _loadLocations(_warehouseId!);
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
            16, 4, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Tạo phiếu kiểm kê',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    'Backend sẽ chụp tồn kho và danh sách BAO trong phạm vi đã chọn.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondaryFor(context)),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: _warehouseId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Kho *',
                      prefixIcon: Icon(Icons.warehouse_outlined),
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<StockTakeScope>(
                    initialValue: _scope,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Phạm vi *',
                      prefixIcon: Icon(Icons.crop_free_rounded),
                    ),
                    items: [
                      for (final scope in StockTakeScope.values)
                        DropdownMenuItem(value: scope, child: Text(scope.label)),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() {
                              _scope = value ?? StockTakeScope.column;
                              _zoneName = null;
                              _locationId = null;
                            }),
                  ),
                  if (_scope == StockTakeScope.zone) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _zoneName,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Khu *',
                        prefixIcon: Icon(Icons.grid_view_rounded),
                      ),
                      items: [
                        for (final zone in _zones)
                          DropdownMenuItem(value: zone, child: Text(zone)),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _zoneName = value),
                    ),
                  ],
                  if (_scope == StockTakeScope.column) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _locationId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Cột *',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                      items: [
                        for (final location in _locations)
                          DropdownMenuItem(
                            value: location.id,
                            child: Text(location.label,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _locationId = value),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú',
                      hintText: 'Lý do hoặc hướng dẫn kiểm kê',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!,
                        style: const TextStyle(
                            color: AppColors.danger, fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Chụp tồn & bắt đầu kiểm'),
                  ),
                ],
              ),
      ),
    );
  }
}

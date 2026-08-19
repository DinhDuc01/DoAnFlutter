import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_reload_mixin.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/stock_take_repository.dart';
import '../../models/inventory_stock.dart' show WarehouseOption;
import '../../models/stock_take.dart';
import '../widgets/qr_scan_screen.dart';
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _createStockTake,
                    color: Colors.white,
                    icon: const Icon(Icons.add, size: 28),
                    tooltip: 'Tạo phiếu mới',
                  ),
                  IconButton(
                    onPressed: _load,
                    color: Colors.white,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Tải lại',
                  ),
                ],
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
  StockTakeScopeOptions _scopeOptions = const StockTakeScopeOptions();
  int? _warehouseId;
  StockTakeScope _scope = StockTakeScope.column;
  String? _zoneName;
  int? _locationId;
  int? _paddyLotId;

  /// Kiểm kê lại KHU CÁCH LY: dropdown chỉ liệt kê ô cách ly.
  bool _quarantineOnly = false;
  bool _loading = true;
  bool _loadingScopes = false;
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
      if (_warehouseId != null) await _loadScopeOptions(_warehouseId!);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  /// Chỉ lấy khu/cột/lô ĐANG CÓ BAO — kiểm kê theo bao mà cột rỗng thì không có
  /// gì để đếm, đưa vào dropdown chỉ làm thủ kho chọn nhầm.
  Future<void> _loadScopeOptions(int warehouseId) async {
    setState(() => _loadingScopes = true);
    try {
      final options = await widget.repository.getScopeOptions(
        warehouseId,
        quarantineOnly: _quarantineOnly ? true : null,
      );
      if (!mounted) return;
      setState(() {
        _scopeOptions = options;
        _locationId = null;
        _zoneName = null;
        _paddyLotId = null;
        _loadingScopes = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loadingScopes = false;
      });
    }
  }

  /// Quét tem QR dán trên cột/khu/lô để chọn phạm vi thay vì mò dropdown.
  Future<void> _scanScope() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const QrScanScreen(
          title: 'Quét tem khu/cột/lô',
          hint: 'Đưa camera vào tem QR dán trên cột, khu hoặc lô',
        ),
      ),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;

    setState(() => _saving = true);
    try {
      final result = await widget.repository
          .resolveScopeQr(code, warehouseId: _warehouseId);
      if (!mounted) return;
      if (!result.matched) {
        setState(() {
          _error = result.message;
          _saving = false;
        });
        return;
      }
      final warehouseChanged =
          result.warehouseId != null && result.warehouseId != _warehouseId;
      setState(() {
        _error = null;
        _saving = false;
        _warehouseId = result.warehouseId ?? _warehouseId;
        _scope = StockTakeScopeX.fromCode(result.scopeType);
        _quarantineOnly = result.isQuarantine;
        _zoneName = result.zoneName;
        _locationId = result.locationId;
        _paddyLotId = result.paddyLotId;
      });
      if (warehouseChanged && _warehouseId != null) {
        // Nạp lại danh mục theo kho mới nhưng GIỮ phạm vi vừa quét.
        final zone = _zoneName;
        final location = _locationId;
        final lot = _paddyLotId;
        await _loadScopeOptions(_warehouseId!);
        if (!mounted) return;
        setState(() {
          _zoneName = zone;
          _locationId = location;
          _paddyLotId = lot;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              content: Text('${result.message} · ${result.bagCount} bao')));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _saving = false;
      });
    }
  }

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
    if (_scope == StockTakeScope.lot && _paddyLotId == null) {
      setState(() => _error = 'Vui lòng chọn lô cần kiểm.');
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
        paddyLotId: _scope == StockTakeScope.lot ? _paddyLotId : null,
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

  Widget _scopeValuePicker() {
    if (_loadingScopes) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    switch (_scope) {
      case StockTakeScope.zone:
        return DropdownButtonFormField<String>(
          initialValue: _zoneName,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Khu *',
            prefixIcon: Icon(Icons.grid_view_rounded),
          ),
          items: [
            for (final zone in _scopeOptions.zones)
              DropdownMenuItem(
                value: zone.zoneName,
                child: Text(zone.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _saving ? null : (value) => setState(() => _zoneName = value),
        );
      case StockTakeScope.column:
        return DropdownButtonFormField<int>(
          initialValue: _locationId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Cột *',
            prefixIcon: Icon(Icons.place_outlined),
          ),
          items: [
            for (final column in _scopeOptions.columns)
              DropdownMenuItem(
                value: column.locationId,
                child: Text(column.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _saving ? null : (value) => setState(() => _locationId = value),
        );
      case StockTakeScope.lot:
        return DropdownButtonFormField<int>(
          initialValue: _paddyLotId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Lô *',
            prefixIcon: Icon(Icons.inventory_2_outlined),
          ),
          items: [
            for (final lot in _scopeOptions.lots)
              DropdownMenuItem(
                value: lot.paddyLotId,
                child: Text(lot.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _saving ? null : (value) => setState(() => _paddyLotId = value),
        );
      case StockTakeScope.warehouse:
        return const SizedBox.shrink();
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
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Tạo phiếu kiểm kê',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      'Backend sẽ chụp danh sách BAO trong phạm vi, kèm thứ tự lấy ra từ trên cột xuống.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondaryFor(context)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _scanScope,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Quét QR khu / cột / lô'),
                    ),
                    const SizedBox(height: 12),
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
                              _loadScopeOptions(value);
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
                                _paddyLotId = null;
                              }),
                    ),
                    if (_scope != StockTakeScope.warehouse) ...[
                      const SizedBox(height: 12),
                      _scopeValuePicker(),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _quarantineOnly,
                      title: const Text('Kiểm kê lại KHU CÁCH LY',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      subtitle: const Text(
                          'Chỉ hiện ô cách ly; bao đạt sẽ được rút về khu thường.',
                          style: TextStyle(fontSize: 11.5)),
                      onChanged: _saving
                          ? null
                          : (value) {
                              setState(() => _quarantineOnly = value);
                              if (_warehouseId != null) _loadScopeOptions(_warehouseId!);
                            },
                    ),
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
                          : const Text('Chụp danh sách bao & bắt đầu kiểm'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

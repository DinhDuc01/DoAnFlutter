import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_reload_mixin.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_pagination.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/permission_guard.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../scan/presentation/screens/scan_qr_screen.dart';
import '../../data/paddy_lot_repository.dart';
import '../../models/paddy_lot.dart';
import 'paddy_lot_detail_screen.dart';

class PaddyLotListScreen extends StatefulWidget {
  const PaddyLotListScreen({this.repository, super.key});

  final PaddyLotRepository? repository;

  @override
  State<PaddyLotListScreen> createState() => _PaddyLotListScreenState();
}

class _PaddyLotListScreenState extends State<PaddyLotListScreen>
    with RealtimeReloadMixin {
  /// Lô đổi trạng thái khi kiểm định, nhập kho, xay xát hay xuất kho ở nơi khác.
  @override
  Set<String> get realtimeEntities => const {
        'PaddyLot',
        'PaddyLotBag',
        'PaddyLotBagContent',
        'PaddyLotBagMovement',
        'LotStatus',
        'QualityInspection',
        'Inventory',
        'MillingOrderInput',
        'MillingOrderOutput',
      };

  @override
  void onRealtimeChanged() => _load(showLoading: false);

  static const int _pageSize = 20;

  late final PaddyLotRepository _repository;
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  PaddyLotPage? _page;
  Object? _error;
  bool _loading = true;
  int _pageNumber = 1;

  PaddyLotFilter _filter = const PaddyLotFilter();
  List<PaddyLotFilterOption> _warehouses = const [];
  List<PaddyLotFilterOption> _statuses = const [];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiPaddyLotRepository();
    // _loading đã mặc định true nên không cần (và không được) setState ở đây.
    _load(showLoading: false);
    _loadFilterOptions();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int get _totalPages =>
      (_page?.totalRecords ?? 0) <= 0
          ? 1
          : (((_page!.totalRecords) + _pageSize - 1) ~/ _pageSize);

  /// Nạp nguồn cho hai dropdown. Trước đây danh sách này được suy ra từ chính
  /// các lô đã tải; mà `GET /paddy-lots` không trả warehouseName/statusName nên
  /// danh sách luôn rỗng và dropdown bị disable. Nay lấy từ danh mục thật.
  Future<void> _loadFilterOptions() async {
    final results = await Future.wait([
      _repository.getWarehouseOptions(),
      _repository.getStatusOptions(),
    ]);
    if (!mounted) return;
    setState(() {
      _warehouses = results[0];
      _statuses = results[1];
    });
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final start = (_pageNumber - 1) * _pageSize;
      final page = await _repository.searchLots(
        filter: _filter,
        start: start,
        length: _pageSize,
      );
      if (!mounted) return;

      if (page.lots.isEmpty && page.totalRecords > 0 && _pageNumber > 1) {
        final lastPage = (page.totalRecords + _pageSize - 1) ~/ _pageSize;
        final target = lastPage < _pageNumber ? lastPage : _pageNumber - 1;
        _pageNumber = target < 1 ? 1 : target;
        await _load(showLoading: false);
        return;
      }

      setState(() {
        _page = page;
        _error = null;
        _loading = false;
      });
      _scrollToTop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(0);
  }

  void _goToPage(int page) {
    if (page == _pageNumber) return;
    setState(() => _pageNumber = page);
    _load();
  }

  void _applyFilter(PaddyLotFilter next) {
    setState(() {
      _filter = next;
      _pageNumber = 1;
    });
    _load();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _applyFilter(_filter.copyWith(keyword: value));
    });
  }

  void _clearFilters() {
    _searchController.clear();
    _applyFilter(const PaddyLotFilter());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        child: Column(
          children: [
            AppGradientHeader(
              title: 'Lô & truy vết',
              subtitle: 'Theo dõi nguồn gốc lúa, gạo và phụ phẩm',
              leading: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                color: Colors.white,
                icon: const Icon(Icons.arrow_back),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PermissionBuilder(
                    menuCode: 'PRODUCT_VARIANTS',
                    action: 'READ',
                    child: IconButton(
                      // Mở thẳng màn quét ở chế độ "tra cứu lô": quét xong (bằng
                      // camera hoặc từ ảnh trong máy) là vào ngay chi tiết lô.
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const PermissionGuard(
                              menuCode: 'PRODUCT_VARIANTS',
                              child: ScanQrScreen(autoOpenLot: true),
                            ),
                          ),
                        );
                        if (mounted) _load();
                      },
                      color: Colors.white,
                      tooltip: 'Quét QR lô',
                      icon: const Icon(Icons.qr_code_scanner),
                    ),
                  ),
                  IconButton(
                    onPressed: _load,
                    color: Colors.white,
                    tooltip: 'Tải lại',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _page == null) return const ListSkeleton();
    if (_error != null && _page == null) return _errorState(_error!);

    final page = _page!;
    final lots = page.lots;

    return RefreshIndicator(
      onRefresh: () => _load(showLoading: false),
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          _Summary(lots: lots, totalRecords: page.totalRecords),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: _onSearch,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Tìm mã lô, SKU, giống lúa hoặc kho',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 10),
          _Filters(
            filter: _filter,
            warehouses: _warehouses,
            statuses: _statuses,
            onChanged: _applyFilter,
            onClear: _clearFilters,
          ),
          const SizedBox(height: 14),
          if (lots.isEmpty)
            HEmptyState(
              title: _filter.isEmpty
                  ? 'Chưa có lô hàng'
                  : 'Không tìm thấy lô phù hợp',
              description: _filter.isEmpty
                  ? 'Backend chưa trả về lô lúa, gạo hoặc phụ phẩm nào.'
                  : 'Thử thay đổi từ khóa hoặc xóa bộ lọc.',
              icon: _filter.isEmpty
                  ? Icons.inventory_2_outlined
                  : Icons.filter_alt_off_outlined,
            )
          else ...[
            for (final lot in lots)
              _LotCard(
                lot: lot,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PaddyLotDetailScreen(
                      lotId: lot.id,
                      repository: _repository,
                    ),
                  ),
                ),
              ),
            if (page.totalRecords > 0) ...[
              const SizedBox(height: 8),
              AppPagination(
                page: _pageNumber,
                totalPages: _totalPages,
                total: page.totalRecords,
                enabled: !_loading,
                onChanged: _goToPage,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _errorState(Object error) {
    if (error is PaddyLotException) {
      if (error.statusCode == 401) {
        return _AccessState(
          icon: Icons.lock_outline,
          title: 'Phiên đăng nhập không hợp lệ',
          message: error.message,
          onRetry: _load,
        );
      }
      if (error.statusCode == 403) {
        return _AccessState(
          icon: Icons.gpp_bad_outlined,
          title: 'Không có quyền xem lô',
          message: error.message,
          onRetry: _load,
        );
      }
      if (error.isTransient) {
        return HNetworkState(message: error.message, onRetry: _load);
      }
    }
    return HErrorState(
        message: 'Không tải được danh sách lô: $error', onRetry: _load);
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.lots, required this.totalRecords});
  final List<PaddyLotSummary> lots;

  /// Tổng số lô khớp bộ lọc ở server (có thể lớn hơn số đang hiển thị).
  final int totalRecords;

  @override
  Widget build(BuildContext context) {
    final paddy = lots.where((lot) => lot.lotType.toUpperCase() == 'PADDY');
    final rice = lots.where((lot) => lot.lotType.toUpperCase() == 'RICE');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Số liệu trên ${lots.length} lô đang hiển thị',
          style: TextStyle(
              fontSize: 12, color: AppColors.textSecondaryFor(context)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _Metric(label: 'Tổng lô', value: '$totalRecords')),
            const SizedBox(width: 8),
            Expanded(
              child: _Metric(
                label: 'Lúa',
                value:
                    '${paddy.fold<double>(0, (sum, lot) => sum + lot.remainingWeightKg).toStringAsFixed(0)} kg',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Metric(
                label: 'Gạo',
                value:
                    '${rice.fold<double>(0, (sum, lot) => sum + lot.remainingWeightKg).toStringAsFixed(0)} kg',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondaryFor(context))),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
}

/// Bộ lọc lô. Loại lô là hằng số nghiệp vụ; kho và trạng thái lấy từ danh mục
/// backend nên luôn chọn được, kể cả khi trang hiện tại không có lô nào thuộc
/// giá trị đó.
class _Filters extends StatelessWidget {
  const _Filters({
    required this.filter,
    required this.warehouses,
    required this.statuses,
    required this.onChanged,
    required this.onClear,
  });

  final PaddyLotFilter filter;
  final List<PaddyLotFilterOption> warehouses;
  final List<PaddyLotFilterOption> statuses;
  final ValueChanged<PaddyLotFilter> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Dropdown<String>(
                label: 'Loại lô',
                value: filter.lotType,
                items: const [
                  ('PADDY', 'Lúa'),
                  ('RICE', 'Gạo'),
                  ('BYPRODUCT', 'Phụ phẩm'),
                  ('PURCHASED_GOOD', 'Hàng mua'),
                ],
                onChanged: (value) => onChanged(
                  value == null
                      ? filter.copyWith(clearLotType: true)
                      : filter.copyWith(lotType: value),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Dropdown<int>(
                label: 'Kho',
                value: filter.warehouseId,
                items: [
                  for (final option in warehouses) (option.id, option.name),
                ],
                onChanged: (value) => onChanged(
                  value == null
                      ? filter.copyWith(clearWarehouse: true)
                      : filter.copyWith(warehouseId: value),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _Dropdown<int>(
                label: 'Trạng thái',
                value: filter.statusId,
                items: [
                  for (final option in statuses) (option.id, option.name),
                ],
                onChanged: (value) => onChanged(
                  value == null
                      ? filter.copyWith(clearStatus: true)
                      : filter.copyWith(statusId: value),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: filter.isEmpty ? null : onClear,
              icon: const Icon(Icons.clear_all),
              label: const Text('Xóa lọc'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;

  /// (giá trị gửi lên API, nhãn hiển thị)
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    // Giá trị đang chọn có thể chưa nằm trong danh mục vừa tải xong; giữ nó lại
    // để DropdownButton không ném lỗi "no item matches value".
    final values = items.map((item) => item.$1).toSet();
    final current = value != null && values.contains(value) ? value : null;

    return DropdownButtonFormField<T>(
      initialValue: current,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      hint: Text(
        items.isEmpty ? 'Không có dữ liệu' : 'Tất cả',
        overflow: TextOverflow.ellipsis,
      ),
      items: [
        DropdownMenuItem<T>(value: null, child: const Text('Tất cả')),
        for (final (itemValue, itemLabel) in items)
          DropdownMenuItem<T>(
            value: itemValue,
            child: Text(itemLabel, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: items.isEmpty ? null : onChanged,
    );
  }
}

/// Thẻ lô trong danh sách.
///
/// Cố ý KHÔNG hiện kho/vị trí: danh sách chỉ để nhận diện và chọn lô, chi tiết
/// kho — ô — vị trí đã có đầy đủ trong màn chi tiết lô.
class _LotCard extends StatelessWidget {
  const _LotCard({required this.lot, required this.onTap});

  final PaddyLotSummary lot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondaryFor(context);
    final reference = lot.sourceReceiptId != null
        ? 'Phiếu mua #${lot.sourceReceiptId}'
        : lot.sourceMillingOrderId != null
            ? 'Lệnh xay #${lot.sourceMillingOrderId}'
            : 'Không có chứng từ nguồn';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  lot.lotCode,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              if (lot.statusName?.trim().isNotEmpty == true)
                AppStatusChip(
                  label: lot.statusName!.trim(),
                  tone: lot.needsAttention ? AppTone.warning : AppTone.success,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_lotType(lot.lotType)} • '
            '${lot.sku ?? lot.productName ?? lot.riceVarietyName ?? 'Chưa có sản phẩm'}',
          ),
          const SizedBox(height: 6),
          Text(
            reference,
            style: TextStyle(color: secondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.scale_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                '${lot.remainingWeightKg.toStringAsFixed(1)} kg còn lại',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (lot.qualityStatus?.trim().isNotEmpty == true)
                Flexible(
                  child: AppStatusChip(
                    label: lot.qualityStatus!.trim(),
                    tone: lot.needsAttention ? AppTone.warning : AppTone.info,
                  ),
                ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccessState extends StatelessWidget {
  const _AccessState(
      {required this.icon,
      required this.title,
      required this.message,
      required this.onRetry});
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: AppColors.warning),
              const SizedBox(height: 14),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
}

String _lotType(String value) => switch (value.toUpperCase()) {
      'PADDY' => 'Lúa',
      'RICE' => 'Gạo',
      'BYPRODUCT' => 'Phụ phẩm',
      _ => value,
    };

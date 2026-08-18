import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_service.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../products/presentation/screens/product_detail_screen.dart';
import '../../data/inventory_stock_repository.dart';
import '../../models/inventory_stock.dart';

/// Tab "Kho" — tồn kho THẬT theo lô và vị trí.
///
/// Trước đây tab này đọc phiếu kiểm kê nháp (`getDraftCheck`) rồi hiển thị như
/// thể đó là tồn kho, nên có phiếu nháp là số liệu sai hẳn; số lượng còn bị
/// `round()` về int nên mất phần lẻ kg. Nay đọc thẳng `/inventories/advanced`
/// + `/inventories/summary`, giữ nguyên phần lẻ, và tách kiểm kê thành hành
/// động phụ ở cuối màn.
class KhoTab extends StatefulWidget {
  const KhoTab({this.repository, super.key});

  final InventoryStockRepository? repository;

  @override
  State<KhoTab> createState() => _KhoTabState();
}

/// Bộ lọc nhanh theo loại hàng — đúng các nhóm nghiệp vụ lúa gạo.
enum _LotTypeTab { all, paddy, rice, byproduct }

extension on _LotTypeTab {
  String get label => switch (this) {
        _LotTypeTab.all => 'Tất cả',
        _LotTypeTab.paddy => 'Lúa',
        _LotTypeTab.rice => 'Gạo',
        _LotTypeTab.byproduct => 'Phụ phẩm',
      };

  String? get code => switch (this) {
        _LotTypeTab.all => null,
        _LotTypeTab.paddy => 'PADDY',
        _LotTypeTab.rice => 'RICE',
        _LotTypeTab.byproduct => 'BYPRODUCT',
      };
}

class _KhoTabState extends State<KhoTab> {
  late final InventoryStockRepository _repository;
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<Set<String>>? _realtimeSubscription;
  Timer? _searchDebounce;

  static const Set<String> _entities = {
    'Inventory',
    'InventoryTransaction',
    'InboundOrder',
    'OutboundOrder',
    'PaddyLot',
    'StockTake',
    'Warehouse',
    'Location',
  };

  /// Số dòng mỗi lượt tải. Nhỏ hơn màn web (10/trang) vì thẻ mobile cao hơn,
  /// nhưng đủ để lần cuộn đầu tiên không phải chờ lượt gọi thứ hai.
  static const int _pageSize = 30;

  InventoryStockFilter _filter = const InventoryStockFilter();
  _LotTypeTab _lotTab = _LotTypeTab.all;

  final ScrollController _scrollController = ScrollController();

  InventoryStockPage? _page;
  Object? _error;
  bool _loading = true;
  bool _loadingMore = false;

  /// Mỗi lần đổi bộ lọc/tải lại tăng một nấc. Kết quả của lượt tải cũ về muộn
  /// sẽ mang số cũ và bị bỏ qua, tránh trộn dữ liệu của hai bộ lọc khác nhau.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiInventoryStockRepository();
    _scrollController.addListener(_onScroll);
    // Lần tải đầu KHÔNG bật showLoading: _loading đã mặc định true, gọi
    // setState trong initState sẽ ném lỗi setState-during-build.
    _load(showLoading: false);
    _realtimeSubscription = RealtimeService.instance.onEntitiesChanged.listen((changed) {
      if (changed.isEmpty || changed.any(_entities.contains)) {
        // Giữ nguyên số dòng đang xem: người dùng cuộn sâu rồi mà một biến
        // động tồn kho kéo họ về 30 dòng đầu thì rất khó chịu.
        _load(showLoading: false, keepLoaded: true);
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _realtimeSubscription?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Tải lại từ đầu. Dùng cho lần đầu, đổi bộ lọc, realtime, kéo làm mới.
  ///
  /// [keepLoaded] = true thì lấy lại đúng số dòng đang hiển thị thay vì co về
  /// một trang, để lần tải lại do realtime không cuốn người dùng lên đầu.
  Future<void> _load({bool showLoading = true, bool keepLoaded = false}) async {
    final requestId = ++_requestId;
    final loaded = _page?.lines.length ?? 0;
    // Chặn trên để một màn đang mở rất nhiều dòng không kéo về cả nghìn bản ghi
    // mỗi lần có biến động tồn kho.
    final length = keepLoaded && loaded > _pageSize
        ? (loaded > 300 ? 300 : loaded)
        : _pageSize;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final page = await _repository.load(filter: _filter, length: length);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _page = page;
        _error = null;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = error;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  /// Tải thêm một trang và nối vào cuối danh sách.
  Future<void> _loadMore() async {
    final page = _page;
    if (page == null || _loadingMore || _loading || !page.hasMore) return;

    final requestId = _requestId;
    setState(() => _loadingMore = true);
    try {
      final next = await _repository.load(
        filter: _filter,
        start: page.lines.length,
        length: _pageSize,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _page = page.append(next);
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tải thêm được: $error')),
      );
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Nạp trước khi chạm đáy để danh sách không bị khựng giữa chừng.
    if (position.pixels >= position.maxScrollExtent - 400) {
      unawaited(_loadMore());
    }
  }

  void _applyFilter(InventoryStockFilter next) {
    setState(() => _filter = next);
    _load();
  }

  void _onSearchChanged(String value) {
    // Gõ tới đâu gọi API tới đó sẽ dội request; chờ người dùng ngừng gõ.
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _applyFilter(_filter.copyWith(keyword: value));
    });
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return ColoredBox(
      color: AppColors.backgroundFor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppGradientHeader(
            title: 'Tồn kho',
            subtitle: page == null
                ? 'Đang tải dữ liệu tồn…'
                : '${page.summary.lineCount} dòng tồn • cập nhật '
                    '${formatDate(page.loadedAt, withTime: true)}',
            trailing: IconButton(
              onPressed: () => _load(),
              color: Colors.white,
              icon: const Icon(Icons.refresh),
              tooltip: 'Tải lại',
            ),
          ),
          _searchAndFilterBar(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  // ── Bộ lọc ─────────────────────────────────────────────────────────
  Widget _searchAndFilterBar() {
    final warehouses = _page?.warehouses ?? const <WarehouseOption>[];
    final lotStatuses = _page?.lotStatuses ?? const <LotStatusOption>[];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Tìm mã lô, SKU, tên hàng, vị trí…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _applyFilter(_filter.copyWith(keyword: ''));
                      },
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final tab in _LotTypeTab.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: tab.label,
                      selected: _lotTab == tab,
                      onTap: () {
                        setState(() => _lotTab = tab);
                        _applyFilter(tab.code == null
                            ? _filter.copyWith(clearLotType: true)
                            : _filter.copyWith(lotType: tab.code));
                      },
                    ),
                  ),
                const _ChipDivider(),
                if (warehouses.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: _filter.warehouseId == null
                          ? 'Tất cả kho'
                          : warehouses
                              .firstWhere(
                                (w) => w.id == _filter.warehouseId,
                                orElse: () =>
                                    const WarehouseOption(id: 0, name: 'Kho'),
                              )
                              .name,
                      icon: Icons.warehouse_outlined,
                      selected: _filter.warehouseId != null,
                      onTap: () => _pickWarehouse(warehouses),
                    ),
                  ),
                if (lotStatuses.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: _filter.lotStatusId == null
                          ? 'Trạng thái lô'
                          : lotStatuses
                              .firstWhere(
                                (s) => s.id == _filter.lotStatusId,
                                orElse: () => const LotStatusOption(
                                    id: 0, name: 'Trạng thái lô'),
                              )
                              .name,
                      icon: Icons.label_outline_rounded,
                      selected: _filter.lotStatusId != null,
                      onTap: () => _pickLotStatus(lotStatuses),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: 'Cách ly',
                    icon: Icons.block_outlined,
                    selected: _filter.quarantinedOnly,
                    tone: AppTone.danger,
                    onTap: () => _applyFilter(_filter.copyWith(
                      quarantinedOnly: !_filter.quarantinedOnly,
                    )),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: 'Tồn thấp',
                    icon: Icons.trending_down_rounded,
                    selected: _filter.lowStockOnly,
                    tone: AppTone.warning,
                    onTap: () => _applyFilter(_filter.copyWith(
                      lowStockOnly: !_filter.lowStockOnly,
                    )),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickWarehouse(List<WarehouseOption> warehouses) async {
    final chosen = await showModalBottomSheet<int?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.select_all_rounded),
              title: const Text('Tất cả kho'),
              selected: _filter.warehouseId == null,
              onTap: () => Navigator.of(context).pop(-1),
            ),
            for (final warehouse in warehouses)
              ListTile(
                leading: const Icon(Icons.warehouse_outlined),
                title: Text(warehouse.name),
                selected: _filter.warehouseId == warehouse.id,
                onTap: () => Navigator.of(context).pop(warehouse.id),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    _applyFilter(chosen == -1
        ? _filter.copyWith(clearWarehouse: true)
        : _filter.copyWith(warehouseId: chosen));
  }

  /// Chọn trạng thái lô để lọc — đây là cách xem "chỉ các lô đang cách ly"
  /// theo TRẠNG THÁI LÔ, khác với chip "Cách ly" (lọc theo tồn đang bị giữ ở
  /// vị trí cách ly). Hai điều kiện có thể dùng cùng lúc.
  Future<void> _pickLotStatus(List<LotStatusOption> statuses) async {
    final chosen = await showModalBottomSheet<int?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.select_all_rounded),
              title: const Text('Tất cả trạng thái'),
              selected: _filter.lotStatusId == null,
              onTap: () => Navigator.of(context).pop(-1),
            ),
            for (final status in statuses)
              ListTile(
                leading: Icon(
                  status.isQuarantine
                      ? Icons.block_outlined
                      : Icons.label_outline_rounded,
                  color: status.isQuarantine ? AppColors.danger : null,
                ),
                title: Text(status.name),
                selected: _filter.lotStatusId == status.id,
                onTap: () => Navigator.of(context).pop(status.id),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    _applyFilter(chosen == -1
        ? _filter.copyWith(clearLotStatus: true)
        : _filter.copyWith(lotStatusId: chosen));
  }

  // ── Nội dung ───────────────────────────────────────────────────────
  Widget _body() {
    if (_loading && _page == null) return const ListSkeleton();
    if (_error != null && _page == null) {
      final error = _error!;
      if (error is InventoryStockException && error.isTransient) {
        return HNetworkState(message: error.message, onRetry: _load);
      }
      return HErrorState(
        message: 'Không tải được tồn kho: $error',
        onRetry: _load,
      );
    }

    final page = _page!;
    return RefreshIndicator(
      onRefresh: () => _load(showLoading: false),
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _summaryGrid(page.summary),
          const SizedBox(height: 14),
          if (page.lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: HEmptyState(
                title: _filter.isEmpty ? 'Kho chưa có hàng' : 'Không có kết quả',
                description: _filter.isEmpty
                    ? 'Chưa có dòng tồn nào lớn hơn 0.'
                    : 'Thử bỏ bớt bộ lọc hoặc đổi từ khoá tìm kiếm.',
                icon: Icons.inventory_2_outlined,
              ),
            )
          else ...[
            AppSectionHeader(
              title: 'Tồn theo lô & vị trí',
              icon: Icons.grid_view_rounded,
              action: Text(
                '${page.lines.length}/${page.totalRecords}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondaryFor(context),
                ),
              ),
            ),
            for (final line in page.lines) _lineCard(line),
            if (page.hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: _loadingMore
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        ),
                      )
                    // Cuộn gần đáy là tự tải; nút này chỉ để dự phòng khi
                    // danh sách chưa đủ dài để cuộn.
                    : OutlinedButton.icon(
                        onPressed: _loadMore,
                        icon: const Icon(Icons.expand_more_rounded),
                        label: Text(
                          'Tải thêm (còn '
                          '${page.totalRecords - page.lines.length} dòng)',
                        ),
                      ),
              )
            else if (page.lines.length > _pageSize)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  'Đã hiện hết ${page.lines.length} dòng.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryFor(context),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.paddyLots),
            icon: const Icon(Icons.account_tree_outlined),
            label: const Text('Lô & truy vết'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.stocktake),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Kiểm kê kho'),
          ),
        ],
      ),
    );
  }

  /// Số cho thẻ KPI: kg khi còn nhỏ, tự đổi sang tấn khi lớn để không tràn ô.
  /// Backend chưa cấu hình khối lượng thì rơi về số đơn vị (bao).
  String _kpi(InventoryStockSummary summary, double value) {
    if (!summary.hasWeightData) return '${formatNumber(value)} đv';
    if (value.abs() >= 1000) {
      return '${formatNumber(value / 1000, digits: 1)} t';
    }
    return formatKg(value, digits: 1);
  }

  Widget _summaryGrid(InventoryStockSummary summary) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AppStatTile(
                label: 'Tồn thực tế',
                value: _kpi(summary, summary.onHandKg),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppStatTile(
                label: 'Khả dụng',
                value: _kpi(summary, summary.availableKg),
                tone: AppTone.brand,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AppStatTile(
                label: 'Đã giữ',
                value: _kpi(summary, summary.reservedKg),
                tone: AppTone.info,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppStatTile(
                label: 'Đang xử lý',
                value: _kpi(summary, summary.processingKg),
                tone: AppTone.warning,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppStatTile(
                label: 'Cách ly',
                value: _kpi(summary, summary.quarantineKg),
                tone: summary.quarantineKg > 0
                    ? AppTone.danger
                    : AppTone.neutral,
              ),
            ),
          ],
        ),
        if (summary.quarantineLotCount > 0 || summary.lowStockCount > 0) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              if (summary.quarantineLotCount > 0)
                Expanded(
                  child: _AlertBanner(
                    icon: Icons.block_outlined,
                    tone: AppTone.danger,
                    text: '${summary.quarantineLotCount} lô đang cách ly',
                    onTap: () => _applyFilter(
                        _filter.copyWith(quarantinedOnly: true)),
                  ),
                ),
              if (summary.quarantineLotCount > 0 && summary.lowStockCount > 0)
                const SizedBox(width: 8),
              if (summary.lowStockCount > 0)
                Expanded(
                  child: _AlertBanner(
                    icon: Icons.trending_down_rounded,
                    tone: AppTone.warning,
                    text: '${summary.lowStockCount} dòng dưới định mức',
                    onTap: () =>
                        _applyFilter(_filter.copyWith(lowStockOnly: true)),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _lineCard(InventoryStockLine line) {
    final secondary = AppColors.textSecondaryFor(context);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ProductDetailScreen(productVariantId: line.productVariantId),
        ),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            line.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (line.lotType != null) ...[
                          const SizedBox(width: 6),
                          _TypePill(lotType: line.lotType!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line.productLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: secondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatKg(line.quantityOnHand),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    'KD ${formatKg(line.quantityAvailable)}',
                    style: TextStyle(fontSize: 11, color: secondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MetaPill(
                icon: Icons.warehouse_outlined,
                text: line.warehouseName ?? 'Kho ${line.warehouseId}',
              ),
              _MetaPill(
                icon: Icons.place_outlined,
                text: line.locationLabel,
              ),
              if (line.hasPhysicalBagData)
                _MetaPill(
                  icon: Icons.inventory_2_outlined,
                  text: line.openBags > 0
                      ? '${line.bags} bao (${line.openBags} lẻ)'
                      : '${line.bags} bao',
                ),
              if (line.quantityReserved > 0)
                _MetaPill(
                  icon: Icons.lock_outline_rounded,
                  text: 'Giữ ${formatKg(line.quantityReserved)}',
                  tone: AppTone.info,
                ),
              if (line.isProcessing)
                _MetaPill(
                  icon: Icons.autorenew_rounded,
                  text: 'Xử lý ${formatKg(line.quantityProcessing)}',
                  tone: AppTone.warning,
                ),
              if (line.isQuarantined)
                _MetaPill(
                  icon: Icons.block_outlined,
                  text: 'Cách ly ${formatKg(line.quantityQuarantine)}',
                  tone: AppTone.danger,
                ),
              if (line.isLowStock)
                _MetaPill(
                  icon: Icons.trending_down_rounded,
                  text: line.minStockLevel == null
                      ? 'Tồn thấp'
                      : 'Dưới định mức ${formatKg(line.minStockLevel)}',
                  tone: AppTone.warning,
                ),
              if (line.lotStatusName != null && !line.isQuarantined)
                _MetaPill(
                  icon: Icons.label_outline_rounded,
                  text: line.lotStatusName!,
                  tone: line.lotIsSellable == false
                      ? AppTone.warning
                      : AppTone.neutral,
                ),
            ],
          ),
          if (line.lotQualityStatus?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              line.lotQualityStatus!.trim(),
              style: TextStyle(fontSize: 11.5, color: secondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.tone = AppTone.brand,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final foreground =
        selected ? tone.fg : AppColors.textSecondaryFor(context);
    return Material(
      color: selected ? tone.bg : AppColors.surfaceFor(context),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected ? tone.fg : AppColors.borderFor(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipDivider extends StatelessWidget {
  const _ChipDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: AppColors.borderFor(context),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.lotType});

  final String lotType;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (lotType.toUpperCase()) {
      'PADDY' => ('Lúa', AppTone.warning),
      'RICE' => ('Gạo', AppTone.brand),
      'BYPRODUCT' => ('Phụ phẩm', AppTone.info),
      'PURCHASED_GOOD' => ('Hàng mua', AppTone.neutral),
      _ => (lotType, AppTone.neutral),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: tone.fg,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.text,
    this.tone = AppTone.neutral,
  });

  final IconData icon;
  final String text;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tone == AppTone.neutral
            ? AppColors.subtleSurfaceFor(context)
            : tone.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: tone == AppTone.neutral
                ? AppColors.textSecondaryFor(context)
                : tone.fg,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: tone == AppTone.neutral
                  ? AppColors.textSecondaryFor(context)
                  : tone.fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({
    required this.icon,
    required this.text,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final AppTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tone.bg,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Icon(icon, size: 16, color: tone.fg),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: tone.fg,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 16, color: tone.fg),
            ],
          ),
        ),
      ),
    );
  }
}

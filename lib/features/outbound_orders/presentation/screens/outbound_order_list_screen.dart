import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/app_pagination.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../sales_orders/presentation/screens/sales_order_list_screen.dart';
import '../../data/outbound_order_repository.dart';
import '../../models/outbound_order.dart';
import 'outbound_order_detail_screen.dart';

/// Danh sách phiếu xuất kho / giao hàng.
///
/// Lọc trạng thái và phân trang đều chạy phía backend qua
/// `POST /outbound-orders/paged`, nên tổng số trang luôn khớp bộ lọc đang chọn.
/// Đổi từ khóa hoặc trạng thái đều quay về trang 1.
class OutboundOrderListScreen extends StatefulWidget {
  const OutboundOrderListScreen({
    this.repository,
    this.embedded = false,
    super.key,
  });

  final OutboundOrderRepository? repository;

  /// true khi nhúng làm tab (không hiện nút quay lại).
  final bool embedded;

  @override
  State<OutboundOrderListScreen> createState() =>
      _OutboundOrderListScreenState();
}

class _OutboundOrderListScreenState extends State<OutboundOrderListScreen> {
  static const int _pageSize = 20;

  /// Tab lọc trạng thái, ánh xạ 1-1 với `outboundStatusId` của backend.
  static const List<({int? id, String label})> _statusTabs = [
    (id: null, label: 'Tất cả'),
    (id: OutboundStatusIds.draft, label: 'Nháp'),
    (id: OutboundStatusIds.picking, label: 'Đang lấy hàng'),
    (id: OutboundStatusIds.packed, label: 'Chờ xuất kho'),
    (id: OutboundStatusIds.dispatched, label: 'Đang giao'),
    (id: OutboundStatusIds.completed, label: 'Hoàn tất'),
    (id: OutboundStatusIds.deliveryFailed, label: 'Giao lỗi'),
    (id: OutboundStatusIds.cancelled, label: 'Đã hủy'),
  ];

  late final OutboundOrderRepository _repository;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  /// Tăng mỗi lần gửi request; kết quả về trễ của request cũ sẽ bị bỏ qua để
  /// đổi bộ lọc nhanh không ghi đè dữ liệu của bộ lọc mới.
  int _requestId = 0;

  List<OutboundOrderSummary> _orders = const [];
  int _total = 0;
  int _page = 1;
  String _keyword = '';
  int? _statusId;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiOutboundOrderRepository();
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

  Future<void> _load({bool showLoading = true}) async {
    final requestId = ++_requestId;
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await _repository.getPaged(
        keyword: _keyword,
        statusId: _statusId,
        page: _page,
        pageSize: _pageSize,
      );
      if (!mounted || requestId != _requestId) return;

      // Trang hiện tại rỗng (do phiếu bị hủy/đổi trạng thái) → lùi về trang
      // hợp lệ. Trang mới luôn nhỏ hơn trang cũ nên vòng lặp chắc chắn dừng.
      if (result.items.isEmpty && result.total > 0 && _page > 1) {
        final lastPage = (result.total + _pageSize - 1) ~/ _pageSize;
        final target = lastPage < _page ? lastPage : _page - 1;
        _page = target < 1 ? 1 : target;
        await _load(showLoading: false);
        return;
      }

      setState(() {
        _orders = result.items;
        _total = result.total;
        _loading = false;
        _error = null;
      });
      _scrollToTop();
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = error;
        _orders = const [];
        _total = 0;
      });
    }
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(0);
  }

  /// Đổi bộ lọc luôn kéo về trang 1 — nếu giữ nguyên trang cũ có thể rơi vào
  /// trang vượt quá tổng số trang của kết quả mới.
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

  Future<void> _openDetail(OutboundOrderSummary order) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => OutboundOrderDetailScreen(
          outboundOrderId: order.id,
          repository: _repository,
        ),
      ),
    );
    if (changed == true) _load(showLoading: false);
  }

  void _openSalesOrders() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SalesOrderListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        AppGradientHeader(
          title: 'Xuất kho & giao hàng',
          subtitle: 'Phân bổ lô, lấy hàng, xuất kho và thu tiền',
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
                onPressed: _openSalesOrders,
                color: Colors.white,
                tooltip: 'Đơn bán',
                icon: const Icon(Icons.receipt_long_outlined),
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

    if (widget.embedded) {
      return ColoredBox(color: AppColors.backgroundFor(context), child: content);
    }
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(child: content),
    );
  }

  Widget _body() {
    if (_loading && _orders.isEmpty && _error == null) {
      return const ListSkeleton();
    }
    if (_error != null) return _errorState(_error!);

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
              labelText: 'Tìm mã đơn bán hoặc khách hàng',
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
          const SizedBox(height: 14),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_orders.isEmpty)
            const HEmptyState(
              title: 'Không có phiếu xuất phù hợp',
              description:
                  'Thử đổi từ khóa hoặc trạng thái. Phiếu xuất được tạo từ màn Đơn bán.',
              icon: Icons.local_shipping_outlined,
            )
          else
            for (final order in _orders)
              _OutboundCard(order: order, onTap: () => _openDetail(order)),
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
              selected: _statusId == tab.id,
              onSelected: _loading
                  ? null
                  : (_) => _applyFilter(() => _statusId = tab.id),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _errorState(Object error) {
    if (error is OutboundOrderException) {
      if (error.statusCode == 401) {
        return HErrorState(
          message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          onRetry: _load,
        );
      }
      if (error.statusCode == 403) {
        return HErrorState(
          message: 'Bạn không có quyền xem phiếu xuất.',
          onRetry: _load,
        );
      }
      if (error.isTransient) {
        return HNetworkState(message: error.message, onRetry: _load);
      }
      return HErrorState(message: error.message, onRetry: _load);
    }
    return HErrorState(
      message: 'Không tải được danh sách phiếu xuất: $error',
      onRetry: _load,
    );
  }
}

/// Sắc thái chip trạng thái phiếu xuất.
AppTone outboundTone(int statusId) => switch (statusId) {
      OutboundStatusIds.cancelled ||
      OutboundStatusIds.deliveryFailed =>
        AppTone.danger,
      OutboundStatusIds.completed => AppTone.success,
      OutboundStatusIds.dispatched => AppTone.info,
      OutboundStatusIds.draft => AppTone.neutral,
      _ => AppTone.brand,
    };

class _OutboundCard extends StatelessWidget {
  const _OutboundCard({required this.order, required this.onTap});

  final OutboundOrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondaryFor(context);
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
                  'Phiếu #${order.id} • ${order.soCode}',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              AppStatusChip(
                label: order.statusLabel,
                tone: outboundTone(order.statusId),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            order.customerName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${order.warehouseName ?? 'Chưa rõ kho'} • Tạo ${formatDate(order.createdDate)}',
            style: TextStyle(fontSize: 12, color: secondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.payments_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  formatMoney(order.totalDispatchedSaleValue),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (order.completedDate != null)
                Text(
                  'Xong ${formatDate(order.completedDate)}',
                  style: TextStyle(fontSize: 12, color: secondary),
                ),
              const Icon(Icons.chevron_right),
            ],
          ),
          if (order.statusId == OutboundStatusIds.cancelled &&
              (order.cancelReason?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            Text(
              'Lý do hủy: ${order.cancelReason!.trim()}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

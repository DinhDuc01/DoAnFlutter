import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_reload_mixin.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_pagination.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/permission_guard.dart';
import '../../../auth/data/auth_session_store.dart';
import '../../data/sales_order_repository.dart';
import '../../models/sales_order.dart';
import '../widgets/sales_order_card.dart';
import 'sales_order_create_screen.dart';
import 'sales_order_detail_screen.dart';

/// Danh sách đơn bán.
///
/// Mobile được tạo, xác nhận và kiểm tra & giữ hàng theo permission/status
/// giống contract mà Web đang dùng.
///
/// Lọc trạng thái, lọc kênh bán và phân trang đều chạy phía backend qua
/// `POST /sales-orders/paged`, nên tổng số trang luôn khớp bộ lọc đang chọn.
/// Mỗi lần đổi từ khóa hoặc bộ lọc đều quay về trang 1 để không rơi vào trang
/// không tồn tại của tập kết quả mới.
class SalesOrderListScreen extends StatefulWidget {
  const SalesOrderListScreen(
      {this.repository, this.embedded = false, super.key});

  final SalesOrderRepository? repository;

  /// true khi nhúng làm tab (không hiện nút quay lại).
  final bool embedded;

  @override
  State<SalesOrderListScreen> createState() => _SalesOrderListScreenState();
}

class _SalesOrderListScreenState extends State<SalesOrderListScreen>
    with RealtimeReloadMixin {
  static const int _pageSize = 20;

  /// Đơn bán đổi trạng thái do phiếu xuất/lệnh xay/công nợ ở nơi khác → tải lại.
  @override
  Set<String> get realtimeEntities => const {
        'SalesOrder',
        'SalesOrderItem',
        'OutboundOrder',
        'OutboundOrderItem',
        'MillingOrder',
        'SalesOrderStatus',
        'Customer',
      };

  @override
  void onRealtimeChanged() => _load(showLoading: false);

  /// Chip lọc trạng thái — ánh xạ 1-1 với `statusId` của backend để bộ lọc và
  /// phân trang không đá nhau.
  static const List<({int? id, String label})> _statusTabs = [
    (id: null, label: 'Tất cả'),
    (id: SalesOrderStatusIds.newOrder, label: 'Mới tạo'),
    (id: SalesOrderStatusIds.pendingConfirm, label: 'Chờ xác nhận'),
    (id: SalesOrderStatusIds.reserved, label: 'Đã giữ hàng'),
    (id: SalesOrderStatusIds.awaitingMilling, label: 'Chờ xay xát'),
    (id: SalesOrderStatusIds.preparing, label: 'Đang chuẩn bị'),
    (id: SalesOrderStatusIds.delivering, label: 'Đang giao'),
    (id: SalesOrderStatusIds.completed, label: 'Hoàn tất'),
    (id: SalesOrderStatusIds.cancelled, label: 'Đã hủy'),
  ];

  /// Chip lọc kênh bán — khớp ràng buộc `DIRECT | WHOLESALE` của backend.
  static const List<({String? code, String label})> _channelTabs = [
    (code: null, label: 'Mọi kênh'),
    (code: 'DIRECT', label: 'Bán trực tiếp'),
    (code: 'WHOLESALE', label: 'Bán sỉ'),
  ];

  late final SalesOrderRepository _repository;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  /// Tăng mỗi lần gửi request; kết quả về trễ của request cũ sẽ bị bỏ qua để
  /// đổi bộ lọc nhanh không ghi đè dữ liệu của bộ lọc mới.
  int _requestId = 0;

  List<SalesOrderSummary> _orders = const [];
  int _total = 0;
  int _page = 1;
  String _keyword = '';
  int? _statusId;
  String? _channel;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiSalesOrderRepository();
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
        channel: _channel,
        page: _page,
        pageSize: _pageSize,
      );
      if (!mounted || requestId != _requestId) return;

      // Xóa bản ghi cuối của trang cuối có thể làm trang hiện tại rỗng →
      // lùi về trang hợp lệ thay vì hiển thị danh sách trống. Trang mới luôn
      // nhỏ hơn trang cũ nên vòng lặp chắc chắn dừng.
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

  Future<void> _openDetail(SalesOrderSummary order) =>
      _openDetailById(order.id);

  Future<void> _openDetailById(int salesOrderId) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SalesOrderDetailScreen(
          salesOrderId: salesOrderId,
          repository: _repository,
        ),
      ),
    );
    if (changed == true) _load(showLoading: false);
  }

  /// Mở form tạo đơn bán; tạo xong thì mở luôn chi tiết đơn vừa tạo.
  Future<void> _createOrder() async {
    if (AuthSessionStore.current?.hasPermission('SALE_ORDERS', 'CREATE') !=
        true) {
      return;
    }
    final created = await Navigator.of(context).push<CreatedSalesOrder>(
      MaterialPageRoute<CreatedSalesOrder>(
        builder: (_) => SalesOrderCreateScreen(repository: _repository),
      ),
    );
    if (!mounted || created == null) return;

    await _load(showLoading: false);
    if (!mounted || created.id <= 0) return;
    await _openDetailById(created.id);
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        AppGradientHeader(
          title: 'Đơn bán',
          subtitle: 'Tạo đơn, giữ hàng và tạo phiếu xuất kho',
          leading: widget.embedded
              ? null
              : IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  color: Colors.white,
                  icon: const Icon(Icons.arrow_back),
                ),
          trailing: IconButton(
            onPressed: _loading ? null : () => _load(),
            color: Colors.white,
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
          ),
        ),
        Expanded(child: _body()),
      ],
    );

    final createButton =
        AuthSessionStore.current?.user.isWarehouseWorker == true
            ? const SizedBox.shrink()
            : PermissionBuilder(
                menuCode: 'SALE_ORDERS',
                action: 'CREATE',
                child: FloatingActionButton.extended(
                  onPressed: _createOrder,
                  icon: const Icon(Icons.add),
                  label: const Text('Tạo đơn bán'),
                ),
              );

    if (widget.embedded) {
      // Khi nhúng làm tab, Scaffold cha không nhận FAB nên đặt nút nổi bằng Stack.
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
              labelText: 'Tìm mã đơn hoặc khách hàng',
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
          const SizedBox(height: 8),
          _channelChips(),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_orders.isEmpty)
            const HEmptyState(
              title: 'Không có đơn bán phù hợp',
              description:
                  'Thử đổi từ khóa, trạng thái hoặc kênh bán, hoặc bấm "Tạo đơn bán".',
              icon: Icons.receipt_long_outlined,
            )
          else
            for (final order in _orders)
              SalesOrderCard(order: order, onTap: () => _openDetail(order)),
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

  Widget _channelChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              Icons.storefront_outlined,
              size: 18,
              color: AppColors.textSecondaryFor(context),
            ),
          ),
          for (final tab in _channelTabs) ...[
            ChoiceChip(
              label: Text(tab.label),
              selected: _channel == tab.code,
              onSelected: _loading
                  ? null
                  : (_) => _applyFilter(() => _channel = tab.code),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _errorState(Object error) {
    if (error is SalesOrderException) {
      if (error.statusCode == 401) {
        return HErrorState(
          message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          onRetry: _load,
        );
      }
      if (error.statusCode == 403) {
        return HErrorState(
          message: 'Bạn không có quyền xem đơn bán.',
          onRetry: _load,
        );
      }
      if (error.isTransient) {
        return HNetworkState(message: error.message, onRetry: _load);
      }
      return HErrorState(message: error.message, onRetry: _load);
    }
    return HErrorState(
      message: 'Không tải được danh sách đơn bán: $error',
      onRetry: _load,
    );
  }
}

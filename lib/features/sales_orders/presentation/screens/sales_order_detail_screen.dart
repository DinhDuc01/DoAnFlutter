import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../milling/models/milling_plan_args.dart';
import '../../../outbound_orders/models/outbound_order.dart';
import '../../../outbound_orders/presentation/screens/outbound_order_detail_screen.dart';
import '../../data/sales_order_repository.dart';
import '../../models/sales_order.dart';
import '../widgets/sales_order_card.dart' show salesOrderTone;
import '../widgets/create_outbound_sheet.dart';

/// Chi tiết đơn bán: xem thông tin, hủy đơn kèm lý do, tạo phiếu xuất và mở
/// màn xay xát cho đơn cần xay.
///
/// Không có chức năng tạo/sửa/xác nhận/giữ hàng — các bước đó chỉ làm trên web.
class SalesOrderDetailScreen extends StatefulWidget {
  const SalesOrderDetailScreen({
    required this.salesOrderId,
    this.repository,
    super.key,
  });

  final int salesOrderId;
  final SalesOrderRepository? repository;

  @override
  State<SalesOrderDetailScreen> createState() => _SalesOrderDetailScreenState();
}

class _SalesOrderDetailScreenState extends State<SalesOrderDetailScreen> {
  late final SalesOrderRepository _repository;
  SalesOrderDetail? _order;
  Object? _error;
  bool _loading = true;
  bool _busy = false;

  /// true nếu đã có thao tác làm đổi dữ liệu → màn danh sách cần tải lại.
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiSalesOrderRepository();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final order = await _repository.getById(widget.salesOrderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_order == null) _error = error;
      });
      if (_order != null) _snack('Không làm mới được đơn bán: $error');
    }
  }

  void _snack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.primaryDark : null,
      ));
  }

  // ── Hủy đơn kèm lý do ────────────────────────────────────────────────
  Future<void> _cancelOrder(SalesOrderDetail order) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _CancelReasonDialog(soCode: order.soCode),
    );
    if (reason == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await _repository.cancel(order.id, reason: reason);
      _changed = true;
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Đã hủy đơn bán ${order.soCode}.', success: true);
      await _load(showLoading: false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('$error');
    }
  }

  // ── Tạo phiếu xuất ───────────────────────────────────────────────────
  Future<void> _createOutbound(SalesOrderDetail order) async {
    final lines = await showModalBottomSheet<List<CreateOutboundLine>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CreateOutboundSheet(order: order),
    );
    if (lines == null || lines.isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      final outboundId = await _repository.createOutbound(order.id, lines);
      _changed = true;
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(
        outboundId > 0
            ? 'Đã tạo phiếu xuất #$outboundId.'
            : 'Đã tạo phiếu xuất kho.',
        success: true,
      );
      await _load(showLoading: false);
      if (outboundId > 0) await _openOutbound(outboundId);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('$error');
    }
  }

  Future<void> _openOutbound(int outboundOrderId) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            OutboundOrderDetailScreen(outboundOrderId: outboundOrderId),
      ),
    );
    if (changed == true) {
      _changed = true;
      await _load(showLoading: false);
    }
  }

  /// Mở màn xay xát với loại kế hoạch đặt sẵn là "đơn bán cần xay".
  void _openMilling(SalesOrderDetail order) {
    Navigator.of(context).pushNamed(
      AppRoutes.milling,
      arguments: MillingPlanArgs.forSalesOrder(
        salesOrderId: order.id,
        salesOrderCode: order.soCode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        child: Column(
          children: [
            AppGradientHeader(
              overline:
                  order == null ? null : salesChannelLabel(order.channel),
              title: order?.soCode ?? 'Chi tiết đơn bán',
              subtitle: order?.customerName ?? 'Đang tải dữ liệu…',
              leading: IconButton(
                onPressed:
                    _busy ? null : () => Navigator.of(context).pop(_changed),
                color: Colors.white,
                icon: const Icon(Icons.arrow_back),
              ),
              trailing: IconButton(
                onPressed: _busy ? null : () => _load(),
                color: Colors.white,
                tooltip: 'Tải lại',
                icon: const Icon(Icons.refresh),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
      bottomNavigationBar: order == null ? null : _actionBar(order),
    );
  }

  Widget _body() {
    if (_loading && _order == null) return const FormSkeleton();
    if (_error != null && _order == null) {
      return HErrorState(message: '$_error', onRetry: _load);
    }
    final order = _order!;
    return RefreshIndicator(
      onRefresh: () => _load(showLoading: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _statusCard(order),
          const SizedBox(height: 12),
          _infoCard(order),
          const SizedBox(height: 12),
          _itemsCard(order),
          const SizedBox(height: 12),
          _amountCard(order),
          if (order.outboundOrders.isNotEmpty) ...[
            const SizedBox(height: 12),
            _outboundCard(order),
          ],
        ],
      ),
    );
  }

  Widget _statusCard(SalesOrderDetail order) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppStatusChip(
                label: order.statusLabel,
                tone: salesOrderTone(order.statusId),
              ),
              const SizedBox(width: 8),
              if (order.requiresMilling)
                const AppStatusChip(
                  label: 'Đơn cần xay',
                  tone: AppTone.warning,
                  icon: Icons.grain_outlined,
                ),
            ],
          ),
          if (order.statusId == SalesOrderStatusIds.cancelled &&
              (order.cancelReason?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: 12),
            AppInfoBanner(
              message: 'Lý do hủy: ${order.cancelReason!.trim()}',
              tone: AppTone.danger,
              icon: Icons.cancel_outlined,
            ),
          ],
          if (order.needsMilling) ...[
            const SizedBox(height: 12),
            AppInfoBanner(
              message:
                  'Đơn này phải xay xát trước khi giữ hàng. Nhấn để mở màn Xay xát với loại kế hoạch "Đơn bán cần xay".',
              tone: AppTone.warning,
              icon: Icons.grain_outlined,
              onTap: () => _openMilling(order),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoCard(SalesOrderDetail order) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'Thông tin đơn',
            icon: Icons.info_outline_rounded,
          ),
          _Line('Khách hàng', order.customerName),
          if (order.customerPhone?.isNotEmpty == true)
            _Line('Số điện thoại', order.customerPhone!),
          _Line('Kênh bán', salesChannelLabel(order.channel)),
          _Line('Kho xuất', order.warehouseName ?? 'Chưa chọn'),
          _Line('Ngày đặt', formatDate(order.orderDate, withTime: true)),
          _Line('Giao dự kiến', formatDate(order.expectedDeliveryDate)),
          if (order.shippingAddress?.isNotEmpty == true)
            _Line('Địa chỉ giao', order.shippingAddress!),
          if (order.note?.isNotEmpty == true) _Line('Ghi chú', order.note!),
        ],
      ),
    );
  }

  Widget _itemsCard(SalesOrderDetail order) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'Sản phẩm (${order.items.length})',
            icon: Icons.inventory_2_outlined,
          ),
          if (order.items.isEmpty)
            Text(
              'Đơn chưa có dòng hàng.',
              style: TextStyle(color: AppColors.textSecondaryFor(context)),
            )
          else
            for (final item in order.items) _itemRow(item),
        ],
      ),
    );
  }

  Widget _itemRow(SalesOrderItem item) {
    final secondary = AppColors.textSecondaryFor(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.productVariantName,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (item.sku?.isNotEmpty == true)
            Text(item.sku!, style: TextStyle(fontSize: 12, color: secondary)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatKg(item.quantityOrdered)} × ${formatMoney(item.unitSalePrice)}',
                  style: TextStyle(fontSize: 12.5, color: secondary),
                ),
              ),
              Text(
                formatMoney(item.lineAmount),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          if (item.discountAmount > 0)
            Text(
              'Giảm giá ${formatMoney(item.discountAmount)}',
              style: TextStyle(fontSize: 12, color: secondary),
            ),
        ],
      ),
    );
  }

  Widget _amountCard(SalesOrderDetail order) {
    return AppCard(
      child: Column(
        children: [
          _Line('Tổng tiền', formatMoney(order.totalAmount)),
          _Line('Tiền cọc', formatMoney(order.depositAmount ?? 0)),
          _Line('Còn lại', formatMoney(order.remainingAmount), strong: true),
        ],
      ),
    );
  }

  Widget _outboundCard(SalesOrderDetail order) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'Phiếu xuất (${order.outboundOrders.length})',
            icon: Icons.local_shipping_outlined,
          ),
          for (final outbound in order.outboundOrders)
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: _busy ? null : () => _openOutbound(outbound.id),
              title: Text(
                'Phiếu #${outbound.id}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${outboundStatusLabel(outbound.statusId, outbound.statusName)}'
                '${outbound.totalDispatchedSaleValue > 0 ? ' • ${formatMoney(outbound.totalDispatchedSaleValue)}' : ''}',
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
        ],
      ),
    );
  }

  Widget? _actionBar(SalesOrderDetail order) {
    final draft = order.draftOutbound;
    final buttons = <Widget>[];

    if (order.needsMilling) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _openMilling(order),
          icon: const Icon(Icons.grain_outlined),
          label: const Text('Xay xát'),
        ),
      );
    }
    if (draft != null) {
      buttons.add(
        FilledButton.icon(
          onPressed: _busy ? null : () => _openOutbound(draft.id),
          icon: const Icon(Icons.playlist_add_check_rounded),
          label: const Text('Tiếp tục phiếu xuất'),
        ),
      );
    } else if (order.canCreateOutbound) {
      buttons.add(
        FilledButton.icon(
          onPressed: _busy ? null : () => _createOutbound(order),
          icon: const Icon(Icons.local_shipping_outlined),
          label: const Text('Tạo phiếu xuất'),
        ),
      );
    }
    if (order.canCancel) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _cancelOrder(order),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Hủy đơn'),
        ),
      );
    }

    if (buttons.isEmpty) return null;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(right: 4, top: 12),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ...buttons,
        ],
      ),
    );
  }
}

/// Hộp thoại bắt buộc nhập lý do hủy đơn.
class _CancelReasonDialog extends StatefulWidget {
  const _CancelReasonDialog({required this.soCode});

  final String soCode;

  @override
  State<_CancelReasonDialog> createState() => _CancelReasonDialogState();
}

class _CancelReasonDialogState extends State<_CancelReasonDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Vui lòng nhập lý do hủy.');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hủy đơn bán?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đơn ${widget.soCode} sẽ bị hủy và phần tồn đã giữ được giải phóng.',
            style: TextStyle(color: AppColors.textSecondaryFor(context)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            maxLines: 3,
            maxLength: 500,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Lý do hủy *',
              hintText: 'VD: Khách hủy đặt hàng',
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Không hủy'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text('Hủy đơn'),
        ),
      ],
    );
  }
}

/// Dòng nhãn – giá trị dùng lại trong các card chi tiết.
class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondaryFor(context),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

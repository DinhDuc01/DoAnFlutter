import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_reload_mixin.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../auth/data/auth_session_store.dart';
import '../../../sales_orders/data/sales_order_repository.dart';
import '../../../scale/presentation/widgets/scale_status_chip.dart';
import '../../data/outbound_order_repository.dart';
import '../../models/outbound_order.dart';
import '../widgets/outbound_action_sheets.dart';
import 'outbound_order_list_screen.dart' show outboundTone;

/// Các bước của phiếu xuất, chỉ để hiển thị tiến trình (khớp web).
const List<String> _pipelineSteps = [
  'Phân bổ lô',
  'Lấy hàng',
  'Đóng gói',
  'Xuất kho',
  'Giao hàng',
];

/// Chi tiết phiếu xuất kho — nơi chạy toàn bộ luồng nghiệp vụ:
/// phân bổ lô → lấy hàng → đóng gói → xuất kho → giao thành công/thất bại,
/// và hủy phiếu khi chưa xuất kho.
class OutboundOrderDetailScreen extends StatefulWidget {
  const OutboundOrderDetailScreen({
    required this.outboundOrderId,
    this.preview,
    this.repository,
    this.salesOrderRepository,
    super.key,
  });

  final int outboundOrderId;
  final OutboundOrderDetail? preview;
  final OutboundOrderRepository? repository;
  final SalesOrderRepository? salesOrderRepository;

  @override
  State<OutboundOrderDetailScreen> createState() =>
      _OutboundOrderDetailScreenState();
}

class _OutboundOrderDetailScreenState extends State<OutboundOrderDetailScreen>
    with RealtimeReloadMixin {
  /// Nhiều người cùng xử lý một phiếu xuất (kho phân bổ, giao hàng xác nhận)
  /// nên tiến trình phải tự cập nhật, không chờ bấm tải lại.
  @override
  Set<String> get realtimeEntities => const {
        'OutboundOrder',
        'OutboundOrderItem',
        'OutboundOrderItemAllocation',
        'OutboundOrderStatus',
        'DeliveryNote',
        'SalesOrder',
        'Inventory',
        'PaddyLotBag',
      };

  @override
  void onRealtimeChanged() => _load(showLoading: false);

  late final OutboundOrderRepository _repository;
  late final SalesOrderRepository _salesOrderRepository;

  OutboundOrderDetail? _order;
  Object? _error;
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;

  bool get _canUpdate =>
      AuthSessionStore.current?.hasPermission('OUTBOUND_ORDERS', 'UPDATE') ==
      true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiOutboundOrderRepository();
    _salesOrderRepository =
        widget.salesOrderRepository ?? ApiSalesOrderRepository();
    _order = widget.preview;
    _loading = widget.preview == null;
    _load(showLoading: widget.preview == null);
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final order = await _repository.getById(widget.outboundOrderId);
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
      if (_order != null) _snack('Không làm mới được phiếu xuất: $error');
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

  /// Bọc một thao tác ghi: khóa UI, báo lỗi, tải lại chi tiết khi xong.
  Future<void> _run(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      _changed = true;
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(successMessage, success: true);
      await _load(showLoading: false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('$error');
    }
  }

  // ── 1. Phân bổ lô ────────────────────────────────────────────────────
  Future<void> _allocate(OutboundOrderDetail order) async {
    if (!_canUpdate || !order.canAllocate || _busy) return;
    setState(() => _busy = true);
    List<OutboundAllocationCandidate> candidates;
    try {
      candidates = await _repository.getAllocationCandidates(order.id);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Không tải được nguồn tồn có thể phân bổ: $error');
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    final payload = await showModalBottomSheet<List<AllocateItemPayload>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AllocateSheet(order: order, candidates: candidates),
    );
    if (payload == null || payload.isEmpty || !mounted || _busy) return;

    await _run(
      () => _repository.allocate(order.id, payload),
      successMessage: 'Đã phân bổ lô/vị trí. Phiếu chuyển sang Đang lấy hàng.',
    );
  }

  // ── 2. Lấy hàng ──────────────────────────────────────────────────────
  Future<void> _pick(OutboundOrderDetail order) async {
    if (!_canUpdate || !order.canPick || _busy) return;
    final picks = await showModalBottomSheet<List<PickAllocationPayload>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PickSheet(order: order),
    );
    if (picks == null || picks.isEmpty || !mounted || _busy) return;

    await _run(
      () => _repository.pick(order.id, picks),
      successMessage: 'Đã cập nhật số lượng lấy hàng.',
    );
  }

  // ── 3. Đóng gói ──────────────────────────────────────────────────────
  Future<void> _pack(OutboundOrderDetail order) async {
    if (!_canUpdate || !order.canPack || _busy) return;
    final result = await showModalBottomSheet<PackingResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PackingSheet(order: order),
    );
    if (result == null || !mounted || _busy) return;

    await _run(
      () => _repository.confirmPacking(
        order.id,
        qrCode: result.qrCode,
        actualWeightKg: result.actualWeightKg,
        scaleDevice: result.scaleDevice,
        items: [
          for (final item in result.items)
            PackingItemWeightPayload(
              outboundOrderItemId: item.outboundOrderItemId,
              actualWeightKg: item.actualWeightKg,
              fromScale: item.fromScale,
            ),
        ],
      ),
      successMessage: 'Đóng gói hoàn tất. Phiếu chuyển sang Chờ xuất kho.',
    );
  }

  // ── 4. Xác nhận xuất kho ─────────────────────────────────────────────
  Future<void> _dispatch(OutboundOrderDetail order) async {
    if (!_canUpdate || !order.canDispatch || _busy) return;
    setState(() => _busy = true);
    final receivable = await _computeExpectedReceivable(order);
    if (!mounted) return;
    setState(() => _busy = false);

    final result = await showModalBottomSheet<DispatchResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          DispatchSheet(order: order, expectedReceivable: receivable),
    );
    if (result == null || !mounted || _busy) return;

    await _run(
      () => _repository.confirmDispatch(
        order.id,
        dueDate: result.dueDate,
        note: result.note,
      ),
      successMessage: 'Đã xuất kho. Đơn bán chuyển sang Đang giao.',
    );
  }

  /// Giá trị phải thu dự kiến theo GIÁ BÁN (không dùng giá vốn) — copy đúng
  /// cách tính của web: đơn giá lấy từ đơn bán (lineAmount / quantityOrdered)
  /// nhân với số lượng đã lấy của từng dòng phiếu xuất.
  /// Trả -1 nếu không xác định được (vẫn hỏi hạn thanh toán cho an toàn).
  Future<double> _computeExpectedReceivable(OutboundOrderDetail order) async {
    try {
      final salesOrder =
          await _salesOrderRepository.getById(order.salesOrderId);
      final unitByItemId = <int, double>{
        for (final item in salesOrder.items)
          item.id: item.quantityOrdered > 0
              ? item.lineAmount / item.quantityOrdered
              : item.unitSalePrice,
      };
      var total = 0.0;
      for (final item in order.items) {
        final unit = item.salesOrderItemId == null
            ? 0.0
            : unitByItemId[item.salesOrderItemId] ?? 0.0;
        total += item.quantityPicked * unit;
      }
      return total;
    } catch (_) {
      return -1;
    }
  }

  // ── 5. Giao hàng thành công (giữ form mở khi backend trả 422) ────────
  Future<void> _completeDelivery(OutboundOrderDetail order) async {
    if (!_canUpdate || !order.canDeliver || _busy) return;
    setState(() => _busy = true);
    final debt = await _repository.getReceivableSnapshot(
      outboundOrderId: order.id,
      soCode: order.soCode,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    String? validationError;
    while (mounted) {
      if (!mounted) return;
      final result = await showModalBottomSheet<DeliveryResult>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        isDismissible: true,
        builder: (_) => CompleteDeliverySheet(
          order: order,
          debt: debt,
          externalError: validationError,
        ),
      );
      if (result == null || !mounted || _busy) return;

      setState(() => _busy = true);
      try {
        final outcome = await _repository.completeDelivery(
          order.id,
          receiverName: result.receiverName,
          paymentAmount: result.paymentAmount,
          deliveryNote: result.deliveryNote,
        );
        _changed = true;
        if (!mounted) return;
        setState(() => _busy = false);
        _snack(_deliveryMessage(outcome), success: true);
        await _load(showLoading: false);
        return;
      } on OutboundOrderException catch (error) {
        if (!mounted) return;
        setState(() => _busy = false);
        // 422 = số tiền không hợp lệ / vượt dư nợ → mở lại form kèm lỗi.
        if (error.isValidation) {
          validationError = error.message;
          continue;
        }
        _snack(error.message);
        return;
      } catch (error) {
        if (!mounted) return;
        setState(() => _busy = false);
        _snack('$error');
        return;
      }
    }
  }

  String _deliveryMessage(CompleteDeliveryResult result) {
    final remaining = result.remainingDebt;
    if (remaining == 0) return 'Khách hàng đã thanh toán đủ.';
    if (remaining != null && remaining > 0) {
      return 'Đã giao thành công. Còn nợ ${formatMoney(remaining)}.';
    }
    return 'Đã xác nhận giao hàng thành công.';
  }

  // ── 6. Giao thất bại ─────────────────────────────────────────────────
  Future<void> _failDelivery(OutboundOrderDetail order) async {
    if (!_canUpdate || !order.canDeliver || _busy) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const ReasonDialog(
        title: 'Giao hàng thất bại?',
        message: 'Tồn kho sẽ được hoàn nhập và công nợ (nếu có) được đảo lại.',
        confirmLabel: 'Ghi nhận thất bại',
        hint: 'VD: Khách không nhận hàng',
      ),
    );
    if (reason == null || !mounted || _busy) return;

    await _run(
      () => _repository.failDelivery(order.id, reason: reason),
      successMessage: 'Đã ghi nhận giao hàng thất bại và hoàn tồn.',
    );
  }

  // ── 7. Hủy phiếu (bắt buộc nhập lý do) ───────────────────────────────
  Future<void> _cancel(OutboundOrderDetail order) async {
    if (!_canUpdate || !order.canCancel || _busy) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => ReasonDialog(
        title: 'Hủy phiếu xuất?',
        message:
            'Phiếu ${order.soCode} sẽ bị hủy và phần tồn đã giữ được giải phóng.',
        confirmLabel: 'Hủy phiếu',
        hint: 'VD: Khách đổi lịch giao',
        maxLength: 500,
      ),
    );
    if (reason == null || !mounted || _busy) return;

    await _run(
      () => _repository.cancel(order.id, reason: reason),
      successMessage: 'Đã hủy phiếu xuất.',
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
              overline: order == null ? null : 'Đơn bán ${order.soCode}',
              title:
                  order == null ? 'Chi tiết phiếu xuất' : 'Phiếu #${order.id}',
              subtitle: order?.customerName ?? 'Đang tải dữ liệu…',
              leading: IconButton(
                onPressed:
                    _busy ? null : () => Navigator.of(context).pop(_changed),
                color: Colors.white,
                icon: const Icon(Icons.arrow_back),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cân chỉ liên quan khi phiếu đang ở bước lấy hàng/đóng bao.
                  // Khi phiếu đã hoàn tất (hoặc ở trạng thái khác), màn hình chỉ
                  // hiển thị số liệu đã ghi nhận, không gợi ý kết nối cân nữa.
                  if (order?.canPack == true)
                    const KeyedSubtree(
                      key: Key('outbound_scale_status'),
                      child: ScaleStatusChip(),
                    ),
                  IconButton(
                    onPressed: _busy ? null : () => _load(),
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
          _summaryCard(order),
          const SizedBox(height: 12),
          for (final item in order.items) _itemCard(item),
        ],
      ),
    );
  }

  Widget _statusCard(OutboundOrderDetail order) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppStatusChip(
                label: order.statusLabel,
                tone: outboundTone(order.statusId),
              ),
              const Spacer(),
              Text(
                order.warehouseName.isEmpty ? '—' : order.warehouseName,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryFor(context),
                ),
              ),
            ],
          ),
          if (order.cancelReasonText != null) ...[
            const SizedBox(height: 12),
            AppInfoBanner(
              message: 'Lý do hủy: ${order.cancelReasonText}',
              tone: AppTone.danger,
              icon: Icons.cancel_outlined,
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Tiến trình xử lý',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondaryFor(context),
            ),
          ),
          const SizedBox(height: 10),
          KeyedSubtree(
            key: const Key('outbound_progress_steps'),
            child: _pipeline(order),
          ),
        ],
      ),
    );
  }

  Widget _pipeline(OutboundOrderDetail order) {
    final active = order.activeStep;
    return Row(
      children: [
        for (var index = 0; index < _pipelineSteps.length; index++)
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active < 0
                        ? AppColors.dangerTint
                        : index <= active
                            ? AppColors.primary
                            : AppColors.borderFor(context),
                  ),
                  child: Icon(
                    active < 0
                        ? Icons.close_rounded
                        : index < active
                            ? Icons.check_rounded
                            : Icons.circle,
                    size: active < 0 || index < active ? 15 : 8,
                    color: active < 0
                        ? AppColors.danger
                        : index <= active
                            ? Colors.white
                            : AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _pipelineSteps[index],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    color: index <= active && active >= 0
                        ? AppColors.textPrimaryFor(context)
                        : AppColors.textSecondaryFor(context),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _summaryCard(OutboundOrderDetail order) {
    final diff = order.weightDiffKg;
    final isCompleted = order.statusId == OutboundStatusIds.completed;
    final isWeighingStage = order.canPack;
    return AppCard(
      key: const Key('outbound_summary_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            key: const Key('outbound_summary_title'),
            title: isWeighingStage
                ? 'Cân & đóng bao'
                : isCompleted
                    ? 'Kết quả xuất kho'
                    : 'Thông tin xuất kho',
            icon: isWeighingStage
                ? Icons.scale_outlined
                : isCompleted
                    ? Icons.fact_check_outlined
                    : Icons.inventory_2_outlined,
          ),
          Row(
            children: [
              Expanded(
                child: AppStatTile(
                  label: 'Kế hoạch',
                  value: formatKg(order.plannedKg),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppStatTile(
                  label: isCompleted ? 'Đã xuất' : 'Thực lấy',
                  value: formatKg(order.pickedKg),
                  tone: AppTone.info,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppStatTile(
                  label: 'Chênh lệch',
                  value: '${diff >= 0 ? '+' : ''}${formatKg(diff)}',
                  tone: diff.abs() < 0.001 ? AppTone.brand : AppTone.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Line('Giá trị xuất (giá bán)',
              formatMoney(order.totalDispatchedSaleValue)),
          _Line('Giá trị xuất (giá vốn)',
              formatMoney(order.totalDispatchedValue)),
          _Line('Ngày tạo', formatDate(order.createdDate, withTime: true)),
          if (order.completedDate != null)
            _Line('Hoàn tất', formatDate(order.completedDate, withTime: true)),
          if (order.note?.isNotEmpty == true) _Line('Ghi chú', order.note!),
        ],
      ),
    );
  }

  Widget _itemCard(OutboundOrderItem item) {
    final secondary = AppColors.textSecondaryFor(context);
    final groups = item.groups;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.productVariantName,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          Text(
            '${item.sku ?? '—'} • Đặt ${formatKg(item.quantityOrdered)}'
            ' • Đã lấy ${formatKg(item.quantityPicked)}',
            style: TextStyle(fontSize: 12, color: secondary),
          ),
          const SizedBox(height: 10),
          if (groups.isEmpty)
            Text(
              'Chưa phân bổ lô cho dòng này.',
              style: TextStyle(fontSize: 12.5, color: secondary),
            )
          else
            for (final group in groups)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lô ${group.lotLabel} • ${group.locationLabel}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${group.bagCount} bao × ${formatKg(group.weightPerBagKg)}',
                            style: TextStyle(fontSize: 11.5, color: secondary),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatKg(group.totalAllocatedKg),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'lấy ${formatKg(group.totalPickedKg)}',
                          style: TextStyle(fontSize: 11, color: secondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget? _actionBar(OutboundOrderDetail order) {
    if (!_canUpdate) return null;

    final buttons = <Widget>[];

    if (order.canAllocate) {
      buttons.add(FilledButton.icon(
        key: const Key('outbound_allocate'),
        onPressed: _busy ? null : () => _allocate(order),
        icon: const Icon(Icons.splitscreen_rounded),
        label: const Text('Phân bổ lô'),
      ));
    }
    if (order.canPick) {
      buttons.add(FilledButton.icon(
        key: const Key('outbound_pick'),
        onPressed: _busy ? null : () => _pick(order),
        icon: const Icon(Icons.shopping_basket_outlined),
        label: const Text('Lấy hàng'),
      ));
    }
    if (order.canPack) {
      buttons.add(OutlinedButton.icon(
        key: const Key('outbound_pack'),
        onPressed: _busy ? null : () => _pack(order),
        icon: const Icon(Icons.inventory_rounded),
        label: const Text('Đóng gói'),
      ));
    }
    if (order.canDispatch) {
      buttons.add(FilledButton.icon(
        key: const Key('outbound_dispatch'),
        onPressed: _busy ? null : () => _dispatch(order),
        icon: const Icon(Icons.local_shipping_rounded),
        label: const Text('Xuất kho'),
      ));
    }
    if (order.canDeliver) {
      buttons.add(FilledButton.icon(
        key: const Key('outbound_complete_delivery'),
        onPressed: _busy ? null : () => _completeDelivery(order),
        icon: const Icon(Icons.check_circle_outline_rounded),
        label: const Text('Đã giao'),
      ));
      buttons.add(OutlinedButton.icon(
        key: const Key('outbound_fail_delivery'),
        onPressed: _busy ? null : () => _failDelivery(order),
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
        icon: const Icon(Icons.report_gmailerrorred_rounded),
        label: const Text('Giao lỗi'),
      ));
    }
    if (order.canCancel) {
      buttons.add(OutlinedButton.icon(
        key: const Key('outbound_cancel'),
        onPressed: _busy ? null : () => _cancel(order),
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
        icon: const Icon(Icons.cancel_outlined),
        label: const Text('Hủy phiếu'),
      ));
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

/// Dòng nhãn – giá trị trong card chi tiết.
class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

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
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

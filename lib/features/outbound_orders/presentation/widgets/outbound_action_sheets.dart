import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../scale/models/weight_reading.dart';
import '../../../scale/presentation/screens/scale_screen.dart';
import '../../data/outbound_order_repository.dart';
import '../../models/outbound_order.dart';

// ══════════════════════════════════════════════════════════════════════
// 1. PHÂN BỔ LÔ (allocate) — DRAFT → PICKING
// ══════════════════════════════════════════════════════════════════════

/// Bảng phân bổ lô/vị trí cho từng dòng phiếu xuất.
///
/// Kiểm tra khớp web: tổng phân bổ của một dòng không vượt số lượng đặt (đã trừ
/// phần đã phân bổ trước đó), và mỗi lô không vượt `selectableQuantity`.
class AllocateSheet extends StatefulWidget {
  const AllocateSheet({
    required this.order,
    required this.candidates,
    super.key,
  });

  final OutboundOrderDetail order;
  final List<OutboundAllocationCandidate> candidates;

  @override
  State<AllocateSheet> createState() => _AllocateSheetState();
}

class _AllocateSheetState extends State<AllocateSheet> {
  /// Key: "itemId:inventoryId" → ô nhập số lượng.
  final Map<String, TextEditingController> _controllers = {};
  String? _error;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(int itemId, int inventoryId) =>
      _controllers.putIfAbsent(
        '$itemId:$inventoryId',
        TextEditingController.new,
      );

  List<OutboundAllocationCandidate> _lotsFor(OutboundOrderItem item) =>
      widget.candidates
          .where((candidate) =>
              candidate.productVariantId == item.productVariantId &&
              candidate.selectableQuantity > 0)
          .toList();

  double _enteredTotal(OutboundOrderItem item) {
    var total = 0.0;
    for (final lot in _lotsFor(item)) {
      total += parseDecimal(_controllerFor(item.id, lot.inventoryId).text) ?? 0;
    }
    return total;
  }

  double _remaining(OutboundOrderItem item) =>
      item.quantityOrdered - item.allocatedKg - _enteredTotal(item);

  void _submit() {
    final payload = <AllocateItemPayload>[];

    for (final item in widget.order.items) {
      final lots = <AllocateLotPayload>[];
      for (final candidate in _lotsFor(item)) {
        final raw = _controllerFor(item.id, candidate.inventoryId).text.trim();
        if (raw.isEmpty) continue;

        final quantity = parseDecimal(raw);
        if (quantity == null || quantity < 0) {
          setState(() => _error =
              'Số lượng phân bổ của lô ${candidate.lotLabel} không hợp lệ.');
          return;
        }
        if (quantity == 0) continue;
        if (quantity > candidate.selectableQuantity + 0.001) {
          setState(() => _error =
              'Lô ${candidate.lotLabel} chỉ còn ${formatKg(candidate.selectableQuantity)} khả dụng.');
          return;
        }
        lots.add(AllocateLotPayload(
          inventoryId: candidate.inventoryId,
          quantityAllocated: quantity,
        ));
      }

      if (_remaining(item) < -0.001) {
        setState(() => _error =
            'Sản phẩm "${item.productVariantName}" bị phân bổ vượt số lượng đặt.');
        return;
      }
      if (lots.isNotEmpty) {
        payload.add(AllocateItemPayload(
          outboundOrderItemId: item.id,
          lots: lots,
        ));
      }
    }

    if (payload.isEmpty) {
      setState(() => _error = 'Nhập số lượng phân bổ cho ít nhất một lô.');
      return;
    }
    Navigator.of(context).pop(payload);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'Phân bổ lô hàng',
      subtitle:
          'Chọn lô và vị trí lấy hàng cho từng sản phẩm. Sau bước này phiếu chuyển sang "Đang lấy hàng".',
      error: _error,
      confirmLabel: 'Phân bổ',
      confirmIcon: Icons.playlist_add_check_rounded,
      onConfirm: _submit,
      children: [
        for (final item in widget.order.items) _itemBlock(item),
      ],
    );
  }

  Widget _itemBlock(OutboundOrderItem item) {
    final lots = _lotsFor(item);
    final secondary = AppColors.textSecondaryFor(context);
    final remaining = _remaining(item);

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
            '${item.sku ?? '—'} • Cần ${formatKg(item.quantityOrdered)}'
            '${item.allocatedKg > 0 ? ' • Đã phân bổ ${formatKg(item.allocatedKg)}' : ''}',
            style: TextStyle(fontSize: 12, color: secondary),
          ),
          const SizedBox(height: 4),
          Text(
            remaining >= 0
                ? 'Còn cần phân bổ ${formatKg(remaining)}'
                : 'Vượt ${formatKg(remaining.abs())}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: remaining < -0.001 ? AppColors.danger : AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          if (lots.isEmpty)
            Text(
              'Không còn lô khả dụng cho sản phẩm này.',
              style: TextStyle(fontSize: 12.5, color: secondary),
            )
          else
            for (final lot in lots) _lotRow(item, lot, secondary),
        ],
      ),
    );
  }

  Widget _lotRow(
    OutboundOrderItem item,
    OutboundAllocationCandidate lot,
    Color secondary,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lot.lotLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Vị trí ${lot.locationLabel} • còn ${formatKg(lot.selectableQuantity)}',
                  style: TextStyle(fontSize: 11.5, color: secondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _controllerFor(item.id, lot.inventoryId),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'kg',
                isDense: true,
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// 2. LẤY HÀNG (pick)
// ══════════════════════════════════════════════════════════════════════

/// Nhập số lượng thực lấy theo từng nhóm bao (lô + vị trí + khối lượng bao).
///
/// Số kg nhập được rải ngược về từng allocation trong nhóm — đúng cách web làm,
/// vì backend nhận `picks` theo `allocationId`.
class PickSheet extends StatefulWidget {
  const PickSheet({required this.order, super.key});

  final OutboundOrderDetail order;

  @override
  State<PickSheet> createState() => _PickSheetState();
}

class _PickSheetState extends State<PickSheet> {
  late final List<_PickRow> _rows;
  String? _error;

  @override
  void initState() {
    super.initState();
    _rows = [
      for (final item in widget.order.items)
        for (final group in item.groups)
          _PickRow(
            item: item,
            group: group,
            controller: TextEditingController(
              // Mặc định lấy đủ như đã phân bổ (giống web).
              text: formatQuantityInput(
                group.totalPickedKg > 0
                    ? group.totalPickedKg
                    : group.totalAllocatedKg,
              ),
            ),
          ),
    ];
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final allocationById = <int, OutboundAllocation>{
      for (final item in widget.order.items)
        for (final allocation in item.allocations) allocation.id: allocation,
    };

    final picks = <PickAllocationPayload>[];
    for (final row in _rows) {
      final picked = parseDecimal(row.controller.text) ?? 0;
      if (picked < 0 || picked > row.group.totalAllocatedKg + 0.001) {
        setState(() => _error =
            'Số lượng lấy của lô ${row.group.lotLabel} phải trong khoảng 0 – ${formatKg(row.group.totalAllocatedKg)}.');
        return;
      }
      // Rải số kg thực lấy lần lượt cho từng bao trong nhóm.
      var remaining = picked;
      for (final allocationId in row.group.allocationIds) {
        final allocated =
            allocationById[allocationId]?.quantityAllocated ?? 0;
        final quantity = remaining < allocated ? remaining : allocated;
        remaining = remaining - quantity;
        if (remaining < 0) remaining = 0;
        picks.add(PickAllocationPayload(
          allocationId: allocationId,
          quantityPicked: quantity,
        ));
      }
    }

    if (picks.isEmpty) {
      setState(() => _error = 'Phiếu chưa có phân bổ lô để lấy hàng.');
      return;
    }
    Navigator.of(context).pop(picks);
  }

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondaryFor(context);
    return _SheetShell(
      title: 'Cập nhật lấy hàng',
      subtitle: 'Nhập khối lượng thực tế đã lấy khỏi từng lô.',
      error: _error,
      confirmLabel: 'Lưu số lượng lấy',
      confirmIcon: Icons.save_rounded,
      onConfirm: _submit,
      children: [
        if (_rows.isEmpty)
          Text(
            'Phiếu chưa có phân bổ lô. Hãy phân bổ trước khi lấy hàng.',
            style: TextStyle(color: secondary),
          )
        else
          for (final row in _rows)
            AppCard(
              margin: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.item.productVariantName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Lô ${row.group.lotLabel} • ${row.group.locationLabel}',
                          style: TextStyle(fontSize: 11.5, color: secondary),
                        ),
                        Text(
                          '${row.group.bagCount} bao × ${formatKg(row.group.weightPerBagKg)}'
                          ' = ${formatKg(row.group.totalAllocatedKg)}',
                          style: TextStyle(fontSize: 11.5, color: secondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: row.controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Thực lấy (kg)',
                        isDense: true,
                      ),
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _PickRow {
  _PickRow({
    required this.item,
    required this.group,
    required this.controller,
  });

  final OutboundOrderItem item;
  final OutboundAllocationGroup group;
  final TextEditingController controller;
}

// ══════════════════════════════════════════════════════════════════════
// 3. ĐÓNG GÓI (confirm-packing) — PICKING → PACKED
// ══════════════════════════════════════════════════════════════════════

class PackingResult {
  const PackingResult({
    required this.qrCode,
    this.actualWeightKg,
    this.scaleDevice,
  });

  final String qrCode;
  final double? actualWeightKg;
  final String? scaleDevice;
}

class PackingSheet extends StatefulWidget {
  const PackingSheet({required this.order, super.key});

  final OutboundOrderDetail order;

  @override
  State<PackingSheet> createState() => _PackingSheetState();
}

class _PackingSheetState extends State<PackingSheet> {
  late final TextEditingController _qrController;
  late final TextEditingController _weightController;
  final _scaleController = TextEditingController();
  String? _error;

  /// Số cân đọc được từ cân điện tử (null = đang nhập tay).
  WeightReading? _reading;

  @override
  void initState() {
    super.initState();
    final suffix =
        DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    _qrController =
        TextEditingController(text: 'PACK-${widget.order.id}-$suffix');
    final weight = widget.order.pickedKg > 0
        ? widget.order.pickedKg
        : widget.order.plannedKg;
    _weightController =
        TextEditingController(text: formatQuantityInput(weight));
  }

  @override
  void dispose() {
    _qrController.dispose();
    _weightController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  /// Mở màn cân BLE và điền số cân ổn định vào ô khối lượng.
  Future<void> _readFromScale() async {
    final reading = await Navigator.of(context).push<WeightReading>(
      MaterialPageRoute<WeightReading>(builder: (_) => const ScaleScreen()),
    );
    if (reading == null || !mounted) return;

    setState(() {
      _reading = reading;
      _error = null;
      _weightController.text = formatQuantityInput(reading.weight);
      final device = reading.deviceName?.trim();
      _scaleController.text =
          device == null || device.isEmpty ? 'Cân BLE StockLite' : device;
    });
  }

  void _clearReading() {
    setState(() => _reading = null);
  }

  void _submit() {
    final qr = _qrController.text.trim();
    if (qr.isEmpty) {
      setState(() => _error = 'Mã QR đóng gói không được để trống.');
      return;
    }
    final weightText = _weightController.text.trim();
    final weight = weightText.isEmpty ? null : parseDecimal(weightText);
    if (weightText.isNotEmpty && (weight == null || weight < 0)) {
      setState(() => _error = 'Khối lượng thực tế không hợp lệ.');
      return;
    }
    Navigator.of(context).pop(PackingResult(
      qrCode: qr,
      actualWeightKg: weight,
      scaleDevice: _scaleController.text.trim().isEmpty
          ? null
          : _scaleController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final diff = widget.order.weightDiffKg;
    return _SheetShell(
      title: 'Xác nhận đóng gói',
      subtitle:
          'Sau khi đóng gói xong, phiếu chuyển sang "Chờ xuất kho". Backend kiểm tra tất cả dòng đã lấy đủ.',
      error: _error,
      confirmLabel: 'Đóng gói xong',
      confirmIcon: Icons.inventory_rounded,
      onConfirm: _submit,
      children: [
        AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              _KeyValue('Kế hoạch', formatKg(widget.order.plannedKg)),
              _KeyValue('Thực lấy', formatKg(widget.order.pickedKg)),
              _KeyValue(
                'Chênh lệch',
                '${diff >= 0 ? '+' : ''}${formatKg(diff)}',
                strong: true,
              ),
            ],
          ),
        ),
        TextField(
          controller: _qrController,
          decoration: const InputDecoration(labelText: 'Mã QR đóng gói *'),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Khối lượng thực tế (kg)',
            helperText: 'Lấy từ cân điện tử hoặc nhập tay',
          ),
          // Sửa tay sau khi đã đọc cân → không còn là số cân từ thiết bị nữa.
          onChanged: (_) {
            if (_reading != null) _clearReading();
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 10),
        _scaleBlock(),
        const SizedBox(height: 12),
        TextField(
          controller: _scaleController,
          decoration: const InputDecoration(
            labelText: 'Thiết bị cân · tùy chọn',
          ),
        ),
      ],
    );
  }

  /// Nút đọc cân điện tử + thẻ tóm tắt số cân vừa nhận được.
  Widget _scaleBlock() {
    final reading = _reading;
    if (reading == null) {
      return OutlinedButton.icon(
        onPressed: _readFromScale,
        icon: const Icon(Icons.bluetooth_searching_rounded),
        label: const Text('Lấy số cân từ cân điện tử'),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.scale_rounded, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatNumber(reading.weight, digits: 3)} ${reading.unit}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${reading.deviceName?.trim().isNotEmpty == true ? reading.deviceName!.trim() : 'Cân BLE StockLite'}'
                  ' • lúc ${formatDate(reading.receivedAt, withTime: true)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondaryFor(context),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _readFromScale,
            child: const Text('Cân lại'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// 4. XÁC NHẬN XUẤT KHO (confirm-dispatch) — PACKED → DISPATCHED
// ══════════════════════════════════════════════════════════════════════

class DispatchResult {
  const DispatchResult({this.dueDate, this.note});

  final DateTime? dueDate;
  final String? note;
}

/// Popup xác nhận xuất kho.
///
/// Khi phiếu phát sinh công nợ phải thu ([expectedReceivable] != 0) thì hạn
/// thanh toán là bắt buộc và không được trước hôm nay — đúng như web.
/// [expectedReceivable] < 0 nghĩa là "chưa xác định được", vẫn hỏi hạn cho an toàn.
class DispatchSheet extends StatefulWidget {
  const DispatchSheet({
    required this.order,
    required this.expectedReceivable,
    super.key,
  });

  final OutboundOrderDetail order;
  final double expectedReceivable;

  @override
  State<DispatchSheet> createState() => _DispatchSheetState();
}

class _DispatchSheetState extends State<DispatchSheet> {
  final _noteController = TextEditingController();
  late DateTime _dueDate;
  String? _error;

  bool get _hasReceivable => widget.expectedReceivable != 0;
  bool get _known => widget.expectedReceivable > 0;

  @override
  void initState() {
    super.initState();
    _dueDate = DateTime.now();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate.isBefore(today) ? today : _dueDate,
      firstDate: today,
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null && mounted) setState(() => _dueDate = picked);
  }

  void _submit() {
    if (_hasReceivable) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final due = DateTime(_dueDate.year, _dueDate.month, _dueDate.day);
      if (due.isBefore(today)) {
        setState(() => _error = 'Hạn thanh toán không được trước hôm nay.');
        return;
      }
    }
    Navigator.of(context).pop(DispatchResult(
      dueDate: _hasReceivable ? _dueDate : null,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'Xác nhận xuất kho',
      subtitle:
          'Phiếu ${widget.order.soCode} sẽ trừ tồn thực tế, ghi giao dịch kho và chuyển đơn bán sang "Đang giao".',
      error: _error,
      confirmLabel: 'Xác nhận xuất kho',
      confirmIcon: Icons.local_shipping_rounded,
      onConfirm: _submit,
      children: [
        if (_hasReceivable) ...[
          AppInfoBanner(
            message: _known
                ? 'Phiếu phát sinh công nợ phải thu ${formatMoney(widget.expectedReceivable)}.'
                : 'Nếu phiếu phát sinh công nợ phải thu, vui lòng chọn hạn thanh toán.',
            tone: _known ? AppTone.info : AppTone.warning,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDueDate,
            icon: const Icon(Icons.event_rounded),
            label: Text('Hạn thanh toán: ${formatDate(_dueDate)}'),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _noteController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Ghi chú xuất kho',
            hintText: 'Không bắt buộc…',
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// 5. GIAO HÀNG THÀNH CÔNG (complete-delivery)
// ══════════════════════════════════════════════════════════════════════

class DeliveryResult {
  const DeliveryResult({
    required this.receiverName,
    required this.paymentAmount,
    this.deliveryNote,
  });

  final String receiverName;
  final double paymentAmount;
  final String? deliveryNote;
}

/// Popup xác nhận đã giao hàng và thu tiền.
///
/// Hiển thị số dư công nợ lấy từ API ([debt]) kèm hai nút nhanh "Không thanh
/// toán" / "Thanh toán toàn bộ" — giống web. Lỗi 422 do backend trả về được
/// hiển thị tại chỗ ([externalError]) để người dùng sửa số tiền mà không mất form.
class CompleteDeliverySheet extends StatefulWidget {
  const CompleteDeliverySheet({
    required this.order,
    required this.debt,
    this.externalError,
    super.key,
  });

  final OutboundOrderDetail order;
  final OutboundDebtSnapshot? debt;
  final String? externalError;

  @override
  State<CompleteDeliverySheet> createState() => _CompleteDeliverySheetState();
}

class _CompleteDeliverySheetState extends State<CompleteDeliverySheet> {
  final _receiverController = TextEditingController();
  final _paymentController = TextEditingController(text: '0');
  final _noteController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.externalError;
  }

  @override
  void dispose() {
    _receiverController.dispose();
    _paymentController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _setPayment(num value) {
    _paymentController.text = formatNumber(value, digits: 0);
    setState(() => _error = null);
  }

  void _submit() {
    final receiver = _receiverController.text.trim();
    if (receiver.isEmpty) {
      setState(() => _error = 'Vui lòng nhập tên người nhận.');
      return;
    }
    final amount = parseMoney(_paymentController.text).toDouble();
    if (amount < 0) {
      setState(() => _error = 'Số tiền khách thanh toán thêm không được âm.');
      return;
    }
    Navigator.of(context).pop(DeliveryResult(
      receiverName: receiver,
      paymentAmount: amount,
      deliveryNote: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final debt = widget.debt;
    final outstanding = debt?.outstandingAmount;

    return _SheetShell(
      title: 'Xác nhận đã giao hàng',
      subtitle: 'Phiếu ${widget.order.soCode} • ${widget.order.customerName}',
      error: _error,
      confirmLabel: 'Đã giao thành công',
      confirmIcon: Icons.check_circle_outline_rounded,
      onConfirm: _submit,
      children: [
        TextField(
          controller: _receiverController,
          decoration: const InputDecoration(
            labelText: 'Tên người nhận *',
            hintText: 'VD: Nguyễn Văn A',
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 14),
        if (debt != null)
          AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                _KeyValue('Tổng tiền phiếu', formatMoney(debt.totalAmount)),
                _KeyValue('Đã thanh toán/cọc', formatMoney(debt.paidAmount)),
                _KeyValue(
                  'Còn phải thu',
                  formatMoney(debt.outstandingAmount),
                  strong: true,
                  valueColor: AppColors.danger,
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Chưa lấy được số dư công nợ của phiếu. Bạn vẫn có thể nhập số tiền; hệ thống sẽ kiểm tra khi lưu.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondaryFor(context),
              ),
            ),
          ),
        TextField(
          controller: _paymentController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Số tiền khách thanh toán thêm (VNĐ)',
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => _setPayment(0),
              child: const Text('Không thanh toán'),
            ),
            if (outstanding != null && outstanding > 0)
              FilledButton.tonal(
                onPressed: () => _setPayment(outstanding),
                child: const Text('Thanh toán toàn bộ'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _noteController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Ghi chú giao hàng',
            hintText: 'Không bắt buộc…',
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// 6. NHẬP LÝ DO (giao thất bại / hủy phiếu)
// ══════════════════════════════════════════════════════════════════════

/// Hộp thoại nhập lý do bắt buộc — dùng cho "giao thất bại" và "hủy phiếu".
class ReasonDialog extends StatefulWidget {
  const ReasonDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.hint,
    this.maxLength = 1000,
    super.key,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String? hint;

  /// Giới hạn ký tự — khớp ràng buộc của backend (lý do hủy 500, lý do giao
  /// thất bại 1000).
  final int maxLength;

  @override
  State<ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<ReasonDialog> {
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
      setState(() => _error = 'Vui lòng nhập lý do.');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message,
            style: TextStyle(color: AppColors.textSecondaryFor(context)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            maxLines: 3,
            maxLength: widget.maxLength,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Lý do *',
              hintText: widget.hint,
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
          child: const Text('Quay lại'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// Khung chung cho các bottom sheet thao tác
// ══════════════════════════════════════════════════════════════════════

class _SheetShell extends StatelessWidget {
  const _SheetShell({
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.confirmIcon,
    required this.onConfirm,
    required this.children,
    this.error,
  });

  final String title;
  final String subtitle;
  final String confirmLabel;
  final IconData confirmIcon;
  final VoidCallback onConfirm;
  final List<Widget> children;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSectionHeader(title: title, icon: confirmIcon),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: AppColors.textSecondaryFor(context),
                ),
              ),
              const SizedBox(height: 16),
              ...children,
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Quay lại'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onConfirm,
                      icon: Icon(confirmIcon),
                      label: Text(confirmLabel),
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

class _KeyValue extends StatelessWidget {
  const _KeyValue(
    this.label,
    this.value, {
    this.strong = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool strong;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
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
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

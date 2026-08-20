import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../scale/models/weight_reading.dart';
import '../../../scale/presentation/widgets/scale_bar.dart';
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

/// Khối lượng đóng gói thực tế của một dòng phiếu xuất, kèm nguồn số liệu.
class PackingItemWeight {
  const PackingItemWeight({
    required this.outboundOrderItemId,
    required this.actualWeightKg,
    required this.fromScale,
  });

  final int outboundOrderItemId;
  final double actualWeightKg;

  /// true = số đến từ cân điện tử, false = thủ kho gõ tay.
  final bool fromScale;

  String get source => fromScale ? 'SCALE' : 'MANUAL';
}

class PackingResult {
  const PackingResult({
    required this.qrCode,
    this.actualWeightKg,
    this.scaleDevice,
    this.items = const [],
  });

  final String qrCode;

  /// Tổng khối lượng thực tế (= tổng các dòng). Giữ lại để tương thích ngược.
  final double? actualWeightKg;

  /// Tên cân đã dùng — CHỈ khác null khi thực sự có ít nhất một số từ cân.
  final String? scaleDevice;

  /// Khối lượng theo từng dòng phiếu xuất.
  final List<PackingItemWeight> items;
}

/// Popup xác nhận đóng gói.
///
/// Thiết kế cân: cân là nguồn nhập chạy nền, KHÔNG phải một màn hình riêng.
/// [ScaleBar] nằm dính phía trên danh sách; số ổn định chảy thẳng vào dòng lô
/// đang được chọn. Mỗi lần nhận số = thêm MỘT BAO vào dòng đó, nên cân nhiều
/// bao chỉ việc đặt lên — nhấc ra — đặt bao kế tiếp, không chạm màn hình.
///
/// Nhập tay luôn dùng được: gõ vào ô kg của dòng nào thì dòng đó tự chuyển
/// nguồn sang "nhập tay" và bỏ danh sách bao đã cân của riêng nó.
class PackingSheet extends StatefulWidget {
  const PackingSheet({required this.order, super.key});

  final OutboundOrderDetail order;

  @override
  State<PackingSheet> createState() => _PackingSheetState();
}

class _PackingSheetState extends State<PackingSheet> {
  final _scaleBarKey = GlobalKey<ScaleBarState>();
  late final TextEditingController _qrController;
  late final List<_PackRow> _rows;

  int _targetIndex = 0;
  String? _scaleDevice;
  String? _error;

  @override
  void initState() {
    super.initState();
    final suffix =
        DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    _qrController =
        TextEditingController(text: 'PACK-${widget.order.id}-$suffix');

    _rows = [
      for (final item in widget.order.items)
        for (final group in item.groups)
          _PackRow(
            item: item,
            group: group,
            // Gợi ý sẵn số đã lấy để thủ kho chỉ phải sửa khi lệch.
            controller: TextEditingController(
              text: formatQuantityInput(
                ceilKg(
                  group.totalPickedKg > 0
                      ? group.totalPickedKg
                      : group.totalAllocatedKg,
                ),
                digits: 1,
              ),
            ),
          ),
    ];
    for (final row in _rows) {
      row.controller.addListener(() => _onManualEdit(row));
    }
  }

  @override
  void dispose() {
    _qrController.dispose();
    for (final row in _rows) {
      row.controller.dispose();
    }
    super.dispose();
  }

  _PackRow? get _target => _targetIndex >= 0 && _targetIndex < _rows.length
      ? _rows[_targetIndex]
      : null;

  /// Tổng = tổng các dòng ĐÃ làm tròn lên 0,1 kg, khớp đúng số sẽ gửi lên BE.
  double get _total => _rows.fold(
        0.0,
        (sum, row) => sum + ceilKg(parseDecimal(row.controller.text) ?? 0),
      );

  bool get _anyFromScale => _rows.any((row) => row.fromScale);

  // ── Nhập tay ───────────────────────────────────────────────────────
  /// Người dùng sửa tay ô kg → dòng đó không còn là số từ cân nữa.
  void _onManualEdit(_PackRow row) {
    if (row.suppressListener) return;
    // TextEditingController báo cả khi con trỏ di chuyển. Chỉ coi là "sửa tay"
    // khi NỘI DUNG đổi — nếu không, chạm vào ô sẽ xoá oan các bao đã cân.
    if (row.controller.text == row.lastText) return;
    row.lastText = row.controller.text;

    // Luôn setState: tổng ở cuối form phải chạy theo từng phím gõ.
    setState(() {
      row.fromScale = false;
      row.bags.clear();
      _error = null;
      if (!_anyFromScale) _scaleDevice = null;
    });
  }

  // ── Nhận số từ cân ─────────────────────────────────────────────────
  void _onScaleCapture(WeightReading reading, bool automatic) {
    final row = _target;
    if (row == null) return;

    setState(() {
      row.bags.add(reading.weight);
      row.fromScale = true;
      row.writeSum();
      _scaleDevice = reading.deviceName?.trim().isNotEmpty == true
          ? reading.deviceName!.trim()
          : 'Cân BLE StockLite';
      _error = null;
    });

    if (!automatic) return;
    // Auto-capture thì phải có đường lùi: một chạm là bỏ bao vừa nhận.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Text(
            'Đã nhận ${formatNumber(reading.weight, digits: 1)} kg '
            '→ lô ${row.group.lotLabel} (bao ${row.bags.length})',
          ),
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () => _removeBag(row, row.bags.length - 1),
          ),
        ),
      );
  }

  void _removeBag(_PackRow row, int index) {
    if (index < 0 || index >= row.bags.length) return;
    setState(() {
      row.bags.removeAt(index);
      if (row.bags.isEmpty) row.fromScale = false;
      row.writeSum();
      if (!_anyFromScale) _scaleDevice = null;
    });
    // Bao vừa nhận vẫn đang nằm trên cân — đừng nhận lại nó ngay lập tức.
    _scaleBarKey.currentState?.suppressCurrentReading();
  }

  void _clearRow(_PackRow row) {
    setState(() {
      row.bags.clear();
      row.fromScale = false;
      row.write('');
      if (!_anyFromScale) _scaleDevice = null;
    });
    _scaleBarKey.currentState?.suppressCurrentReading();
  }

  // ── Gửi ────────────────────────────────────────────────────────────
  void _submit() {
    final qr = _qrController.text.trim();
    if (qr.isEmpty) {
      setState(() => _error = 'Mã QR đóng gói không được để trống.');
      return;
    }

    // Gộp các dòng lô về từng OutboundOrderItem — backend lưu theo item.
    final byItem = <int, double>{};
    final scaleByItem = <int, bool>{};
    for (final row in _rows) {
      final raw = row.controller.text.trim();
      if (raw.isEmpty) continue;
      final value = parseDecimal(raw);
      if (value == null || value < 0) {
        setState(() =>
            _error = 'Khối lượng của lô ${row.group.lotLabel} không hợp lệ.');
        return;
      }
      // Làm tròn lên 0,1 kg kể cả dòng gõ tay, để mọi số kg trên chứng từ theo
      // cùng một quy tắc với số đọc từ cân.
      final rounded = ceilKg(value);
      row.write(formatQuantityInput(rounded, digits: 1));
      byItem[row.item.id] = (byItem[row.item.id] ?? 0) + rounded;
      scaleByItem[row.item.id] =
          (scaleByItem[row.item.id] ?? false) || row.fromScale;
    }

    final items = [
      for (final entry in byItem.entries)
        PackingItemWeight(
          outboundOrderItemId: entry.key,
          // Cộng dồn số thực sinh đuôi lẻ → chuẩn hoá lại về bội của 0,1.
          actualWeightKg: ceilKg(entry.value),
          fromScale: scaleByItem[entry.key] ?? false,
        ),
    ];
    final total = ceilKg(_total);

    Navigator.of(context).pop(PackingResult(
      qrCode: qr,
      actualWeightKg: total > 0 ? total : null,
      // Chỉ khai báo thiết bị cân khi thật sự có số đến từ cân.
      scaleDevice: _anyFromScale ? _scaleDevice : null,
      items: items,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondaryFor(context);
    final total = _total;
    final planned = widget.order.plannedKg;
    final diff = total - planned;

    return _SheetShell(
      title: 'Xác nhận đóng gói',
      subtitle:
          'Cân từng lô rồi xác nhận. Phiếu chuyển sang "Chờ xuất kho"; backend kiểm tra tất cả dòng đã lấy đủ.',
      error: _error,
      confirmLabel: 'Đóng gói xong',
      confirmIcon: Icons.inventory_rounded,
      onConfirm: _submit,
      children: [
        TextField(
          controller: _qrController,
          decoration: const InputDecoration(labelText: 'Mã QR đóng gói *'),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 14),

        // Thanh cân dính — nguồn nhập chạy nền cho mọi dòng bên dưới.
        ScaleBar(
          key: _scaleBarKey,
          enabled: _rows.isNotEmpty,
          targetLabel: _target == null ? null : 'lô ${_target!.group.lotLabel}',
          onCapture: _onScaleCapture,
        ),
        const SizedBox(height: 14),

        if (_rows.isEmpty)
          Text(
            'Phiếu chưa có phân bổ lô nên không cân được. Hãy phân bổ và lấy hàng trước.',
            style: TextStyle(color: secondary),
          )
        else
          for (var index = 0; index < _rows.length; index++)
            _rowCard(index, secondary),

        const SizedBox(height: 4),
        _totalCard(total, planned, diff, secondary),
      ],
    );
  }

  Widget _rowCard(int index, Color secondary) {
    final row = _rows[index];
    final selected = index == _targetIndex;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      color: selected ? AppColors.brandTintFor(context) : null,
      onTap: selected ? null : () => setState(() => _targetIndex = index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: selected ? AppColors.primary : secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
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
                      'Lô ${row.group.lotLabel} • ${row.group.locationLabel}'
                      ' • ${row.group.bagCount} bao',
                      style: TextStyle(fontSize: 11.5, color: secondary),
                    ),
                  ],
                ),
              ),
              _SourceChip(fromScale: row.fromScale),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: row.controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Khối lượng đóng gói (kg)',
                    isDense: true,
                    helperText: row.bags.isEmpty
                        ? 'Đã lấy ${formatKg(row.group.totalPickedKg)}'
                        : '${row.bags.length}/${row.group.bagCount} bao đã cân',
                    helperStyle: TextStyle(fontSize: 11, color: secondary),
                  ),
                  onTap: () => setState(() => _targetIndex = index),
                ),
              ),
              if (row.bags.isNotEmpty || row.controller.text.trim().isNotEmpty)
                IconButton(
                  tooltip: 'Xoá số của dòng này',
                  onPressed: () => _clearRow(row),
                  icon: const Icon(Icons.backspace_outlined, size: 18),
                ),
            ],
          ),
          if (row.bags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < row.bags.length; i++)
                  InputChip(
                    label: Text(
                      'Bao ${i + 1}: ${formatNumber(row.bags[i], digits: 1)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                    onDeleted: () => _removeBag(row, i),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _totalCard(
    double total,
    double planned,
    double diff,
    Color secondary,
  ) {
    final offPlan = diff.abs() > 0.001;
    return AppCard(
      color: AppColors.subtleSurfaceFor(context),
      child: Column(
        children: [
          _KeyValue('Kế hoạch', formatKg(planned)),
          _KeyValue('Thực lấy', formatKg(widget.order.pickedKg)),
          _KeyValue('Tổng đóng gói', formatKg(total), strong: true),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                offPlan
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                size: 16,
                color: offPlan ? AppColors.warning : AppColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  offPlan
                      ? 'Lệch ${diff >= 0 ? '+' : ''}${formatKg(diff)} so với kế hoạch'
                      : 'Khớp kế hoạch',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: offPlan ? AppColors.warning : AppColors.primary,
                  ),
                ),
              ),
              if (_scaleDevice != null)
                Text(
                  _scaleDevice!,
                  style: TextStyle(fontSize: 11, color: secondary),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Một dòng cân = một nhóm lô/vị trí của phiếu xuất.
class _PackRow {
  _PackRow({
    required this.item,
    required this.group,
    required this.controller,
  }) : lastText = controller.text;

  final OutboundOrderItem item;
  final OutboundAllocationGroup group;
  final TextEditingController controller;

  /// Nội dung lần trước — dùng để phân biệt "gõ phím" với "di chuyển con trỏ".
  String lastText;

  /// Các bao đã cân cho dòng này (rỗng = nhập tay).
  final List<double> bags = [];

  /// Số hiện tại đến từ cân điện tử hay gõ tay.
  bool fromScale = false;

  /// Chặn listener khi chính code ghi vào controller (tránh tự xoá bags).
  bool suppressListener = false;

  void write(String text) {
    suppressListener = true;
    controller.text = text;
    lastText = text;
    suppressListener = false;
  }

  void writeSum() {
    final sum = bags.fold(0.0, (total, bag) => total + bag);
    // Cộng số thực sinh đuôi lẻ (0,1 + 0,2 = 0,30000000000000004) → chuẩn hoá
    // lại về bội của 0,1.
    write(bags.isEmpty ? '' : formatQuantityInput(ceilKg(sum), digits: 1));
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.fromScale});

  final bool fromScale;

  @override
  Widget build(BuildContext context) {
    final tone = fromScale ? AppTone.success : AppTone.neutral;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            fromScale ? Icons.scale_rounded : Icons.keyboard_alt_outlined,
            size: 12,
            color: tone.fg,
          ),
          const SizedBox(width: 4),
          Text(
            fromScale ? 'Từ cân' : 'Nhập tay',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: tone.fg,
            ),
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
          key: const Key('reason_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Quay lại'),
        ),
        FilledButton(
          key: const Key('reason_confirm'),
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
                      key: const Key('sheet_cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Quay lại'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('sheet_confirm'),
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

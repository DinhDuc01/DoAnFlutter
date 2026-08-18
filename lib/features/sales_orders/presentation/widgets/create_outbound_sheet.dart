import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../data/sales_order_repository.dart';
import '../../models/sales_order.dart';

/// Bảng nhập số lượng xuất cho từng dòng hàng khi tạo phiếu xuất từ đơn bán.
///
/// Quy tắc kiểm tra khớp web: mỗi dòng nằm trong khoảng 0 → số lượng đặt, và
/// phải có ít nhất một dòng > 0. Lần tạo phiếu đầu tiên điền sẵn toàn bộ số
/// lượng đặt; các lần sau để trống để người dùng tự nhập phần giao tiếp theo.
class CreateOutboundSheet extends StatefulWidget {
  const CreateOutboundSheet({required this.order, super.key});

  final SalesOrderDetail order;

  @override
  State<CreateOutboundSheet> createState() => _CreateOutboundSheetState();
}

class _CreateOutboundSheetState extends State<CreateOutboundSheet> {
  late final List<TextEditingController> _controllers;
  String? _error;

  @override
  void initState() {
    super.initState();
    final prefill = widget.order.outboundOrders.isEmpty;
    _controllers = [
      for (final item in widget.order.items)
        TextEditingController(
          text: prefill ? formatQuantityInput(item.quantityOrdered) : '',
        ),
    ];
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final items = widget.order.items;
    final lines = <CreateOutboundLine>[];

    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final raw = _controllers[index].text.trim();
      if (raw.isEmpty) continue;

      final quantity = parseDecimal(raw);
      if (quantity == null) {
        setState(() =>
            _error = 'Số lượng của "${item.productVariantName}" không hợp lệ.');
        return;
      }
      if (quantity < 0) {
        setState(() => _error = 'Số lượng xuất không được âm.');
        return;
      }
      if (quantity > item.quantityOrdered + 0.001) {
        setState(() => _error =
            '"${item.productVariantName}" chỉ được xuất tối đa ${formatKg(item.quantityOrdered)}.');
        return;
      }
      if (quantity > 0) {
        lines.add(CreateOutboundLine(
          productVariantId: item.productVariantId,
          quantityToDispatch: quantity,
        ));
      }
    }

    if (lines.isEmpty) {
      setState(() =>
          _error = 'Nhập số lượng xuất lớn hơn 0 cho ít nhất một sản phẩm.');
      return;
    }
    Navigator.of(context).pop(lines);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.order.items;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionHeader(
              title: 'Tạo phiếu xuất kho',
              icon: Icons.local_shipping_outlined,
            ),
            Text(
              'Đơn ${widget.order.soCode} • ${widget.order.customerName}',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondaryFor(context),
              ),
            ),
            const SizedBox(height: 16),
            for (var index = 0; index < items.length; index++)
              _line(items[index], _controllers[index]),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ],
            const SizedBox(height: 16),
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
                    onPressed: _submit,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Tạo phiếu'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(SalesOrderItem item, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.productVariantName,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            '${item.sku ?? '—'} • Đặt ${formatKg(item.quantityOrdered)}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryFor(context),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Số lượng xuất (kg)',
              isDense: true,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
        ],
      ),
    );
  }
}

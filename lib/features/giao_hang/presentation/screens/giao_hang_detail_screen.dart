import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/giao_hang_receipt.dart';

class GiaoHangDetailScreen extends StatelessWidget {
  const GiaoHangDetailScreen({required this.result, super.key});

  final GiaoHangSuccessResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      appBar: AppBar(title: const Text('Chi tiết đơn bán')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card('Thông tin phiếu', [
            _row('Mã đơn bán', result.receiptCode),
            _row('Trạng thái', result.status),
            _row('Hình thức', result.salesMode.label),
            _row('Thời gian', _formatDateTime(result.completedAt)),
            _row('Người thực hiện', result.performedBy),
          ]),
          const SizedBox(height: 12),
          _card('Sản phẩm và kho', [
            _row('Sản phẩm', result.productName),
            _row('SKU', result.sku),
            _row('Số lượng', '${result.quantity} bao'),
            _row('Đơn giá', '${result.unitSalePrice.toStringAsFixed(0)} đ/bao'),
            _row('Kho xuất', result.warehouseName),
            _row('Vị trí', result.locationCode ?? 'Không phân vị trí'),
            _row('Tồn tại lúc tạo đơn', '${result.remainingStock} bao'),
          ]),
          const SizedBox(height: 12),
          _card('Người nhận', [
            _row('Khách hàng', result.customerName),
            _row('Điện thoại', result.customerPhone ?? 'Chưa có'),
            _row('Địa chỉ', result.customerAddress ?? 'Chưa có'),
          ]),
          if (result.expectedDeliveryDate != null) ...[
            const SizedBox(height: 12),
            _card('Giao hàng', [
              _row('Ngày giao', _formatDateTime(result.expectedDeliveryDate!)),
              _row('Địa chỉ', result.customerAddress ?? 'Chưa có'),
            ]),
          ],
          if (result.note?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _card('Ghi chú', [Text(result.note!)]),
          ],
        ],
      ),
    );
  }

  Widget _card(String title, List<Widget> children) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

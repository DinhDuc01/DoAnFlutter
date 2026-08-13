import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/thu_mua_receipt.dart';
import '../widgets/thu_mua_bottom_bar.dart';

/// Màn hình thông báo Nhập kho thành công (Inbound Success Screen).
/// Hiển thị dấu checkmark động, số lượng sản phẩm đã nhập và thẻ thông tin chi tiết biên lai.
class ThuMuaSuccessScreen extends StatefulWidget {
  const ThuMuaSuccessScreen({super.key});

  @override
  State<ThuMuaSuccessScreen> createState() => _ThuMuaSuccessScreenState();
}

class _ThuMuaSuccessScreenState extends State<ThuMuaSuccessScreen> {
  ThuMuaSuccessResult? _result;

  @override
  Widget build(BuildContext context) {
    // Nhận thông tin kết quả nhập kho được truyền qua Navigator arguments
    final args = ModalRoute.of(context)?.settings.arguments;

    // Bản tin dự phòng (fallback) phòng trường hợp Navigator gọi không kèm tham số
    final fallbackResult = ThuMuaSuccessResult(
      receiptCode: 'PN-2026-API',
      quantity: 1,
      productName: 'Sản phẩm',
      sku: 'SKU',
      warehouseName: 'Tất cả kho',
      performedBy: 'Nhân viên kho',
      completedAt: DateTime.now(),
      orderId: 0,
      status: 'Phiếu nháp',
      unitCostPrice: 0,
    );
    _result ??= args is ThuMuaSuccessResult ? args : fallbackResult;
    final result = _result!;

    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 40),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const Spacer(),
                    // Biểu tượng checkmark vòng tròn màu xanh
                    const _SuccessMark(),
                    const SizedBox(height: 18),
                    Text(
                      'Đã tạo phiếu!',
                      style: TextStyle(
                        color: AppColors.textPrimaryFor(context),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Phiếu nháp đã được lưu trên hệ thống',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    // Số lượng sản phẩm thực tế nhập thành công
                    Text(
                      '${result.quantity} bao',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    // Tên sản phẩm & mã SKU sản phẩm
                    Text(
                      '${result.productName} • ${result.sku}',
                      style: TextStyle(
                        color: AppColors.textSecondaryFor(context),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 22),
                    // Thẻ hiển thị các dòng thông số biên nhận
                    _SuccessInfoCard(result: result),
                    const Spacer(),
                    if (result.status == 'Phiếu nháp') ...[
                      Text(
                        'Phiếu đang chờ cập nhật hoặc xử lý tiếp trên hệ thống.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondaryFor(context),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    // Nút bấm quay về trang chủ
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          AppRoutes.home,
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('Quay về trang chủ'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const ThuMuaBottomBar(),
    );
  }
}

/// Widget vẽ biểu tượng vòng tròn báo thành công với hai lớp viền xanh nhạt
class _SuccessMark extends StatelessWidget {
  const _SuccessMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.08),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 2,
        ),
      ),
      child: Center(
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.check_circle_outline,
            color: AppColors.primary,
            size: 38,
          ),
        ),
      ),
    );
  }
}

/// Thẻ hiển thị chi tiết biên lai nhập kho thành công (Mã phiếu, Thời gian, Kho, Người thực hiện)
class _SuccessInfoCard extends StatelessWidget {
  const _SuccessInfoCard({
    required this.result,
  });

  final ThuMuaSuccessResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Column(
        children: [
          _InfoRow(label: 'Mã phiếu mua lúa', value: result.receiptCode),
          const SizedBox(height: 8),
          _InfoRow(label: 'Trạng thái', value: result.status),
          const SizedBox(height: 8),
          _InfoRow(
            label: 'Đơn giá',
            value: '${result.unitCostPrice.toStringAsFixed(0)} đ/kg',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            label: 'Khối lượng',
            value: '${result.actualWeightKg.toStringAsFixed(1)} kg',
          ),
          if (result.moisturePercent != null) ...[
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Độ ẩm',
              value: '${result.moisturePercent!.toStringAsFixed(1)}%',
            ),
          ],
          _InfoRow(
              label: 'Thời gian', value: _formatDateTime(result.completedAt)),
          const SizedBox(height: 8),
          _InfoRow(label: 'Kho', value: result.warehouseName),
          const SizedBox(height: 8),
          _InfoRow(label: 'Người thực hiện', value: result.performedBy),
        ],
      ),
    );
  }

  /// Định dạng đối tượng DateTime thành chuỗi hiển thị dạng DD/MM/YYYY HH:MM:SS
  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute:$second';
  }
}

/// Hàng thông tin biên lai gồm Nhãn (bên trái) và Giá trị (bên phải)
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondaryFor(context),
              fontSize: 12,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimaryFor(context),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/inbound_receipt.dart';
import '../widgets/inbound_bottom_bar.dart';

class InboundSuccessScreen extends StatelessWidget {
  const InboundSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final fallbackResult = InboundSuccessResult(
      receiptCode: 'PN-2025-005',
      quantity: 50,
      productName: 'Bóng đèn LED 9W',
      sku: 'SKU-0001',
      warehouseName: 'Kho A - TP. HCM',
      performedBy: 'Nguyễn Văn A',
      completedAt: DateTime.now(),
    );
    final result = args is InboundSuccessResult ? args : fallbackResult;

    return Scaffold(
      backgroundColor: AppColors.backgroundStart,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Spacer(),
              const _SuccessMark(),
              const SizedBox(height: 18),
              const Text(
                'Thành công!',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Đã nhập kho',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Text(
                '${result.quantity} sản phẩm',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${result.productName} • ${result.sku}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 22),
              _SuccessInfoCard(result: result),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.remove_red_eye_outlined),
                label: const Text('Xem chi tiết'),
              ),
              const SizedBox(height: 10),
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
      bottomNavigationBar: const InboundBottomBar(),
    );
  }
}

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

class _SuccessInfoCard extends StatelessWidget {
  const _SuccessInfoCard({
    required this.result,
  });

  final InboundSuccessResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _InfoRow(label: 'Mã phiếu nhập', value: result.receiptCode),
          const SizedBox(height: 8),
          _InfoRow(label: 'Thời gian', value: _formatDateTime(result.completedAt)),
          const SizedBox(height: 8),
          _InfoRow(label: 'Kho', value: result.warehouseName),
          const SizedBox(height: 8),
          _InfoRow(label: 'Người thực hiện', value: result.performedBy),
        ],
      ),
    );
  }

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
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

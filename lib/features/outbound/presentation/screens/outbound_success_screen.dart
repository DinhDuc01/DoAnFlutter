import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/outbound_receipt.dart';
import '../widgets/outbound_bottom_bar.dart';

class OutboundSuccessScreen extends StatelessWidget {
  const OutboundSuccessScreen({super.key});

  static const _accent = Color(0xFF3478F6);

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final fallbackResult = OutboundSuccessResult(
      receiptCode: 'PX-2025-005',
      quantity: 20,
      productName: 'Cáp sạc Type-C 1m',
      sku: 'SKU-0002',
      customerName: 'Kho A - TP. HCM',
      performedBy: 'Nguyễn Văn A',
      completedAt: DateTime.now(),
    );
    final result = args is OutboundSuccessResult ? args : fallbackResult;

    return Scaffold(
      backgroundColor: AppColors.backgroundStart,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Spacer(),
              const _SuccessMark(accent: _accent),
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
                'Đã xuất kho',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Text(
                '${result.quantity} sản phẩm',
                style: const TextStyle(
                  color: _accent,
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
                style: FilledButton.styleFrom(backgroundColor: _accent),
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
      bottomNavigationBar: const OutboundBottomBar(),
    );
  }
}

class _SuccessMark extends StatelessWidget {
  const _SuccessMark({
    required this.accent,
  });

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.25), width: 2),
      ),
      child: Center(
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: 0.35), width: 2),
          ),
          child: Icon(
            Icons.check_circle_outline,
            color: accent,
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

  final OutboundSuccessResult result;

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
          _InfoRow(label: 'Mã phiếu xuất', value: result.receiptCode),
          const SizedBox(height: 8),
          _InfoRow(label: 'Thời gian', value: _formatDateTime(result.completedAt)),
          const SizedBox(height: 8),
          _InfoRow(label: 'Kho', value: result.customerName),
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

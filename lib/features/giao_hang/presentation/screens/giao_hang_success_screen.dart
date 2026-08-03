import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/api_giao_hang_repository.dart';
import '../../models/giao_hang_receipt.dart';
import 'giao_hang_detail_screen.dart';

class GiaoHangSuccessScreen extends StatefulWidget {
  const GiaoHangSuccessScreen({super.key});

  @override
  State<GiaoHangSuccessScreen> createState() => _GiaoHangSuccessScreenState();
}

class _GiaoHangSuccessScreenState extends State<GiaoHangSuccessScreen> {
  final ApiGiaoHangRepository _repository = ApiGiaoHangRepository();
  GiaoHangSuccessResult? _result;
  bool _confirming = false;

  Future<void> _confirmOrder() async {
    final result = _result;
    if (result == null || result.orderId <= 0 || _confirming) return;
    setState(() => _confirming = true);
    try {
      await _repository.confirmSalesOrder(result.orderId);
      if (!mounted) return;
      setState(() => _result = result.copyWithStatus('Đã xác nhận'));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xác nhận đơn bán trên server')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không xác nhận được đơn bán: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final result = args is GiaoHangSuccessResult
        ? args
        : GiaoHangSuccessResult(
            receiptCode: 'GH-DEMO',
            quantity: 1,
            productName: 'Sản phẩm',
            sku: 'SKU',
            customerName: 'Khách hàng',
            performedBy: 'Nhân viên kho',
            completedAt: DateTime.now(),
            warehouseName: 'Kho',
            remainingStock: 0,
            orderId: 0,
            status: 'Chờ xác nhận',
            salesMode: SalesMode.direct,
            unitSalePrice: 0,
          );
    _result ??= result;
    final current = _result!;
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
                    const Icon(Icons.pending_actions,
                        color: Color(0xFF2563EB), size: 88),
                    const SizedBox(height: 16),
                    const Text('Đã tạo đơn bán',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text('${current.quantity} bao • ${current.productName}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 20),
                    Card(
                      child: ListTile(
                        title: Text(current.customerName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                            '${current.salesMode.label} • ${current.receiptCode}'),
                        trailing: Text(current.status),
                      ),
                    ),
                    const Spacer(),
                    if (current.status == 'Chờ xác nhận') ...[
                      FilledButton.icon(
                        onPressed: _confirming ? null : _confirmOrder,
                        icon: _confirming
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.verified_outlined),
                        label: Text(
                          _confirming ? 'Đang xác nhận...' : 'Xác nhận đơn bán',
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => GiaoHangDetailScreen(result: current),
                        ),
                      ),
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Xem chi tiết đơn bán'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.home,
                        (route) => false,
                      ),
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('Về trang chủ'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

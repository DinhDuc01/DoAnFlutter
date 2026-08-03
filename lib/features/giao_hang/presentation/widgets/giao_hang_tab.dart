import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/api_giao_hang_repository.dart';
import '../../data/giao_hang_repository.dart';
import '../../models/giao_hang_receipt.dart';
import '../screens/giao_hang_screen.dart';

class GiaoHangTab extends StatefulWidget {
  const GiaoHangTab({super.key});

  @override
  State<GiaoHangTab> createState() => _GiaoHangTabState();
}

class _GiaoHangTabState extends State<GiaoHangTab> {
  final GiaoHangRepository _repository = ApiGiaoHangRepository();
  late Future<List<GiaoHangReceipt>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.getAvailableReceipts();
  }

  void _reload() {
    setState(() {
      _future = _repository.getAvailableReceipts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF4FBF7),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Bán hàng (xuất kho)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Tải lại',
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<GiaoHangReceipt>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const ListSkeleton();
                }
                if (snapshot.hasError) {
                  return HErrorState(
                    message:
                        'Không tải được hàng có thể bán: ${snapshot.error}',
                    onRetry: _reload,
                  );
                }
                final receipts = snapshot.data ?? const [];
                if (receipts.isEmpty) {
                  return const HEmptyState(
                    title: 'Không có hàng để bán',
                    description: 'Tất cả sản phẩm hiện có tồn khả dụng bằng 0.',
                    icon: Icons.local_shipping_outlined,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    _reload();
                    await _future;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: receipts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final receipt = receipts[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => GiaoHangScreen(
                                initialReceipt: receipt,
                              ),
                            ),
                          ),
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFEFF6FF),
                            child: Icon(
                              Icons.point_of_sale_outlined,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          title: Text(
                            receipt.productName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${receipt.sku} • ${receipt.warehouseName}'
                            '${receipt.locationCode == null ? '' : ' / ${receipt.locationCode}'}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${receipt.currentStock}',
                                style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                              const Text('bao khả dụng',
                                  style: TextStyle(fontSize: 10)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

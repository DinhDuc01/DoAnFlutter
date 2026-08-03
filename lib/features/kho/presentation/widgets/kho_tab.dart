import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../products/presentation/screens/product_detail_screen.dart';
import '../../data/api_kho_check_repository.dart';
import '../../data/kho_check_repository.dart';
import '../../models/kho_check.dart';

class KhoTab extends StatefulWidget {
  const KhoTab({super.key});

  @override
  State<KhoTab> createState() => _KhoTabState();
}

class _KhoTabState extends State<KhoTab> {
  final KhoCheckRepository _repository = ApiKhoCheckRepository();
  late Future<KhoCheck> _checkFuture;

  @override
  void initState() {
    super.initState();
    _checkFuture = _repository.getDraftCheck();
  }

  void _reload() {
    setState(() {
      _checkFuture = _repository.getDraftCheck();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF4FBF7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Sản phẩm trong kho',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
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
            child: FutureBuilder<KhoCheck>(
              future: _checkFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const ListSkeleton();
                }
                if (snapshot.hasError) {
                  return HErrorState(
                    message: 'Không tải được tồn kho: ${snapshot.error}',
                    onRetry: _reload,
                  );
                }
                final check = snapshot.data;
                if (check == null || check.items.isEmpty) {
                  return const HEmptyState(
                    title: 'Kho chưa có hàng',
                    description:
                        'Không có sản phẩm nào có số lượng tồn lớn hơn 0.',
                    icon: Icons.warehouse_outlined,
                  );
                }
                return _InventoryList(check: check);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryList extends StatelessWidget {
  const _InventoryList({required this.check});

  final KhoCheck check;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _CheckDateBanner(check: check),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Sản phẩm',
                value: '${check.totalProducts}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                label: 'Tổng tồn',
                value: '${check.totalSystemQuantity}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final item in check.items) ...[
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProductDetailScreen(
                    productVariantId: item.productVariantId,
                  ),
                ),
              ),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEAF7EF),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.primary,
                ),
              ),
              title: Text(
                item.productName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${item.sku}\nKiểm gần nhất: '
                '${_formatDate(item.lastStockTakeDate)}',
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${item.systemQuantity}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.stocktake),
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Tạo phiếu kiểm kê'),
        ),
      ],
    );
  }
}

class _CheckDateBanner extends StatelessWidget {
  const _CheckDateBanner({required this.check});

  final KhoCheck check;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCDE7D6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available_outlined, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Dữ liệu tồn ngày ${_formatDate(check.checkedAt)} • '
              '${check.warehouseName}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) return 'Chưa có';
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}

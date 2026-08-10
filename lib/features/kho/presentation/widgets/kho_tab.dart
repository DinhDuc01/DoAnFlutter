import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_data_view.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_ui.dart';
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
  final RealtimeDataController _controller = RealtimeDataController();

  static const Set<String> _entities = {
    'Inventory',
    'InventoryTransaction',
    'InboundOrder',
    'PaddyLot',
    'Warehouse',
    'Location',
  };

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.backgroundFor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppGradientHeader(
            title: 'Sản phẩm trong kho',
            subtitle: 'Tồn kho hiện tại theo hệ thống',
            trailing: IconButton(
              onPressed: _controller.reload,
              color: Colors.white,
              icon: const Icon(Icons.refresh),
              tooltip: 'Tải lại',
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RealtimeDataView<KhoCheck>(
              loader: _repository.getDraftCheck,
              controller: _controller,
              entities: _entities,
              loadingBuilder: (_) => const ListSkeleton(),
              errorBuilder: (context, error, retry) => HErrorState(
                message: 'Không tải được tồn kho: $error',
                onRetry: retry,
              ),
              builder: (context, check) {
                if (check.items.isEmpty) {
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
          ],
        ),
        const SizedBox(height: 14),
        for (final item in check.items) ...[
          AppCard(
            padding: EdgeInsets.zero,
            margin: const EdgeInsets.only(bottom: 8),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProductDetailScreen(
                  productVariantId: item.productVariantId,
                ),
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              leading: const CircleAvatar(
                backgroundColor: AppColors.brandTintStrong,
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
                  const Icon(Icons.chevron_right,
                      color: AppColors.textTertiary),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.stocktake),
          icon: Icon(
            check.id > 0 ? Icons.drafts_outlined : Icons.fact_check_outlined,
          ),
          label: Text(
            check.id > 0 ? 'Tiếp tục phiếu kiểm kê nháp' : 'Tạo phiếu kiểm kê',
          ),
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
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.brandTintStrong),
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
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: AppColors.textSecondaryFor(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimaryFor(context)),
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

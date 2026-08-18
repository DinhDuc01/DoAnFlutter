import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_data_view.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../data/product_variant_api.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    this.productVariantId,
    super.key,
  });

  final int? productVariantId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ProductVariantApi _productApi = ProductVariantApi();

  static const Set<String> _entities = {
    'Product',
    'ProductVariant',
    'Inventory',
    'InventoryTransaction',
  };

  Future<ProductVariantStock> _loadProduct() {
    final id = widget.productVariantId;
    return id != null && id > 0
        ? _productApi.variantDetails(id)
        : _productApi.firstActiveVariantWithStock();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      appBar: AppBar(title: const Text('Chi tiết sản phẩm')),
      body: RealtimeDataView<ProductVariantStock>(
        loader: _loadProduct,
        entities: _entities,
        loadingBuilder: (_) => const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, error, retry) => _ErrorState(message: '$error'),
        builder: (context, product) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProductSummaryCard(product: product),
              const SizedBox(height: 12),
              _ProductInfoCard(product: product),
              const SizedBox(height: 12),
              _WarehouseStockCard(product: product),
              if (product.description?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                _DescriptionCard(description: product.description!.trim()),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text(
              'Không tải được chi tiết sản phẩm',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ProductSummaryCard extends StatelessWidget {
  const _ProductSummaryCard({required this.product});

  final ProductVariantStock product;

  @override
  Widget build(BuildContext context) {
    final isLowStock =
        product.quantityAvailable <= (product.minStockLevel ?? 10);
    return AppCard(
      child: Row(
          children: [
            _ProductImage(imageUrl: product.imageUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.productName ?? product.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (product.productName != null &&
                      product.name != product.productName) ...[
                    const SizedBox(height: 3),
                    Text(product.name),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    product.sku,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  _StatusBadge(isLowStock: isLowStock),
                ],
              ),
            ),
          ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    return Container(
      width: 68,
      height: 68,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.brandTintStrong,
        borderRadius: BorderRadius.circular(16),
      ),
      child: url == null || url.isEmpty
          ? const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.primary,
              size: 34,
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.inventory_2_outlined,
                color: AppColors.primary,
                size: 34,
              ),
            ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isLowStock});

  final bool isLowStock;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isLowStock ? AppColors.dangerTint : AppColors.successTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          isLowStock ? 'Sắp hết hàng' : 'Còn hàng',
          style: TextStyle(
            color: isLowStock ? AppColors.danger : AppColors.primaryDark,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ProductInfoCard extends StatelessWidget {
  const _ProductInfoCard({required this.product});

  final ProductVariantStock product;

  @override
  Widget build(BuildContext context) {
    final unit = product.unitName?.trim().isNotEmpty == true
        ? product.unitName!
        : 'đơn vị';
    return _SectionCard(
      title: 'Thông tin sản phẩm',
      children: [
        _InfoRow(label: 'SKU', value: product.sku),
        if (product.categoryName?.trim().isNotEmpty ?? false)
          _InfoRow(label: 'Danh mục', value: product.categoryName!),
        _InfoRow(label: 'Đơn vị tính', value: unit),
        _InfoRow(
          label: 'Khối lượng chuẩn',
          value: '${product.weightKg.toStringAsFixed(2)} kg',
        ),
        _InfoRow(label: 'Giá vốn', value: _formatMoney(product.costPrice)),
        _InfoRow(label: 'Giá bán', value: _formatMoney(product.salePrice)),
        if (product.minStockLevel != null)
          _InfoRow(
            label: 'Mức tồn tối thiểu',
            value: '${product.minStockLevel!.toStringAsFixed(0)} $unit',
          ),
      ],
    );
  }
}

class _WarehouseStockCard extends StatelessWidget {
  const _WarehouseStockCard({required this.product});

  final ProductVariantStock product;

  @override
  Widget build(BuildContext context) {
    // Show every warehouse, including zero-stock rows, so the warehouse
    // split is complete and operators can see where a product is missing.
    final stockedWarehouses = product.warehouses;
    return _SectionCard(
      title: 'Tồn kho',
      children: [
        _InfoRow(label: 'Đã giữ', value: '${product.quantityReserved}'),
        _InfoRow(label: 'Có thể xuất', value: '${product.quantityAvailable}'),
        _InfoRow(
          label: 'Kiểm kê gần nhất',
          value: _formatDate(product.lastStockTakeDate),
        ),
        if (stockedWarehouses.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('Sản phẩm hiện không còn hàng trong kho.'),
          ),
        for (final inventory in stockedWarehouses)
          _WarehouseRow(inventory: inventory),
      ],
    );
  }
}

class _WarehouseRow extends StatelessWidget {
  const _WarehouseRow({required this.inventory});

  final WarehouseInventory inventory;

  @override
  Widget build(BuildContext context) {
    final location = inventory.locationCode?.trim();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.brandTintStrong),
      ),
      child: Row(
        children: [
          const Icon(Icons.warehouse_outlined, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inventory.warehouseName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  [
                    if (location != null && location.isNotEmpty) location,
                    'Kiểm kê: ${_formatDate(inventory.lastStockTakeDate)}',
                  ].join(' • '),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${inventory.quantityOnHand}',
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Mô tả',
      children: [Text(description, style: const TextStyle(height: 1.45))],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimaryFor(context),
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textPrimaryFor(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) return 'Chưa kiểm kê';
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String _formatMoney(double value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
    buffer.write(digits[index]);
  }
  return '${buffer.toString()}đ';
}

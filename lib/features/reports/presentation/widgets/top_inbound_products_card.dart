import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/warehouse_report.dart';

class TopInboundProductsCard extends StatelessWidget {
  const TopInboundProductsCard({
    required this.products,
    super.key,
  });

  final List<TopInboundProduct> products;

  @override
  Widget build(BuildContext context) {
    final maxQuantity = products.fold<int>(
      1,
      (max, product) => product.quantity > max ? product.quantity : max,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sản phẩm nhập nhiều nhất',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          for (var index = 0; index < products.length; index++) ...[
            _ProductProgressRow(
              product: products[index],
              maxQuantity: maxQuantity,
            ),
            if (index < products.length - 1) const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

class _ProductProgressRow extends StatelessWidget {
  const _ProductProgressRow({
    required this.product,
    required this.maxQuantity,
  });

  final TopInboundProduct product;
  final int maxQuantity;

  @override
  Widget build(BuildContext context) {
    final progress = product.quantity / maxQuantity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '+${product.quantity}',
              style: TextStyle(
                color: product.color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation<Color>(product.color),
          ),
        ),
      ],
    );
  }
}

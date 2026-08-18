import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/warehouse_report.dart';

/// Thẻ hiển thị các sản phẩm nhập kho nhiều nhất (Top Inbound Products Card).
/// Sử dụng biểu đồ thanh tiến trình LinearProgressIndicator để mô phỏng tương quan số lượng giữa các sản phẩm.
class TopThuMuaProductsCard extends StatelessWidget {
  /// Khởi tạo [TopThuMuaProductsCard] nhận danh sách sản phẩm nhập nhiều nhất.
  const TopThuMuaProductsCard({
    required this.products,
    super.key,
  });

  /// Danh sách sản phẩm nhập nhiều nhất.
  final List<TopThuMuaProduct> products;

  @override
  Widget build(BuildContext context) {
    // Tính toán lượng nhập lớn nhất để làm mốc tỷ lệ 100% cho thanh tiến trình
    final maxQuantity = products.fold<int>(
      1,
      (max, product) => product.quantity > max ? product.quantity : max,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sản phẩm nhập nhiều nhất',
            style: TextStyle(
              color: AppColors.textPrimaryFor(context),
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

/// Widget hiển thị thông tin sản phẩm và một thanh tiến trình tương ứng tỉ lệ nhập hàng.
class _ProductProgressRow extends StatelessWidget {
  const _ProductProgressRow({
    required this.product,
    required this.maxQuantity,
  });

  /// Thông tin sản phẩm.
  final TopThuMuaProduct product;

  /// Giá trị sản phẩm có lượng nhập nhiều nhất.
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
                style: TextStyle(
                  color: AppColors.textPrimaryFor(context),
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
        // Thanh tiến trình ngang mô phỏng tỷ lệ nhập hàng
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.borderFor(context),
            valueColor: AlwaysStoppedAnimation<Color>(product.color),
          ),
        ),
      ],
    );
  }
}

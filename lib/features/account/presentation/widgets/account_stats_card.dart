import 'package:flutter/material.dart';

import '../../models/account_profile.dart';

/// Thẻ hiển thị số liệu thống kê hoạt động (Account Stats Card).
/// Được dịch chuyển âm (-18px) lên trên để đè một phần lên Header tạo hiệu ứng chiều sâu (floating card).
class AccountStatsCard extends StatelessWidget {
  const AccountStatsCard({
    required this.profile,
    super.key,
  });

  /// Thông tin hồ sơ chứa các biến đếm hoạt động.
  final AccountProfile profile;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Transform.translate(
      offset: const Offset(0, -18), // Dịch chuyển vị trí lên trên đè lên header
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Hiển thị 3 chỉ số Nhập kho, Xuất kho, Kiểm kho phân tách bởi vạch dọc
            _StatItem(value: profile.inboundCount, label: 'Nhập kho'),
            _Divider(),
            _StatItem(value: profile.outboundCount, label: 'Xuất kho'),
            _Divider(),
            _StatItem(value: profile.inventoryCount, label: 'Kiểm kê'),
          ],
        ),
      ),
    );
  }
}

/// Widget phụ con biểu diễn một ô đếm chỉ số.
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
  });

  /// Số lượng thống kê.
  final int value;

  /// Nhãn mô tả (ví dụ: "Nhập kho").
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Vạch kẻ phân cách dọc giữa các chỉ số.
class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

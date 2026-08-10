import 'package:flutter/material.dart';

/// Hướng dẫn đếm số lượng thực tế trên màn hình kiểm kê.
class KhoCheckHint extends StatelessWidget {
  /// Khởi tạo [KhoCheckHint].
  const KhoCheckHint({super.key});

  /// Màu tím sẫm chủ đạo cho chữ hướng dẫn.
  static const _accentDark = Color(0xFF8200DB);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3E8FF)),
      ),
      child: const Text(
        'Chọn sản phẩm cần kiểm, sau đó nhập số thực tế. Tồn hệ thống được ẩn trong lúc kiểm kê.',
        style: TextStyle(
          color: _accentDark,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

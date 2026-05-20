import 'package:flutter/material.dart';

class InventoryCheckHint extends StatelessWidget {
  const InventoryCheckHint({super.key});

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
        'Nhập số lượng thực tế đếm được — chênh lệch tính tự động',
        style: TextStyle(
          color: _accentDark,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Widget ô nhập ghi chú xuất kho (Outbound Note Field).
/// Hỗ trợ nhập liệu nhiều dòng, căn lề văn bản mờ tự động.
class GiaoHangNoteField extends StatelessWidget {
  const GiaoHangNoteField({
    required this.controller,
    required this.hintText,
    this.labelText = 'Ghi chú',
    super.key,
  });

  /// Bộ điều khiển trường nhập ghi chú.
  final TextEditingController controller;

  /// Văn bản hướng dẫn mờ bên trong.
  final String hintText;

  /// Nhãn hiển thị của trường nhập.
  final String labelText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 1,
      maxLines: 2,
      decoration: InputDecoration(
        alignLabelWithHint: true,
        labelText: labelText,
        hintText: hintText,
        filled: true,
        fillColor: AppColors.surfaceFor(context),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

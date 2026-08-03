import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Widget ô nhập ghi chú (Note Field) cho màn hình nhập kho.
/// Hỗ trợ nhập văn bản nhiều dòng (min 2, max 3) và tự động tương thích giao diện sáng/tối.
class ThuMuaNoteField extends StatelessWidget {
  const ThuMuaNoteField({
    required this.controller,
    required this.hintText,
    this.labelText = 'Ghi chú',
    super.key,
  });

  /// Controller quản lý chuỗi ký tự nhập vào ghi chú.
  final TextEditingController controller;

  /// Văn bản hướng dẫn mờ hiển thị bên dưới.
  final String hintText;

  /// Nhãn hiển thị bên trên.
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

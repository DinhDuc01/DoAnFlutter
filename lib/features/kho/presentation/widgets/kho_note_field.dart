import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Trường ghi chú cho phiếu kiểm kê tồn kho.
class KhoNoteField extends StatelessWidget {
  /// Khởi tạo [KhoNoteField] với bộ điều khiển và văn bản gợi ý bắt buộc.
  const KhoNoteField({
    required this.controller,
    required this.hintText,
    this.labelText,
    super.key,
  });

  /// Bộ điều khiển trường văn bản.
  final TextEditingController controller;

  /// Văn bản gợi ý khi trường để trống.
  final String hintText;

  /// Nhãn hiển thị của trường nhập liệu (Ví dụ: Ghi chú hoặc Giải trình lý do...).
  final String? labelText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 2,
      decoration: InputDecoration(
        alignLabelWithHint: true,
        labelText: labelText ?? 'Ghi chú',
        hintText: hintText,
        filled: true,
        fillColor: AppColors.surfaceFor(context),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class InventoryNoteField extends StatelessWidget {
  const InventoryNoteField({
    required this.controller,
    required this.hintText,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 2,
      decoration: InputDecoration(
        alignLabelWithHint: true,
        labelText: 'Ghi chú',
        hintText: hintText,
        filled: true,
        fillColor: AppColors.surface,
      ),
    );
  }
}

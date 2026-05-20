import 'package:flutter/material.dart';

class InventoryBottomAction extends StatelessWidget {
  const InventoryBottomAction({
    required this.onConfirm,
    super.key,
  });

  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: FilledButton(
        onPressed: onConfirm,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFA855F7),
        ),
        child: const Text('Xác nhận kiểm kho'),
      ),
    );
  }
}

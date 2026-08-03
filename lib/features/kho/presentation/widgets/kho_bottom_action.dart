import 'package:flutter/material.dart';

/// Thanh hành động tạo phiếu kiểm kê.
class KhoBottomAction extends StatelessWidget {
  /// Khởi tạo [KhoBottomAction] nhận callback xác nhận.
  const KhoBottomAction({
    required this.onConfirm,
    this.isLoading = false,
    super.key,
  });

  /// Callback tạo phiếu kiểm kê.
  final VoidCallback? onConfirm;
  final bool isLoading;

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
          backgroundColor: const Color(0xFF8B5CF6),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Tạo phiếu kiểm kê'),
      ),
    );
  }
}

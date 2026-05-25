import 'package:flutter/material.dart';

class InventoryCheckHeader extends StatelessWidget {
  const InventoryCheckHeader({super.key});

  static const _accent = Color.fromARGB(255, 0, 219, 18);
  static const _accentDark = Color.fromARGB(255, 0, 219, 18);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Phiếu kiểm kho',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Kiểm kho',
              style: TextStyle(
                color: _accentDark,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

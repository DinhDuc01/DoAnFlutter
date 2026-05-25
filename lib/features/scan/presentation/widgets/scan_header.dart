import 'package:flutter/material.dart';

class ScanHeader extends StatelessWidget {
  const ScanHeader({
    required this.onToggleTorch,
    super.key,
  });

  final VoidCallback onToggleTorch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      color: Colors.black,
      child: Row(
        children: [
          IconButton.filled(
            onPressed: () => Navigator.of(context).maybePop(),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_back),
          ),
          const Expanded(
            child: Text(
              'Quét mã QR',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton.filled(
            onPressed: onToggleTorch,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.flash_on),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ScanActionPanel extends StatelessWidget {
  const ScanActionPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      color: Colors.black,
      child: Column(
        children: [
          FilledButton(
            onPressed: () {
              // API_SWAP: Trigger real QR scanner result handling here.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đang mô phỏng quét QR')),
              );
            },
            child: const Text('Quét ngay'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SecondaryScanButton(
                  icon: Icons.cameraswitch_outlined,
                  label: 'Đổi camera',
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SecondaryScanButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Thư viện ảnh',
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SecondaryScanButton extends StatelessWidget {
  const _SecondaryScanButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.border, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.border,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

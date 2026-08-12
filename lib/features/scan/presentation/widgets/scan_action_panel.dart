import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/scan_result_info.dart';

/// Bảng điều khiển hành động quét QR/Barcode (Scan Action Panel) hiển thị ở cuối màn hình quét camera.
/// Hiển thị thông số sản phẩm quét được và cung cấp các nút bấm đổi camera, quét tiếp.
class ScanActionPanel extends StatelessWidget {
  const ScanActionPanel({
    required this.onScanAgain,
    required this.onSwitchCamera,
    this.result,
    super.key,
  });

  /// Thông tin sản phẩm đọc được (nếu bằng null nghĩa là đang đợi quét).
  final ScanResultInfo? result;

  /// Callback kích hoạt quét lại.
  final VoidCallback onScanAgain;

  /// Callback đổi camera trước/sau.
  final VoidCallback onSwitchCamera;

  static const _greenAccent = Color(0xFF16A34A); // Màu xanh lá chủ đạo quét QR

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      color: Colors.black,
      child: Column(
        children: [
          // Nếu đã có kết quả quét thành công, hiển thị thẻ thông số sản phẩm
          if (result != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result!.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result!.productCode ?? result!.rawValue,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          // Nút bấm hành động chính (Quét ngay hoặc Quét lại) màu xanh lá
          FilledButton(
            onPressed: onScanAgain,
            style: FilledButton.styleFrom(
              backgroundColor: _greenAccent,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              result == null ? 'Quét ngay' : 'Quét lại',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Các phím chức năng phụ: Đổi camera, Thư viện ảnh
          Row(
            children: [
              Expanded(
                child: _SecondaryScanButton(
                  icon: Icons.cameraswitch_outlined,
                  label: 'Đổi camera',
                  onTap: onSwitchCamera,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SecondaryScanButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Thư viện ảnh',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chưa hỗ trợ quét từ ảnh')),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Nút bấm phụ màu đen viền xám cho các tuỳ chọn của camera
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

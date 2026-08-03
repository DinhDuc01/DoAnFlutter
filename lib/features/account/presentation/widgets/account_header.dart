import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/account_profile.dart';
import '../../../character/runtime/character_renderer.dart';

/// Widget Header của trang cá nhân.
/// Hiển thị CircleAvatar với chữ cái viết tắt, tên hiển thị, email và nhãn vai trò/quyền hạn (Role Chip).
class AccountHeader extends StatelessWidget {
  const AccountHeader({
    required this.profile,
    super.key,
  });

  /// Thông tin hồ sơ tài khoản truyền từ màn hình cha.
  final AccountProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      color: AppColors.primary,
      child: Row(
        children: [
          // Avatar hình tròn hiển thị chữ cái đầu tiên của tên
          Stack(
            clipBehavior: Clip.none,
            children: [
              const CharacterAvatar(size: 64),
              Positioned(
                right: -2,
                bottom: -2,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.white,
                  child: Text(
                    profile.avatarInitial,
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Cột thông tin chi tiết: Tên, Email và Chức danh
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile.email,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 6),
                // Chip hiển thị vai trò (ví dụ: Nhân viên kho)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    profile.role,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

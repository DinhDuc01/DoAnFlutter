import 'package:flutter/material.dart';

import '../../../../core/notifications/fcm_service.dart';
import '../../../../core/realtime/realtime_service.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../auth/data/auth_session_store.dart';
import '../../../auth/data/api_auth_service.dart';
import '../../../auth/models/auth_session.dart';
import '../../../character/runtime/character_renderer.dart';

class AccountTab extends StatelessWidget {
  const AccountTab({this.logout, super.key});

  final Future<void> Function(AuthSession session)? logout;

  Future<void> _logout(BuildContext context, AuthSession session) async {
    // Huỷ token FCM trước khi xoá phiên (cần token để gọi API).
    await FcmService.instance.stopForUser();
    // Đóng kết nối realtime dữ liệu.
    await RealtimeService.instance.stop();
    try {
      await (logout ?? ApiAuthService().logout)(session)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể đóng phiên trên máy chủ. Phiên trên thiết bị đã được xóa.',
            ),
          ),
        );
      }
    } finally {
      AuthSessionStore.current = null;
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthSessionStore.current;
    final user = session?.user;
    if (user == null) {
      return HErrorState(
        message: 'Phiên đăng nhập không còn tồn tại.',
        onRetry: () => Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        ),
      );
    }

    return ColoredBox(
      color: const Color(0xFFF4FBF7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProfileHeader(user: user),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MenuRow(
                    icon: Icons.badge_outlined,
                    title: 'Ngoại hình nhân viên',
                    onTap: () => Navigator.of(context).pushNamed(
                      AppRoutes.characterCustomization,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MenuRow(
                    icon: Icons.key_outlined,
                    title: 'Đổi mật khẩu',
                    onTap: () => Navigator.of(context).pushNamed(
                      AppRoutes.changePassword,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MenuRow(
                    icon: Icons.sync,
                    title: 'Đồng bộ dữ liệu',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Dữ liệu đang được tải trực tiếp từ API.'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _MenuRow(
                    icon: Icons.access_time,
                    title: 'Lịch sử thao tác của tôi',
                    onTap: () => Navigator.of(context).pushNamed(
                      AppRoutes.history,
                    ),
                  ),
                  const SizedBox(height: 80),
                  InkWell(
                    onTap: () => _logout(context, session!),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFEE2E2)),
                      ),
                      child: const Text(
                        'Đăng xuất',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final fullName =
        user.fullName.trim().isEmpty ? 'Người dùng' : user.fullName.trim();
    final email =
        user.email.trim().isEmpty ? 'Chưa có email' : user.email.trim();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      color: const Color(0xFF159447),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              const CharacterAvatar(size: 82),
              Positioned(
                right: -2,
                bottom: -2,
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.white,
                  child: Text(
                    fullName.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF159447),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF159447), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF94A3B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

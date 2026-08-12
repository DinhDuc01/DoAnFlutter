import 'package:flutter/material.dart';

import '../../../../core/notifications/fcm_service.dart';
import '../../../../core/realtime/realtime_service.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../auth/data/auth_session_store.dart';
import '../../../auth/data/api_auth_service.dart';
import '../../../auth/models/auth_session.dart';

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
      await AuthSessionStore.clear();
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
      color: AppColors.backgroundFor(context),
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
                    icon: Icons.person_outline,
                    title: 'Thông tin cá nhân',
                    onTap: () => Navigator.of(context).pushNamed(
                      AppRoutes.personalInfo,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MenuRow(
                    icon: Icons.lock_outline,
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
                  const SizedBox(height: 80),
                  InkWell(
                    onTap: () => _logout(context, session!),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.dangerTint,
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.25)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded,
                              color: AppColors.danger, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Đăng xuất',
                            style: TextStyle(
                              color: AppColors.danger,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          _UserAvatar(user: user, fullName: fullName),
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

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user, required this.fullName});

  final AuthUser user;
  final String fullName;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    final initial = fullName.characters.first.toUpperCase();

    return CircleAvatar(
      radius: 41,
      backgroundColor: Colors.white,
      backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
      child: hasAvatar
          ? null
          : Text(
              initial,
              style: const TextStyle(
                color: Color(0xFF16A34A),
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
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
          color: AppColors.surfaceFor(context),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(color: AppColors.borderFor(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.brandTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryFor(context),
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Khối skeleton nhấp nháy (shimmer bằng opacity) cho trạng thái đang tải.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({
    this.width,
    this.height,
    this.borderRadius = 8,
    super.key,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = Tween<double>(begin: 0.35, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: AppColors.isDark(context)
                  ? AppColors.darkSurfaceAlt
                  : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}

/// Trạng thái rỗng: icon tròn + tiêu đề + mô tả.
class HEmptyState extends StatelessWidget {
  const HEmptyState({
    required this.title,
    required this.description,
    this.icon = Icons.inbox_outlined,
    this.iconColor,
    this.circleColor,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color? iconColor;
  final Color? circleColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: circleColor ??
                    AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 34,
                color: iconColor ?? AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimaryFor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondaryFor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trạng thái lỗi hệ thống, có nút thử lại.
class HErrorState extends StatelessWidget {
  const HErrorState({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _RetryState(
      circleColor: AppColors.dangerTint,
      iconColor: AppColors.danger,
      icon: Icons.warning_amber_rounded,
      title: 'Đã xảy ra lỗi',
      description: message.contains('Không thể tải')
          ? message
          : 'Không thể tải dữ liệu. Vui lòng thử lại hoặc liên hệ quản trị viên.',
      buttonColor: AppColors.primary,
      onRetry: onRetry,
    );
  }
}

/// Trạng thái mất mạng, có nút thử lại.
class HNetworkState extends StatelessWidget {
  const HNetworkState({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _RetryState(
      circleColor: AppColors.warningTint,
      iconColor: AppColors.warning,
      icon: Icons.wifi_off_rounded,
      title: 'Mất kết nối mạng',
      description: 'Kiểm tra Wi-Fi hoặc dữ liệu di động rồi thử lại.',
      buttonColor: AppColors.warning,
      onRetry: onRetry,
    );
  }
}

class _RetryState extends StatelessWidget {
  const _RetryState({
    required this.circleColor,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonColor,
    required this.onRetry,
  });

  final Color circleColor;
  final Color iconColor;
  final IconData icon;
  final String title;
  final String description;
  final Color buttonColor;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: iconColor),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimaryFor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondaryFor(context),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: buttonColor,
                minimumSize: const Size(140, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                ),
              ),
              child: const Text(
                'Thử lại',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton danh sách: 3 ô thống kê + 4 dòng + nút CTA.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Expanded(child: SkeletonPulse(height: 62, borderRadius: 14)),
              SizedBox(width: 10),
              Expanded(child: SkeletonPulse(height: 62, borderRadius: 14)),
              SizedBox(width: 10),
              Expanded(child: SkeletonPulse(height: 62, borderRadius: 14)),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceFor(context),
              borderRadius: BorderRadius.circular(AppColors.radiusLg),
              border: Border.all(color: AppColors.borderFor(context)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 1,
                color: AppColors.borderFor(context),
              ),
              itemBuilder: (_, __) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    SkeletonPulse(width: 22, height: 22, borderRadius: 11),
                    SizedBox(width: 12),
                    Expanded(
                      child: SkeletonPulse(height: 14, borderRadius: 4),
                    ),
                    SizedBox(width: 12),
                    SkeletonPulse(width: 12, height: 20, borderRadius: 2),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const SkeletonPulse(height: 50, borderRadius: 14),
        ],
      ),
    );
  }
}

/// Skeleton biểu mẫu: thanh ghi chú + 4 field + nút CTA.
class FormSkeleton extends StatelessWidget {
  const FormSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SkeletonPulse(height: 40, borderRadius: 12),
          const SizedBox(height: 24),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (_, __) => const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonPulse(width: 90, height: 12),
                SizedBox(height: 8),
                SkeletonPulse(height: 50, borderRadius: 12),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const SkeletonPulse(height: 50, borderRadius: 14),
        ],
      ),
    );
  }
}

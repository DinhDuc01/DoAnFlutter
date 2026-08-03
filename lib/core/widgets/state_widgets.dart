import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// SkeletonPulse represents the 'Sk' skeleton block that pulses with an opacity animation.
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
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(begin: 0.35, end: 0.75).animate(
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
                  ? const Color(0xFF374151)
                  : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}

/// HEmptyState (HEmpty) shows an empty state illustration with title and description.
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: circleColor ?? AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: iconColor ?? AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryFor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryFor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// HErrorState (HError) displays system errors with a retry option.
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon cảnh báo tam giác viền đỏ trong vòng tròn hồng nhạt
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                size: 32,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Đã xảy ra lỗi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message.contains('Không thể tải')
                  ? message
                  : 'Không thể tải dữ liệu. Vui lòng thử lại hoặc liên hệ quản trị viên.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // Nút Thử lại màu xanh lá cây bo tròn hình pill
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF159447),
                minimumSize: const Size(120, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
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

/// HNetworkState (HNetwork) displays network offline state with retry.
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon mất kết nối mạng màu vàng cam trong vòng tròn cam nhạt
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 32,
                color: Color(0xFFD97706),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Mất kết nối mạng',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Kiểm tra Wi-Fi hoặc dữ liệu di động rồi thử lại.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // Nút Thử lại màu cam đất bo tròn hình pill
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                minimumSize: const Size(120, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
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

/// ListSkeleton displays 3 stat boxes + 4 skeleton rows + skeleton CTA button.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 3 stat boxes
          const Row(
            children: [
              Expanded(child: SkeletonPulse(height: 48, borderRadius: 12)),
              SizedBox(width: 8),
              Expanded(child: SkeletonPulse(height: 48, borderRadius: 12)),
              SizedBox(width: 8),
              Expanded(child: SkeletonPulse(height: 48, borderRadius: 12)),
            ],
          ),
          const SizedBox(height: 18),
          // 4 skeleton rows inside a card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFFF1F5F9),
              ),
              itemBuilder: (_, __) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    SkeletonPulse(width: 20, height: 20, borderRadius: 10),
                    SizedBox(width: 12),
                    Expanded(
                      child: SkeletonPulse(
                          width: 180, height: 14, borderRadius: 4),
                    ),
                    SizedBox(width: 12),
                    SkeletonPulse(width: 12, height: 20, borderRadius: 2),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Skeleton CTA button
          const SkeletonPulse(height: 48, borderRadius: 16),
        ],
      ),
    );
  }
}

/// FormSkeleton displays a note bar + 4 field skeletons + CTA button.
class FormSkeleton extends StatelessWidget {
  const FormSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Note bar skeleton
          const SkeletonPulse(height: 36, borderRadius: 6),
          const SizedBox(height: 24),
          // 4 field skeletons
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (_, __) => const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonPulse(width: 80, height: 12),
                SizedBox(height: 8),
                SkeletonPulse(height: 48, borderRadius: 8),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // CTA button skeleton
          const SkeletonPulse(height: 44, borderRadius: 22),
        ],
      ),
    );
  }
}

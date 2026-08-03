import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_service.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/purchase_schedule_repository.dart';
import '../../models/purchase_schedule.dart';

class PurchaseScheduleDetailScreen extends StatefulWidget {
  const PurchaseScheduleDetailScreen({
    this.initialSchedule,
    this.repository,
    super.key,
  });

  final PurchaseSchedule? initialSchedule;
  final PurchaseScheduleRepository? repository;

  @override
  State<PurchaseScheduleDetailScreen> createState() =>
      _PurchaseScheduleDetailScreenState();
}

class _PurchaseScheduleDetailScreenState
    extends State<PurchaseScheduleDetailScreen> {
  late final PurchaseScheduleRepository _repository;
  PurchaseSchedule? _schedule;
  PurchaseSchedule? _detail;
  Object? _error;
  bool _loading = false;
  int _generation = 0;
  StreamSubscription<Set<String>>? _realtimeSub;

  static const Set<String> _entities = {
    'PaddyPurchaseSchedule',
    'PaddyPurchaseReceipt',
    'InboundOrder',
  };

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? PurchaseScheduleRepository();
    _realtimeSub =
        RealtimeService.instance.onEntitiesChanged.listen(_onEntitiesChanged);
    if (widget.initialSchedule != null) {
      // Đặt cờ trực tiếp (không setState trong initState) rồi tải bất đồng bộ.
      _loading = true;
      _load(widget.initialSchedule!, showLoading: false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_schedule != null) return;

    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is PurchaseSchedule) {
      _loading = true;
      _load(arguments, showLoading: false);
    }
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  void _onEntitiesChanged(Set<String> changed) {
    if (!mounted || _schedule == null) return;
    if (changed.any(_entities.contains)) {
      _load(_schedule!, showLoading: false);
    }
  }

  Future<void> _load(
    PurchaseSchedule schedule, {
    required bool showLoading,
  }) async {
    _schedule = schedule;
    final generation = ++_generation;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final detail = await _repository.getScheduleDetails(schedule);
      if (!mounted || generation != _generation) return;
      setState(() {
        _detail = detail;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      // Giữ dữ liệu cũ khi reload im lặng thất bại.
      if (_detail == null) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  void _retry() {
    final schedule = _schedule;
    if (schedule == null) return;
    _load(schedule, showLoading: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FBF4),
      body: SafeArea(
        child: Column(
          children: [
            const _DetailHeader(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_schedule == null) {
      return HErrorState(
        message: 'Không tìm thấy lịch thu mua cần hiển thị.',
        onRetry: () => Navigator.of(context).maybePop(),
      );
    }
    // Chỉ hiện skeleton ở lần tải đầu tiên.
    if (_loading && _detail == null) {
      return const _DetailSkeleton();
    }
    if (_error != null && _detail == null) {
      return HErrorState(
        message: 'Không tải được chi tiết lịch: $_error',
        onRetry: _retry,
      );
    }
    return _DetailContent(schedule: _detail!);
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: Color(0xFFDDE3EA)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Icon(Icons.arrow_back, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Chi tiết lịch thu mua',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.schedule});

  final PurchaseSchedule schedule;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            children: [
              _ScheduleStatusRow(schedule: schedule),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Đặt từng bao lúa lên cân. Số cân từ thiết bị IoT sẽ tự động ghi vào điện thoại.',
                  style: TextStyle(
                    color: Color(0xFF166534),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _DetailCard(
                label: 'Nông dân',
                value: _joinAvailable([
                  schedule.farmerName,
                  schedule.farmerPhone ?? 'Chưa có số điện thoại',
                ]),
              ),
              _DetailCard(
                label: 'Địa điểm',
                value: schedule.location == 'Chưa có địa điểm'
                    ? schedule.farmerAddress ?? schedule.location
                    : schedule.location,
              ),
              _DetailCard(
                label: 'Giống',
                value:
                    '${schedule.riceVariety} · dự kiến ${_formatWeight(schedule.estimatedWeightKg)}',
              ),
              _DetailCard(
                label: 'Giá dự kiến',
                value: schedule.expectedPrice == null
                    ? 'Chưa cập nhật'
                    : '${_formatNumber(schedule.expectedPrice!)}đ/kg',
              ),
              _DetailCard(label: 'Trạng thái', value: schedule.status),
              if (schedule.note?.trim().isNotEmpty == true)
                _DetailCard(label: 'Ghi chú', value: schedule.note!.trim()),
            ],
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: schedule.isCancelled
                ? null
                : () => Navigator.of(context).pushNamed(AppRoutes.inbound),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF16B957),
              disabledBackgroundColor: const Color(0xFF94A3B8),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              schedule.isCancelled ? 'Lịch đã hủy' : 'Bắt đầu cân tại nhà',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _joinAvailable(List<String> values) {
    return values.where((value) => value.trim().isNotEmpty).join(' · ');
  }

  static String _formatWeight(double weightKg) {
    if (weightKg >= 1000) {
      final tons = weightKg / 1000;
      return '${tons == tons.roundToDouble() ? tons.toStringAsFixed(0) : tons.toStringAsFixed(1)}t';
    }
    return '${weightKg.toStringAsFixed(0)}kg';
  }

  static String _formatNumber(double value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }
}

class _ScheduleStatusRow extends StatelessWidget {
  const _ScheduleStatusRow({required this.schedule});

  final PurchaseSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final statusColor = schedule.isCancelled
        ? const Color(0xFFDC2626)
        : const Color(0xFF16A34A);
    final date = '${schedule.scheduledAt.day.toString().padLeft(2, '0')}/'
        '${schedule.scheduledAt.month.toString().padLeft(2, '0')}/'
        '${schedule.scheduledAt.year}';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            schedule.status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${schedule.code} · $date',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8DEE8)),
      ),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            height: 1.3,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SkeletonPulse(width: 190, height: 28, borderRadius: 14),
        SizedBox(height: 12),
        SkeletonPulse(height: 72, borderRadius: 12),
        SizedBox(height: 12),
        SkeletonPulse(height: 58, borderRadius: 12),
        SizedBox(height: 9),
        SkeletonPulse(height: 58, borderRadius: 12),
        SizedBox(height: 9),
        SkeletonPulse(height: 58, borderRadius: 12),
        SizedBox(height: 9),
        SkeletonPulse(height: 58, borderRadius: 12),
        SizedBox(height: 9),
        SkeletonPulse(height: 58, borderRadius: 12),
      ],
    );
  }
}

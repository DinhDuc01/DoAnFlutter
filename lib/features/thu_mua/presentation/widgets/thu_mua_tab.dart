import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_data_view.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/purchase_schedule_repository.dart';
import '../../models/purchase_schedule.dart';

class ThuMuaTab extends StatefulWidget {
  const ThuMuaTab({super.key});

  @override
  State<ThuMuaTab> createState() => _ThuMuaTabState();
}

class _ThuMuaTabState extends State<ThuMuaTab> {
  final PurchaseScheduleRepository _repository = PurchaseScheduleRepository();
  final RealtimeDataController _controller = RealtimeDataController();

  static const Set<String> _entities = {
    'PaddyPurchaseSchedule',
    'PaddyPurchaseReceipt',
    'InboundOrder',
    'PaddyLot',
  };

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF4FBF7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Lịch thu mua',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tải lại',
                  onPressed: _controller.reload,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton.filled(
                  tooltip: 'Tạo phiếu nhập kho',
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.inbound),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Expanded(
            child: RealtimeDataView<List<PurchaseSchedule>>(
              loader: _repository.getSchedules,
              controller: _controller,
              entities: _entities,
              loadingBuilder: (_) => const ListSkeleton(),
              errorBuilder: (context, error, retry) => HErrorState(
                message: 'Không tải được lịch thu mua: $error',
                onRetry: retry,
              ),
              builder: (context, schedules) {
                if (schedules.isEmpty) {
                  return const HEmptyState(
                    title: 'Chưa có lịch thu mua',
                    description: 'Server chưa có lịch thu mua nào.',
                    icon: Icons.shopping_cart_outlined,
                  );
                }
                return _ScheduleList(schedules: schedules);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleList extends StatelessWidget {
  const _ScheduleList({required this.schedules});

  final List<PurchaseSchedule> schedules;

  @override
  Widget build(BuildContext context) {
    final active = schedules.where((item) => !item.isCancelled).length;
    final totalKg = schedules
        .where((item) => !item.isCancelled)
        .fold<double>(0, (sum, item) => sum + item.estimatedWeightKg);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Expanded(child: _Metric(label: '${schedules.length} lịch')),
            const SizedBox(width: 8),
            Expanded(
                child: _Metric(
                    label: '${(totalKg / 1000).toStringAsFixed(1)} tấn')),
            const SizedBox(width: 8),
            Expanded(child: _Metric(label: '$active còn hiệu lực')),
          ],
        ),
        const SizedBox(height: 16),
        for (final item in schedules) ...[
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).pushNamed(
                AppRoutes.purchaseScheduleDetail,
                arguments: item,
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: item.isCancelled
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  child: Icon(
                    item.isCancelled ? Icons.event_busy : Icons.agriculture,
                    color: item.isCancelled ? Colors.red : AppColors.primary,
                  ),
                ),
                title: Text(
                  item.farmerName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${item.code} • ${item.riceVariety}\n'
                  '${item.estimatedWeightKg.toStringAsFixed(0)} kg • ${item.status}',
                ),
                isThreeLine: true,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${item.scheduledAt.day.toString().padLeft(2, '0')}/'
                      '${item.scheduledAt.month.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/paddy_lot_repository.dart';
import '../../models/paddy_lot.dart';

class PaddyLotTraceabilityScreen extends StatefulWidget {
  const PaddyLotTraceabilityScreen({
    required this.lotId,
    required this.lotCode,
    this.repository,
    super.key,
  });

  final int lotId;
  final String lotCode;
  final PaddyLotRepository? repository;

  @override
  State<PaddyLotTraceabilityScreen> createState() =>
      _PaddyLotTraceabilityScreenState();
}

class _PaddyLotTraceabilityScreenState
    extends State<PaddyLotTraceabilityScreen> {
  late final PaddyLotRepository _repository;
  PaddyLotTraceability? _traceability;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiPaddyLotRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _traceability = null;
      _error = null;
    });
    try {
      final result = await _repository.getTraceabilityById(widget.lotId);
      if (mounted) setState(() => _traceability = result);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      appBar: AppBar(
        title: const Text('Truy xuất nguồn gốc'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_traceability == null && _error == null) return const ListSkeleton();
    if (_error != null) {
      final error = _error!;
      if (error is PaddyLotException && error.isTransient) {
        return HNetworkState(message: error.message, onRetry: _load);
      }
      return HErrorState(
          message: 'Không tải được lịch sử truy vết: $error', onRetry: _load);
    }
    final data = _traceability!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          AppCard(
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.brandTintStrong,
                  child: Icon(Icons.account_tree_outlined,
                      color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            data.requestedLotCode.isEmpty
                                ? widget.lotCode
                                : data.requestedLotCode,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w900)),
                        Text('${data.events.length} sự kiện từ Backend',
                            style: TextStyle(
                                color: AppColors.textSecondaryFor(context))),
                      ]),
                ),
              ],
            ),
          ),
          if (data.isTruncated) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningTint,
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                border: Border.all(color: AppColors.warning),
              ),
              child: const Row(children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                SizedBox(width: 10),
                Expanded(
                    child: Text(
                        'Lịch sử đã bị giới hạn độ sâu. Một số quan hệ lô có thể chưa được hiển thị.')),
              ]),
            ),
          ],
          const SizedBox(height: 18),
          if (data.events.isEmpty)
            const HEmptyState(
              title: 'Chưa có lịch sử truy vết',
              description: 'Backend chưa trả về sự kiện nào cho lô này.',
              icon: Icons.timeline_outlined,
            )
          else
            for (var index = 0; index < data.events.length; index++)
              _TimelineItem(
                event: data.events[index],
                isLast: index == data.events.length - 1,
              ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.event, required this.isLast});
  final TraceabilityEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = _eventColor(event.eventType);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(children: [
              Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2))),
              if (!isLast)
                Expanded(
                    child: Container(
                        width: 2, color: AppColors.borderFor(context))),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 15)),
                    if (event.status != null) ...[
                      const SizedBox(height: 6),
                      AppStatusChip(label: event.status!, tone: AppTone.info),
                    ],
                    if (event.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(event.description,
                          style: const TextStyle(height: 1.4)),
                    ],
                    const SizedBox(height: 10),
                    Text(_formatEventDate(event.eventAt),
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryFor(context))),
                    if (event.referenceCode != null)
                      Text(event.referenceCode!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800)),
                  ]),
            ),
          ),
        ],
      ),
    );
  }
}

Color _eventColor(String type) {
  final value = type.toUpperCase();
  if (value.contains('QUALITY')) return AppColors.info;
  if (value.contains('MILLING')) return AppColors.warning;
  if (value.contains('OUTBOUND')) return AppColors.accentPurple;
  return AppColors.primary;
}

String _formatEventDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

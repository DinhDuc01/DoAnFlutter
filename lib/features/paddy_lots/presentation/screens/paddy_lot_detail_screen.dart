import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_reload_mixin.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/paddy_lot_repository.dart';
import '../../models/paddy_lot.dart';
import 'paddy_lot_traceability_screen.dart';

class PaddyLotDetailScreen extends StatefulWidget {
  const PaddyLotDetailScreen({
    required this.lotId,
    this.repository,
    super.key,
  });

  final int lotId;
  final PaddyLotRepository? repository;

  @override
  State<PaddyLotDetailScreen> createState() => _PaddyLotDetailScreenState();
}

class _PaddyLotDetailScreenState extends State<PaddyLotDetailScreen>
    with RealtimeReloadMixin {
  /// Lô có thể được kiểm định / nhập kho / xay ở máy khác trong lúc đang xem.
  @override
  Set<String> get realtimeEntities => const {
        'PaddyLot',
        'PaddyLotBag',
        'PaddyLotBagContent',
        'PaddyLotBagMovement',
        'LotStatus',
        'QualityInspection',
        'Inventory',
      };

  @override
  void onRealtimeChanged() => _load(showLoading: false);

  late final PaddyLotRepository _repository;
  PaddyLotDetail? _detail;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiPaddyLotRepository();
    _load();
  }

  /// [showLoading] = false: giữ dữ liệu cũ trên màn và thay im lặng khi có dữ
  /// liệu mới — dùng cho reload realtime để màn không nháy về trạng thái trống.
  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _detail = null;
        _error = null;
      });
    }
    try {
      final detail = await _repository.getLotDetail(widget.lotId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _error = null;
        });
      }
    } catch (error) {
      // Reload im lặng thất bại thì giữ nguyên dữ liệu đang hiển thị.
      if (mounted && (showLoading || _detail == null)) {
        setState(() => _error = error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      appBar: AppBar(
        title: const Text('Chi tiết lô'),
        actions: [
          IconButton(
              onPressed: _load,
              tooltip: 'Tải lại',
              icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_detail == null && _error == null) return const FormSkeleton();
    if (_error != null) {
      final error = _error!;
      if (error is PaddyLotException && error.statusCode == 404) {
        return _DetailMessage(
          icon: Icons.inventory_2_outlined,
          title: 'Không tìm thấy lô',
          message: error.message,
          onRetry: _load,
        );
      }
      if (error is PaddyLotException && error.statusCode == 403) {
        return _DetailMessage(
          icon: Icons.gpp_bad_outlined,
          title: 'Không có quyền xem lô',
          message: error.message,
          onRetry: _load,
        );
      }
      if (error is PaddyLotException && error.isTransient) {
        return HNetworkState(message: error.message, onRetry: _load);
      }
      return HErrorState(
          message: 'Không tải được chi tiết lô: $error', onRetry: _load);
    }
    final lot = _detail!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(lot.lotCode,
                            style: const TextStyle(
                                fontSize: 21, fontWeight: FontWeight.w900))),
                    AppStatusChip(
                        label: lot.statusName ?? 'Chưa rõ',
                        tone: lot.needsAttention
                            ? AppTone.warning
                            : AppTone.success),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                    '${_typeName(lot.lotType)} • ${lot.sku ?? lot.productName ?? lot.riceVarietyName ?? 'Chưa có sản phẩm'}'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const AppSectionHeader(
              title: 'Nguồn lô', icon: Icons.account_tree_outlined),
          AppCard(
            child: Column(
              children: [
                _Info(
                    label: 'Phiếu mua',
                    value: lot.sourceReceiptId == null
                        ? null
                        : '#${lot.sourceReceiptId}'),
                _Info(
                    label: 'Lệnh xay',
                    value: lot.sourceMillingOrderId == null
                        ? null
                        : '#${lot.sourceMillingOrderId}'),
                _Info(label: 'Giống lúa', value: lot.riceVarietyName),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const AppSectionHeader(
              title: 'Kho và số lượng', icon: Icons.warehouse_outlined),
          AppCard(
            child: Column(
              children: [
                _Info(label: 'Kho', value: lot.warehouseName),
                _Info(label: 'Vị trí', value: lot.locationCode),
                _Info(
                    label: 'Khối lượng ban đầu',
                    value: '${lot.initialWeightKg.toStringAsFixed(1)} kg'),
                _Info(
                    label: 'Khối lượng còn lại',
                    value: '${lot.remainingWeightKg.toStringAsFixed(1)} kg'),
                if (lot.bagCount != null)
                  _Info(label: 'Số bao', value: '${lot.bagCount}'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const AppSectionHeader(
              title: 'Chất lượng và trạng thái', icon: Icons.verified_outlined),
          AppCard(
            child: Column(
              children: [
                _Info(label: 'Chất lượng', value: lot.qualityStatus),
                if (lot.isQuarantined != null)
                  _Info(
                      label: 'Cách ly',
                      value: lot.isQuarantined! ? 'Có' : 'Không'),
                if (lot.isSellable != null)
                  _Info(
                      label: 'Được phép bán',
                      value: lot.isSellable! ? 'Có' : 'Không'),
                _Info(
                    label: 'Ngày nhập',
                    value: _formatDateTime(lot.inboundDate)),
                _Info(
                    label: 'Ngày tạo', value: _formatDateTime(lot.createdDate)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('open_traceability'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PaddyLotTraceabilityScreen(
                  lotId: lot.id,
                  lotCode: lot.lotCode,
                  repository: _repository,
                ),
              ),
            ),
            icon: const Icon(Icons.timeline),
            label: const Text('Truy xuất nguồn gốc'),
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, this.value});
  final String label;
  final String? value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 142,
                child: Text(label,
                    style:
                        TextStyle(color: AppColors.textSecondaryFor(context)))),
            Expanded(
                child: Text(
                    value?.trim().isNotEmpty == true ? value! : 'Chưa có',
                    style: const TextStyle(fontWeight: FontWeight.w700))),
          ],
        ),
      );
}

class _DetailMessage extends StatelessWidget {
  const _DetailMessage(
      {required this.icon,
      required this.title,
      required this.message,
      required this.onRetry});
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 54, color: AppColors.warning),
            const SizedBox(height: 12),
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ]),
        ),
      );
}

String _typeName(String value) => switch (value.toUpperCase()) {
      'PADDY' => 'Lúa',
      'RICE' => 'Gạo',
      'BYPRODUCT' => 'Phụ phẩm',
      _ => value,
    };

String? _formatDateTime(DateTime? value) {
  if (value == null) return null;
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

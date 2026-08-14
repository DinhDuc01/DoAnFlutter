import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_reload_mixin.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/paddy_lot_repository.dart';
import '../../models/paddy_lot.dart';

/// Hồ sơ truy xuất nguồn gốc của một lô.
///
/// Backend trả về đủ cả chuỗi (lô liên quan, thu mua, kiểm định, xay xát, bán
/// ra, tổng hợp khối lượng) nhưng màn cũ chỉ vẽ `timeline`. Ở đây hiển thị hết:
/// tab Tổng quan cho bức tranh cân đối khối lượng, tab Dòng thời gian cho
/// diễn biến, tab Chi tiết cho từng chứng từ.
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
    extends State<PaddyLotTraceabilityScreen> with RealtimeReloadMixin {
  /// Dòng đời lô kéo dài qua thu mua → kiểm định → nhập kho → xay → xuất kho,
  /// mỗi bước do một người khác thao tác nên phải tự cập nhật.
  @override
  Set<String> get realtimeEntities => const {
        'PaddyLot',
        'PaddyLotBag',
        'PaddyLotBagContent',
        'PaddyLotBagMovement',
        'LotStatus',
        'QualityInspection',
        'InboundOrder',
        'InboundOrderItem',
        'MillingOrder',
        'MillingOrderInput',
        'MillingOrderOutput',
        'OutboundOrderItemAllocation',
        'InventoryTransaction',
      };

  @override
  void onRealtimeChanged() => _load(showLoading: false);

  late final PaddyLotRepository _repository;
  PaddyLotTraceability? _traceability;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiPaddyLotRepository();
    _load();
  }

  /// [showLoading] = false: reload im lặng (realtime) — giữ dữ liệu đang xem.
  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _traceability = null;
        _error = null;
      });
    }
    try {
      final result = await _repository.getTraceabilityById(widget.lotId);
      if (mounted) {
        setState(() {
          _traceability = result;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted && (showLoading || _traceability == null)) {
        setState(() => _error = error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _traceability;
    if (data == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundFor(context),
        appBar: AppBar(
          title: const Text('Truy xuất nguồn gốc'),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: _placeholder(),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.backgroundFor(context),
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Truy xuất nguồn gốc'),
              Text(
                data.requestedLotCode.isEmpty
                    ? widget.lotCode
                    : data.requestedLotCode,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tổng quan'),
              Tab(text: 'Dòng thời gian'),
              Tab(text: 'Chi tiết'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(data: data, onRefresh: _load),
            _TimelineTab(data: data, onRefresh: _load),
            _DetailTab(data: data, onRefresh: _load),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    if (_error == null) return const ListSkeleton();
    final error = _error!;
    if (error is PaddyLotException && error.isTransient) {
      return HNetworkState(message: error.message, onRetry: _load);
    }
    return HErrorState(
      message: 'Không tải được lịch sử truy vết: $error',
      onRetry: _load,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// TAB 1 — TỔNG QUAN: cân đối khối lượng cả chuỗi
// ══════════════════════════════════════════════════════════════════════

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.data, required this.onRefresh});

  final PaddyLotTraceability data;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final summary = data.summary;
    final self = data.selfLot;
    final secondary = AppColors.textSecondaryFor(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          if (self != null) _LotHeaderCard(lot: self),
          if (data.isTruncated) ...[
            const SizedBox(height: 12),
            const AppInfoBanner(
              message: 'Lịch sử đã bị giới hạn độ sâu. Một số quan hệ lô có '
                  'thể chưa được hiển thị.',
              tone: AppTone.warning,
            ),
          ],
          const SizedBox(height: 14),

          // ── Cân đối khối lượng ──────────────────────────────────────
          const AppSectionHeader(
            title: 'Cân đối khối lượng',
            icon: Icons.balance_rounded,
          ),
          _FlowRow(
            label: 'Mua vào',
            valueKg: summary.purchasedWeightKg,
            tone: AppTone.brand,
            icon: Icons.download_rounded,
          ),
          _FlowRow(
            label: 'Đưa vào xay',
            valueKg: summary.millingInputWeightKg,
            tone: AppTone.info,
            icon: Icons.autorenew_rounded,
          ),
          _FlowRow(
            label: 'Gạo thu được',
            valueKg: summary.millingRiceOutputWeightKg,
            tone: AppTone.brand,
            icon: Icons.grain_rounded,
            hint: summary.millingInputWeightKg > 0
                ? 'Tỉ lệ thu hồi thực tế '
                    '${(summary.actualYieldRate * 100).toStringAsFixed(1)}%'
                : null,
          ),
          _FlowRow(
            label: 'Phụ phẩm',
            valueKg: summary.millingByproductWeightKg,
            tone: AppTone.neutral,
            icon: Icons.grass_rounded,
          ),
          _FlowRow(
            label: 'Hao hụt',
            valueKg: summary.millingLossWeightKg,
            tone: summary.millingLossWeightKg > 0
                ? AppTone.warning
                : AppTone.neutral,
            icon: Icons.trending_down_rounded,
          ),
          _FlowRow(
            label: 'Đã xuất bán',
            valueKg: summary.dispatchedWeightKg,
            tone: AppTone.info,
            icon: Icons.local_shipping_rounded,
            hint: summary.allocatedOutboundWeightKg >
                    summary.dispatchedWeightKg
                ? 'Đang giữ cho đơn: '
                    '${formatKg(summary.allocatedOutboundWeightKg - summary.dispatchedWeightKg)}'
                : null,
          ),
          _FlowRow(
            label: 'Còn tồn',
            valueKg: summary.currentRemainingWeightKg,
            tone: AppTone.brand,
            icon: Icons.inventory_2_rounded,
            strong: true,
          ),

          const SizedBox(height: 16),
          const AppSectionHeader(
            title: 'Phạm vi truy vết',
            icon: Icons.hub_outlined,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CountChip(
                icon: Icons.account_tree_outlined,
                label: 'Lô liên quan',
                count: summary.relatedLotCount > 0
                    ? summary.relatedLotCount
                    : data.relatedLots.length,
              ),
              _CountChip(
                icon: Icons.receipt_long_outlined,
                label: 'Phiếu thu mua',
                count: summary.purchaseReceiptCount > 0
                    ? summary.purchaseReceiptCount
                    : data.purchases.length,
              ),
              _CountChip(
                icon: Icons.science_outlined,
                label: 'Lần kiểm định',
                count: summary.inspectionCount > 0
                    ? summary.inspectionCount
                    : data.inspections.length,
              ),
              _CountChip(
                icon: Icons.grain_outlined,
                label: 'Lệnh xay',
                count: summary.millingOrderCount > 0
                    ? summary.millingOrderCount
                    : data.millingOrders.length,
              ),
              _CountChip(
                icon: Icons.local_shipping_outlined,
                label: 'Phiếu xuất',
                count: summary.outboundOrderCount > 0
                    ? summary.outboundOrderCount
                    : data.outboundSales.length,
              ),
            ],
          ),

          if (data.relatedLots.length > 1) ...[
            const SizedBox(height: 16),
            const AppSectionHeader(
              title: 'Lô liên quan',
              icon: Icons.account_tree_outlined,
            ),
            for (final lot in data.relatedLots)
              if (!lot.isSelf && lot.id != data.requestedLotId)
                _RelatedLotTile(lot: lot),
          ],

          if (!data.hasDetail) ...[
            const SizedBox(height: 20),
            Text(
              'Backend chưa trả về chứng từ chi tiết cho lô này.',
              textAlign: TextAlign.center,
              style: TextStyle(color: secondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _LotHeaderCard extends StatelessWidget {
  const _LotHeaderCard({required this.lot});

  final TraceabilityLot lot;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondaryFor(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.brandTintStrong,
                child: Icon(Icons.inventory_2_outlined,
                    color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lot.lotCode,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      lot.productVariantName ?? lot.sku ?? '—',
                      style: TextStyle(fontSize: 12.5, color: secondary),
                    ),
                  ],
                ),
              ),
              if (lot.statusName != null)
                AppStatusChip(
                  label: lot.statusName!,
                  tone: lot.isQuarantined
                      ? AppTone.danger
                      : (lot.isSellable ? AppTone.success : AppTone.warning),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppStatTile(
                  label: 'Nhập ban đầu',
                  value: formatKg(lot.initialWeightKg),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppStatTile(
                  label: 'Còn lại',
                  value: formatKg(lot.remainingWeightKg),
                  tone: AppTone.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (lot.riceVarietyName != null)
                _MiniPill(icon: Icons.spa_outlined, text: lot.riceVarietyName!),
              if (lot.warehouseName != null)
                _MiniPill(
                    icon: Icons.warehouse_outlined, text: lot.warehouseName!),
              if (lot.locationCode != null)
                _MiniPill(
                    icon: Icons.place_outlined, text: lot.locationCode!),
              if (lot.inboundDate != null)
                _MiniPill(
                  icon: Icons.event_outlined,
                  text: 'Nhập ${formatDate(lot.inboundDate)}',
                ),
            ],
          ),
          if (lot.qualityStatus?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              lot.qualityStatus!.trim(),
              style: TextStyle(fontSize: 12, color: secondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _FlowRow extends StatelessWidget {
  const _FlowRow({
    required this.label,
    required this.valueKg,
    required this.tone,
    required this.icon,
    this.hint,
    this.strong = false,
  });

  final String label;
  final double valueKg;
  final AppTone tone;
  final IconData icon;
  final String? hint;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final muted = valueKg == 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: muted ? AppColors.subtleSurfaceFor(context) : tone.bg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              size: 16,
              color: muted ? AppColors.textTertiary : tone.fg,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
                if (hint != null)
                  Text(
                    hint!,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryFor(context),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            formatKg(valueKg),
            style: TextStyle(
              fontSize: strong ? 16 : 14,
              fontWeight: FontWeight.w900,
              color: muted ? AppColors.textTertiary : tone.fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondaryFor(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedLotTile extends StatelessWidget {
  const _RelatedLotTile({required this.lot});

  final TraceabilityLot lot;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondaryFor(context);
    final role = switch (lot.relationRole.toUpperCase()) {
      'PARENT' => 'Lô nguồn',
      'CHILD' => 'Lô sinh ra',
      'SIBLING' => 'Lô cùng mẻ',
      _ => lot.relationRole,
    };
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        lot.lotCode,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 13.5),
                      ),
                    ),
                    if (role.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.subtleSurfaceFor(context),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          role,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: secondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${lot.productVariantName ?? lot.sku ?? '—'}'
                  '${lot.locationCode != null ? ' • ${lot.locationCode}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: secondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatKg(lot.remainingWeightKg),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '/ ${formatKg(lot.initialWeightKg)}',
                style: TextStyle(fontSize: 11, color: secondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// TAB 2 — DÒNG THỜI GIAN
// ══════════════════════════════════════════════════════════════════════

class _TimelineTab extends StatelessWidget {
  const _TimelineTab({required this.data, required this.onRefresh});

  final PaddyLotTraceability data;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
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
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                      width: 2, color: AppColors.borderFor(context)),
                ),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                      ),
                      if (event.quantityKg != null)
                        Text(
                          formatKg(event.quantityKg),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                            color: color,
                          ),
                        ),
                    ],
                  ),
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
                  Row(
                    children: [
                      Text(
                        formatDate(event.eventAt, withTime: true),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryFor(context),
                        ),
                      ),
                      if (event.referenceCode != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          event.referenceCode!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
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

// ══════════════════════════════════════════════════════════════════════
// TAB 3 — CHI TIẾT CHỨNG TỪ
// ══════════════════════════════════════════════════════════════════════

class _DetailTab extends StatelessWidget {
  const _DetailTab({required this.data, required this.onRefresh});

  final PaddyLotTraceability data;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (!data.hasDetail) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 28),
          children: const [
            HEmptyState(
              title: 'Chưa có chứng từ',
              description:
                  'Lô này chưa gắn với phiếu thu mua, kiểm định, lệnh xay hay '
                  'phiếu xuất nào.',
              icon: Icons.description_outlined,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          if (data.purchases.isNotEmpty)
            _Section(
              title: 'Thu mua (${data.purchases.length})',
              icon: Icons.receipt_long_outlined,
              children: [
                for (final purchase in data.purchases)
                  _PurchaseTile(purchase: purchase),
              ],
            ),
          if (data.inspections.isNotEmpty)
            _Section(
              title: 'Kiểm định (${data.inspections.length})',
              icon: Icons.science_outlined,
              children: [
                for (final inspection in data.inspections)
                  _InspectionTile(inspection: inspection),
              ],
            ),
          if (data.millingOrders.isNotEmpty)
            _Section(
              title: 'Xay xát (${data.millingOrders.length})',
              icon: Icons.grain_outlined,
              children: [
                for (final milling in data.millingOrders)
                  _MillingTile(milling: milling),
              ],
            ),
          if (data.outboundSales.isNotEmpty)
            _Section(
              title: 'Bán ra (${data.outboundSales.length})',
              icon: Icons.local_shipping_outlined,
              children: [
                for (final outbound in data.outboundSales)
                  _OutboundTile(outbound: outbound),
              ],
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(title: title, icon: icon),
        ...children,
        const SizedBox(height: 8),
      ],
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({required this.purchase});

  final TraceabilityPurchase purchase;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondaryFor(context);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  purchase.receiptCode,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
              Text(
                formatKg(purchase.actualWeightKg),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _KeyLine('Nông dân',
              purchase.farmerName ?? purchase.farmerCode ?? '—'),
          if (purchase.riceVarietyName != null)
            _KeyLine('Giống lúa', purchase.riceVarietyName!),
          if (purchase.warehouseName != null)
            _KeyLine('Kho nhập', purchase.warehouseName!),
          if (purchase.bagCount != null)
            _KeyLine('Số bao', '${purchase.bagCount}'),
          if (purchase.receiptDate != null)
            _KeyLine('Ngày mua', formatDate(purchase.receiptDate)),
          if (purchase.paddyLotCode != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Tạo ra lô ${purchase.paddyLotCode}',
                style: TextStyle(fontSize: 11.5, color: secondary),
              ),
            ),
        ],
      ),
    );
  }
}

class _InspectionTile extends StatelessWidget {
  const _InspectionTile({required this.inspection});

  final TraceabilityInspection inspection;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  inspection.paddyLotCode ?? 'Lô ${inspection.paddyLotId}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
              AppStatusChip(
                label: inspection.resultName ??
                    (inspection.passedInspection ? 'Đạt' : 'Không đạt'),
                tone:
                    inspection.passedInspection ? AppTone.success : AppTone.danger,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (inspection.moisturePercent != null)
                _MiniPill(
                  icon: Icons.water_drop_outlined,
                  text: 'Ẩm ${formatNumber(inspection.moisturePercent, digits: 1)}%',
                ),
              if (inspection.impurityPercent != null)
                _MiniPill(
                  icon: Icons.grain_outlined,
                  text:
                      'Tạp ${formatNumber(inspection.impurityPercent, digits: 1)}%',
                ),
              if (inspection.moldLevel != null)
                _MiniPill(
                    icon: Icons.coronavirus_outlined,
                    text: 'Mốc ${inspection.moldLevel}'),
              if (inspection.pestLevel != null)
                _MiniPill(
                    icon: Icons.bug_report_outlined,
                    text: 'Sâu mọt ${inspection.pestLevel}'),
              if (inspection.packagingStatus != null)
                _MiniPill(
                    icon: Icons.inventory_2_outlined,
                    text: inspection.packagingStatus!),
            ],
          ),
          if (inspection.handling?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            _KeyLine('Xử lý', inspection.handling!),
          ],
          if (inspection.inspectorName != null)
            _KeyLine('Người kiểm', inspection.inspectorName!),
          if (inspection.inspectedAt != null)
            _KeyLine('Thời điểm',
                formatDate(inspection.inspectedAt, withTime: true)),
          if (inspection.note?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              inspection.note!.trim(),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryFor(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MillingTile extends StatelessWidget {
  const _MillingTile({required this.milling});

  final TraceabilityMilling milling;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondaryFor(context);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  milling.millingCode,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
              if (milling.statusName != null)
                AppStatusChip(
                    label: milling.statusName!, tone: AppTone.info),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppStatTile(
                  label: 'Lúa vào',
                  value: formatKg(milling.computedPaddyKg),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppStatTile(
                  label: 'Gạo ra',
                  value: formatKg(milling.totalRiceOutputKg),
                  tone: AppTone.brand,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppStatTile(
                  label: 'Hao hụt',
                  value: formatKg(milling.lossKg ?? 0),
                  tone: (milling.lossKg ?? 0) > 0
                      ? AppTone.warning
                      : AppTone.neutral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _KeyLine('Tỉ lệ áp dụng',
              '${formatNumber(milling.yieldRateUsed * 100, digits: 1)}%'),
          if (milling.warehouseName != null)
            _KeyLine('Kho', milling.warehouseName!),
          if (milling.completedAt != null)
            _KeyLine('Hoàn tất', formatDate(milling.completedAt, withTime: true))
          else if (milling.startedAt != null)
            _KeyLine(
                'Bắt đầu', formatDate(milling.startedAt, withTime: true)),
          if (milling.inputs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Lô đưa vào',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: secondary)),
            for (final input in milling.inputs)
              _SubLine(
                left: input.paddyLotCode ?? 'Lô ${input.paddyLotId}',
                right: formatKg(input.consumedWeightKg),
                hint: input.locationCode,
              ),
          ],
          if (milling.outputs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Sản phẩm ra',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: secondary)),
            for (final output in milling.outputs)
              _SubLine(
                left: output.outputLotCode ??
                    output.productVariantName ??
                    output.outputType,
                right: formatKg(output.outputWeightKg),
                hint: output.isByproduct ? 'Phụ phẩm' : output.sku,
              ),
          ],
        ],
      ),
    );
  }
}

class _OutboundTile extends StatelessWidget {
  const _OutboundTile({required this.outbound});

  final TraceabilityOutbound outbound;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondaryFor(context);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  outbound.salesOrderCode ?? 'Phiếu #${outbound.outboundOrderId}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
              Text(
                formatKg(outbound.totalPickedKg),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _KeyLine('Khách hàng',
              outbound.customerName ?? outbound.customerCode ?? '—'),
          if (outbound.outboundStatusName != null)
            _KeyLine('Trạng thái phiếu', outbound.outboundStatusName!),
          if (outbound.salesOrderStatusName != null)
            _KeyLine('Trạng thái đơn', outbound.salesOrderStatusName!),
          if (outbound.warehouseName != null)
            _KeyLine('Kho xuất', outbound.warehouseName!),
          if (outbound.completedDate != null)
            _KeyLine('Giao xong',
                formatDate(outbound.completedDate, withTime: true))
          else if (outbound.salesOrderDate != null)
            _KeyLine('Ngày đặt', formatDate(outbound.salesOrderDate)),
          if (outbound.allocations.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Lô đã lấy',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: secondary)),
            for (final allocation in outbound.allocations)
              _SubLine(
                left: allocation.paddyLotCode ??
                    allocation.productVariantName ??
                    'Phân bổ #${allocation.allocationId}',
                right: formatKg(allocation.quantityPickedKg),
                hint: allocation.locationCode,
              ),
          ],
        ],
      ),
    );
  }
}

// ── Widget dùng chung ────────────────────────────────────────────────

class _KeyLine extends StatelessWidget {
  const _KeyLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryFor(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubLine extends StatelessWidget {
  const _SubLine({required this.left, required this.right, this.hint});

  final String left;
  final String right;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.subdirectory_arrow_right_rounded,
              size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              hint == null ? left : '$left • $hint',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Text(
            right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.subtleSurfaceFor(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondaryFor(context)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondaryFor(context),
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

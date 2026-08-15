import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_reload_mixin.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/inbound_order_repository.dart';
import '../../models/inbound_order.dart';
import 'inbound_putaway_line_screen.dart';

/// Màn "Nhập kho & xếp vị trí" (Store-in & Put-away) — dựng theo bản web:
/// 4 ô KPI + danh sách lô chờ nhập kho. Chọn một lô để sang bước gợi ý vị trí.
///
/// Khác web đúng một điểm: mobile KHÔNG có nút phê duyệt phiếu. Mobile chỉ gửi
/// duyệt và nhận hàng; phê duyệt phiếu nhập chỉ làm trên web.
class InboundPutawayScreen extends StatefulWidget {
  const InboundPutawayScreen({this.repository, super.key});

  final InboundOrderRepository? repository;

  @override
  State<InboundPutawayScreen> createState() => _InboundPutawayScreenState();
}

class _InboundPutawayScreenState extends State<InboundPutawayScreen>
    with RealtimeReloadMixin {
  late final InboundOrderRepository _repository;

  List<InboundPutawayLine> _lines = const <InboundPutawayLine>[];
  List<StorageLocation> _locations = const <StorageLocation>[];
  Object? _error;
  bool _loading = true;

  @override
  Set<String> get realtimeEntities => const {
        'InboundOrder',
        'InboundOrderItem',
        'PaddyLot',
        'PaddyLotBag',
        'QualityInspection',
        'Location',
        'Inventory',
      };

  @override
  void onRealtimeChanged() => _load(showLoading: false);

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiInboundOrderRepository();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final lines = await _repository.getPutawayPending();
      final locations = await _safeLocations();
      if (!mounted) return;
      setState(() {
        _lines = lines;
        _locations = locations;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_lines.isEmpty) _error = error;
      });
    }
  }

  Future<List<StorageLocation>> _safeLocations() async {
    try {
      return await _repository.getLocations();
    } catch (_) {
      return _locations;
    }
  }

  /// Lô còn phải nhập: bỏ phiếu đã hủy/từ chối/hoàn tất và dòng đã hủy nhận.
  List<InboundPutawayLine> get _pendingLines => _lines.where((line) {
        final status = line.order.normalizedStatus;
        return line.item.remainingKg > 0 &&
            !const [
              InboundOrderStatuses.cancelled,
              InboundOrderStatuses.rejected,
              InboundOrderStatuses.confirmed,
            ].contains(status) &&
            line.item.receiptStatus != 'Cancelled';
      }).toList();

  Future<void> _openLine(InboundPutawayLine line) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => InboundPutawayLineScreen(
          line: line,
          locations: _locations,
          repository: _repository,
        ),
      ),
    );
    if (changed == true && mounted) await _load(showLoading: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppGradientHeader(
              overline: 'Store-in & Put-away',
              title: 'Nhập kho & xếp vị trí',
              subtitle: 'Xác nhận lô sau kiểm định và chọn khu/cột lưu trữ',
              leading: IconButton(
                tooltip: 'Quay lại',
                color: Colors.white,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              trailing: IconButton(
                color: Colors.white,
                tooltip: 'Làm mới',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => _load(showLoading: false),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _lines.isEmpty && _error == null) {
      return const ListSkeleton();
    }
    if (_error != null && _lines.isEmpty) {
      return HErrorState(
        message: 'Không tải được phiếu nhập kho: $_error',
        onRetry: _load,
      );
    }

    final lines = _pendingLines;
    return RefreshIndicator(
      onRefresh: () => _load(showLoading: false),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          AppSectionHeader(
            title: 'Lô chờ nhập kho (${lines.length})',
            icon: Icons.move_to_inbox_outlined,
          ),
          if (lines.isEmpty)
            const HEmptyState(
              title: 'Không có lô nào chờ nhập kho',
              description:
                  'Lô mới xuất hiện ở đây sau khi phiếu kiểm định được lưu kết quả.',
              icon: Icons.done_all_rounded,
            )
          else
            for (final line in lines) ...[
              _LineCard(line: line, onTap: () => _openLine(line)),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.line, required this.onTap});

  final InboundPutawayLine line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final item = line.item;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                  ),
                ),
              ),
              AppStatusChip(
                label: item.receiptStatus == 'PartiallyReceived'
                    ? 'Nhập một phần'
                    : 'Chờ nhập',
                tone: AppTone.info,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${formatKg(item.remainingKg)} còn lại',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            line.sourceLabel,
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondaryFor(context),
            ),
          ),
          const SizedBox(height: 8),
          // Wrap để hai chip tự xuống dòng trên máy hẹp / cỡ chữ lớn.
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              AppStatusChip(
                label: item.needsQuarantine ? 'QC: Cần cách ly' : 'QC: Đạt',
                tone: item.needsQuarantine ? AppTone.warning : AppTone.success,
                dense: true,
              ),
              AppStatusChip(
                label: line.order.statusName ?? line.order.normalizedStatus,
                tone: AppTone.neutral,
                dense: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

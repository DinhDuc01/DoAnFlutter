import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_reload_mixin.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/app_pagination.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/quality_inspection_repository.dart';
import '../../models/quality_inspection.dart';
import 'quality_inspection_detail_screen.dart';

/// Màn "Chất lượng & cách ly" — dựng lại theo đúng bản web:
/// banner + 4 ô KPI + tìm kiếm/lọc kết quả + danh sách lô rủi ro theo vị trí.
///
/// Khác web ở đúng một điểm: mobile KHÔNG có nút tạo phiếu kiểm định và nút
/// kiểm tra lại lô cách ly (hai luồng đó chỉ làm trên web). Mobile chỉ mở phiếu
/// để CẬP NHẬT kết quả kiểm định.
class QualityInspectionScreen extends StatefulWidget {
  const QualityInspectionScreen({this.repository, super.key});

  final QualityInspectionRepository? repository;

  @override
  State<QualityInspectionScreen> createState() =>
      _QualityInspectionScreenState();
}

class _QualityInspectionScreenState extends State<QualityInspectionScreen>
    with RealtimeReloadMixin {
  late final QualityInspectionRepository _repository;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  QualityInspectionPage _page = QualityInspectionPage.empty;
  Map<int, QualityLot> _lots = const <int, QualityLot>{};
  Object? _error;
  bool _loading = true;
  int _pageIndex = 1;
  int _pageSize = 10;
  bool? _passed;

  /// Lô đổi trạng thái khi kiểm định / nhập kho nên phải nghe cả hai entity.
  @override
  Set<String> get realtimeEntities => const {
        'QualityInspection',
        'PaddyLot',
        'PaddyLotBag',
        'InboundOrder',
      };

  @override
  void onRealtimeChanged() => _load(showLoading: false);

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiQualityInspectionRepository();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final page = await _repository.loadPage(
        page: _pageIndex,
        pageSize: _pageSize,
        search: _searchController.text.trim(),
        passedInspection: _passed,
      );
      final lots = await _loadLots();
      if (!mounted) return;
      setState(() {
        _page = page;
        _lots = lots;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      // Reload im lặng thất bại thì giữ nguyên dữ liệu đang xem.
      if (_page.items.isEmpty) {
        setState(() {
          _error = error;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    }
  }

  /// Bản đồ lô chỉ dùng để hiển thị (loại hàng/vị trí/tổng tồn) nên lỗi ở đây
  /// không được làm hỏng bảng phiếu kiểm định.
  Future<Map<int, QualityLot>> _loadLots() async {
    try {
      return await _repository.loadLotMap();
    } catch (_) {
      return _lots;
    }
  }

  void _onSearchChanged(String _) {
    setState(() {}); // hiện/ẩn nút xoá từ khoá ngay khi gõ
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _pageIndex = 1;
      _load(showLoading: false);
    });
  }

  Future<void> _openFilter() async {
    final result = await showModalBottomSheet<_ResultFilter>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Lọc theo kết quả',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            for (final option in _ResultFilter.values)
              ListTile(
                title: Text(option.label),
                trailing: option.value == _passed ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, option),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _passed = result.value;
      _pageIndex = 1;
    });
    _load(showLoading: false);
  }

  Future<void> _openPageSize() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Số phiếu mỗi trang',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            for (final size in const [10, 20, 50])
              ListTile(
                title: Text('$size / trang'),
                trailing: size == _pageSize ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, size),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _pageSize = result;
      _pageIndex = 1;
    });
    _load(showLoading: false);
  }

  Future<void> _openDetail(QualityInspection item) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => QualityInspectionDetailScreen(
          inspectionId: item.id,
          preview: item,
          repository: _repository,
        ),
      ),
    );
    if (changed == true && mounted) _load(showLoading: false);
  }

  int get _totalPages {
    final total = _page.recordsFiltered;
    if (total <= 0) return 1;
    return ((total + _pageSize - 1) ~/ _pageSize).clamp(1, 9999);
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
              overline: 'Quản lý chất lượng & cách ly lô',
              title: 'Chất lượng & cách ly',
              subtitle: 'Rủi ro theo mã lô · vị trí · số lượng ảnh hưởng',
              leading: IconButton(
                tooltip: 'Quay lại',
                color: Colors.white,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              trailing: IconButton(
                tooltip: 'Tải lại',
                color: Colors.white,
                onPressed: () => _load(showLoading: false),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _page.items.isEmpty && _error == null) {
      return const ListSkeleton();
    }
    if (_error != null && _page.items.isEmpty) {
      return HErrorState(
        message: 'Không tải được dữ liệu chất lượng: $_error',
        onRetry: _load,
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(showLoading: false),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          const AppInfoBanner(
            message:
                'Hệ thống không khóa toàn bộ lô ở mọi nơi. Khi phát hiện rủi ro, '
                'chỉ phần tồn bị ảnh hưởng tại vị trí cụ thể mới chuyển sang cách ly.',
            tone: AppTone.info,
          ),
          const SizedBox(height: 14),
          _searchRow(),
          const SizedBox(height: 12),
          if (_page.items.isEmpty)
            const HEmptyState(
              title: 'Chưa có phiếu kiểm định',
              description: 'Không có phiếu phù hợp với điều kiện hiện tại.',
              icon: Icons.science_outlined,
            )
          else ...[
            for (final item in _page.items) ...[
              _InspectionCard(
                item: item,
                lot: _lots[item.paddyLotId],
                onTap: () => _openDetail(item),
              ),
              const SizedBox(height: 10),
            ],
            AppPagination(
              page: _pageIndex,
              totalPages: _totalPages,
              total: _page.recordsFiltered,
              enabled: !_loading,
              onChanged: (value) {
                setState(() => _pageIndex = value);
                _load(showLoading: false);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _searchRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Tìm mã lô, người kiểm...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        _pageIndex = 1;
                        _load(showLoading: false);
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: 'Lọc kết quả',
          onPressed: _openFilter,
          icon: Icon(
            Icons.tune_rounded,
            color: _passed == null ? null : AppColors.primary,
          ),
        ),
        IconButton.outlined(
          tooltip: 'Số phiếu mỗi trang',
          onPressed: _openPageSize,
          icon: const Icon(Icons.format_list_numbered_rounded),
        ),
      ],
    );
  }
}

enum _ResultFilter {
  all('Tất cả kết quả', null),
  passed('Đạt', true),
  quarantine('Cách ly / Không đạt', false);

  const _ResultFilter(this.label, this.value);

  final String label;
  final bool? value;
}

/// Thẻ một phiếu kiểm định — gói đủ 6 cột của bảng web vào một thẻ mobile.
class _InspectionCard extends StatelessWidget {
  const _InspectionCard({
    required this.item,
    required this.lot,
    required this.onTap,
  });

  final QualityInspection item;
  final QualityLot? lot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.lotLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              AppStatusChip(
                label: item.statusText,
                tone: qualityStatusTone(item),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _row(context, 'Loại hàng', lot?.productVariantName ?? '—'),
          _row(context, 'Vị trí', lot?.locationLabel ?? '—'),
          _row(context, 'Số lượng', qualityAffectedMain(item, lot),
              sub: qualityAffectedSub(item, lot)),
          _row(context, 'Rủi ro chính', item.riskText),
          const SizedBox(height: 8),
          // Wrap thay cho Row + Spacer: máy hẹp hoặc cỡ chữ lớn thì chip và
          // thời gian tự xuống dòng thay vì tràn ngang.
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppStatusChip(
                label: 'Mức độ: ${item.severity.label}',
                tone: qualitySeverityTone(item.severity),
                dense: true,
              ),
              Text(
                formatDate(item.inspectedAt, withTime: true),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondaryFor(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {String? sub}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondaryFor(context),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryFor(context),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cột "SỐ LƯỢNG": kg bị ảnh hưởng nếu tách, ngược lại tồn của lô (như web).
String qualityAffectedMain(QualityInspection item, QualityLot? lot) {
  if ((item.affectedWeightKg ?? 0) > 0) return formatKg(item.affectedWeightKg);
  final basis = lot?.basisWeightKg;
  return basis == null ? '—' : formatKg(basis);
}

String qualityAffectedSub(QualityInspection item, QualityLot? lot) {
  final basis = lot?.basisWeightKg;
  if ((item.affectedWeightKg ?? 0) > 0) {
    return 'Tách • tổng lô ${basis == null ? '—' : formatKg(basis)}';
  }
  return item.passedInspection == true ? 'Toàn lô' : 'Toàn bộ lô';
}

AppTone qualityStatusTone(QualityInspection item) {
  if (item.isDraft) return AppTone.warning;
  return item.passedInspection == true ? AppTone.success : AppTone.danger;
}

AppTone qualitySeverityTone(QualitySeverity severity) {
  switch (severity) {
    case QualitySeverity.high:
      return AppTone.danger;
    case QualitySeverity.medium:
    case QualitySeverity.pending:
      return AppTone.warning;
    case QualitySeverity.low:
      return AppTone.success;
  }
}

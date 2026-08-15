import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_reload_mixin.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/quality_inspection_repository.dart';
import '../../models/quality_inspection.dart';
import 'quality_inspection_edit_screen.dart';
import 'quality_inspection_screen.dart'
    show
        qualityAffectedMain,
        qualityAffectedSub,
        qualitySeverityTone,
        qualityStatusTone;

/// Chi tiết xử lý một phiếu kiểm định + lịch sử kiểm tra của lô — khớp panel
/// bên phải của màn web. Nút hành động duy nhất là CẬP NHẬT phiếu (mobile không
/// tạo và không xóa phiếu kiểm định).
class QualityInspectionDetailScreen extends StatefulWidget {
  const QualityInspectionDetailScreen({
    required this.inspectionId,
    this.preview,
    this.repository,
    super.key,
  });

  final int inspectionId;

  /// Dòng đã có ở danh sách — hiện ngay trong lúc chờ API chi tiết.
  final QualityInspection? preview;
  final QualityInspectionRepository? repository;

  @override
  State<QualityInspectionDetailScreen> createState() =>
      _QualityInspectionDetailScreenState();
}

class _QualityInspectionDetailScreenState
    extends State<QualityInspectionDetailScreen> with RealtimeReloadMixin {
  late final QualityInspectionRepository _repository;

  QualityInspection? _detail;
  QualityLot? _lot;
  List<QualityInspection> _history = const <QualityInspection>[];
  Object? _error;
  bool _loading = true;
  bool _changed = false;

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
    _detail = widget.preview;
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
      final detail = await _repository.getDetail(widget.inspectionId);
      final lotId = detail.paddyLotId;
      final lot = lotId > 0 ? await _safeLot(lotId) : null;
      final history = lotId > 0 ? await _safeHistory(lotId) : const <QualityInspection>[];
      if (!mounted) return;
      setState(() {
        // Bảng paged không trả affectedWeightKg/lotStatusCode đầy đủ nên chi
        // tiết mới là nguồn hiển thị chuẩn; giữ lotStatusCode của dòng danh
        // sách khi API chi tiết không có.
        _detail = detail.lotStatusCode == null && widget.preview != null
            ? _withPreviewStatus(detail, widget.preview!)
            : detail;
        _lot = lot;
        _history = history;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_detail == null) _error = error;
      });
    }
  }

  QualityInspection _withPreviewStatus(
    QualityInspection detail,
    QualityInspection preview,
  ) =>
      QualityInspection(
        id: detail.id,
        paddyLotId: detail.paddyLotId,
        lotCode: detail.lotCode ?? preview.lotCode,
        lotStatusCode: preview.lotStatusCode,
        inspectorId: detail.inspectorId,
        inspectorName: detail.inspectorName,
        inspectedAt: detail.inspectedAt,
        moisturePercent: detail.moisturePercent,
        impurityPercent: detail.impurityPercent,
        moldLevel: detail.moldLevel,
        pestLevel: detail.pestLevel,
        packagingStatus: detail.packagingStatus,
        passedInspection: detail.passedInspection,
        handling: detail.handling,
        note: detail.note,
        affectedWeightKg: detail.affectedWeightKg,
        createdDate: detail.createdDate,
        lastModifiedDate: detail.lastModifiedDate,
      );

  Future<QualityLot?> _safeLot(int lotId) async {
    try {
      return await _repository.getLot(lotId);
    } catch (_) {
      return _lot;
    }
  }

  Future<List<QualityInspection>> _safeHistory(int lotId) async {
    try {
      return await _repository.getHistory(lotId);
    } catch (_) {
      return _history;
    }
  }

  Future<void> _openEdit() async {
    final detail = _detail;
    if (detail == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => QualityInspectionEditScreen(
          inspection: detail,
          lot: _lot,
          repository: _repository,
        ),
      ),
    );
    if (saved == true) {
      _changed = true;
      if (mounted) await _load(showLoading: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
        backgroundColor: AppColors.backgroundFor(context),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppGradientHeader(
                overline: 'Chi tiết xử lý',
                title: detail?.lotLabel ?? 'Phiếu kiểm định',
                subtitle: detail == null
                    ? 'Đang tải dữ liệu…'
                    : '${detail.statusText} · ${formatDate(detail.inspectedAt, withTime: true)}',
                leading: IconButton(
                  color: Colors.white,
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.of(context).pop(_changed),
                ),
                trailing: IconButton(
                  color: Colors.white,
                  tooltip: 'Tải lại',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => _load(showLoading: false),
                ),
              ),
              Expanded(child: _body(detail)),
            ],
          ),
        ),
        bottomNavigationBar: detail == null
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: _openEdit,
                  icon: const Icon(Icons.fact_check_outlined),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  label: Text(
                    detail.isDraft ? 'Kiểm định ngay' : 'Cập nhật phiếu',
                  ),
                ),
              ),
    );
  }

  Widget _body(QualityInspection? detail) {
    if (detail == null) {
      if (_error != null) {
        return HErrorState(
          message: 'Không tải được chi tiết phiếu: $_error',
          onRetry: _load,
        );
      }
      return const FormSkeleton();
    }

    return RefreshIndicator(
      onRefresh: () => _load(showLoading: false),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          _section('Thông tin lô', [
            _field('Mã lô', detail.lotLabel),
            _field('Loại hàng', _lot?.productVariantName ?? '—'),
            _field('Vị trí', _lot?.locationLabel ?? '—'),
            _field(
              'Tổng tồn của lô',
              _lot?.basisWeightKg == null ? '—' : formatKg(_lot!.basisWeightKg),
            ),
            _field('Số lượng ảnh hưởng', qualityAffectedMain(detail, _lot),
                sub: qualityAffectedSub(detail, _lot)),
            _field('Phạm vi xử lý', detail.scopeText),
          ]),
          _section('Kết quả kiểm định', [
            _field('Độ ẩm', _percent(detail.moisturePercent)),
            _field('Tạp chất', _percent(detail.impurityPercent)),
            _field(
              'Mốc / Sâu mọt',
              '${_dash(detail.moldLevel)} / ${_dash(detail.pestLevel)}',
            ),
            _field('Đóng gói', _dash(detail.packagingStatus)),
            _field('Rủi ro chính', detail.riskText),
            _chipField('Mức độ', detail.severity.label,
                qualitySeverityTone(detail.severity)),
            _chipField('Trạng thái', detail.statusText, qualityStatusTone(detail)),
            _field('Hướng xử lý', _dash(detail.handling)),
            _field('Ghi chú', _dash(detail.note)),
          ]),
          _section('Thông tin thực hiện', [
            _field('Người kiểm', _dash(detail.inspectorName)),
            _field('Thời gian kiểm', formatDate(detail.inspectedAt, withTime: true)),
            _field('Ngày tạo', formatDate(detail.createdDate, withTime: true)),
            _field('Cập nhật', formatDate(detail.lastModifiedDate, withTime: true)),
          ]),
          if (detail.wasSplit)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: AppInfoBanner(
                message:
                    'Phiếu này đã tách lô cách ly — không thể đổi lô, kết quả hay '
                    'khối lượng ảnh hưởng.',
              ),
            ),
          _historyCard(),
        ],
      ),
    );
  }

  Widget _historyCard() {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'Lịch sử kiểm tra',
            icon: Icons.history_rounded,
          ),
          if (_history.isEmpty)
            Text(
              'Chưa có lịch sử kiểm tra cho lô này',
              style: TextStyle(color: AppColors.textSecondaryFor(context)),
            )
          else
            for (final record in _history)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      record.passedInspection == true
                          ? Icons.check_circle_outline_rounded
                          : Icons.warning_amber_rounded,
                      size: 18,
                      color: record.passedInspection == true
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${record.lotLabel} · ${record.passedInspection == true ? 'Đạt' : 'Cách ly'}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${_dash(record.handling, fallback: 'Chưa xử lý')}'
                            '${record.packagingStatus == null ? '' : ' · Bao ${record.packagingStatus}'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            '${_dash(record.inspectorName, fallback: 'N/A')} · '
                            '${formatDate(record.inspectedAt, withTime: true)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondaryFor(context),
                            ),
                          ),
                          if ((record.note ?? '').trim().isNotEmpty)
                            Text(
                              record.note!.trim(),
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => AppCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(title: title),
            ...children,
          ],
        ),
      );

  Widget _field(String label, String value, {String? sub}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 132,
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
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (sub != null)
                    Text(
                      sub,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondaryFor(context),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _chipField(String label, String value, AppTone tone) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 132,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondaryFor(context),
                ),
              ),
            ),
            AppStatusChip(label: value, tone: tone, dense: true),
          ],
        ),
      );
}

String _dash(String? value, {String fallback = '—'}) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? fallback : trimmed;
}

String _percent(double? value) =>
    value == null ? '—' : '${formatNumber(value, digits: 2)}%';

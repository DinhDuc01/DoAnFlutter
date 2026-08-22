import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../auth/data/auth_session_store.dart';
import '../../data/quality_inspection_repository.dart';
import '../../models/quality_inspection.dart';

/// Cập nhật phiếu kiểm định — bám đúng modal "Phiếu kiểm tra chất lượng" của web:
/// 1. Lô được kiểm tra & phạm vi ảnh hưởng (chọn bao cần tách sang cách ly)
/// 2. Chỉ số kiểm định
/// 3. Đánh giá & quyết định (người kiểm luôn là người đang sửa phiếu)
///
/// Hai nút lưu quyết định kết quả giống web: "Lưu & cách ly lô" (không đạt) và
/// "Lưu & duyệt đạt". Sau khi lưu, backend tự sinh phiếu nhập kho nên màn này
/// mời người dùng sang thẳng màn Nhập kho.
class QualityInspectionEditScreen extends StatefulWidget {
  const QualityInspectionEditScreen({
    required this.inspection,
    this.lot,
    this.repository,
    super.key,
  });

  final QualityInspection inspection;
  final QualityLot? lot;
  final QualityInspectionRepository? repository;

  @override
  State<QualityInspectionEditScreen> createState() =>
      _QualityInspectionEditScreenState();
}

class _QualityInspectionEditScreenState
    extends State<QualityInspectionEditScreen> {
  late final QualityInspectionRepository _repository;

  final _moistureController = TextEditingController();
  final _impurityController = TextEditingController();
  final _noteController = TextEditingController();

  String? _moldLevel;
  String? _pestLevel;
  String? _packagingStatus;
  String? _handling;
  late DateTime _inspectedAt;
  final Set<int> _affectedBagIds = <int>{};

  QualityLot? _lot;
  bool _loadingLot = false;
  bool _confirming = false;
  bool _saving = false;
  String? _error;

  bool get _canUpdate =>
      AuthSessionStore.current?.hasPermission(
        'QUALITY_INSPECTIONS',
        'UPDATE',
      ) ==
      true;

  bool get _canEditDraft => _canUpdate && widget.inspection.isDraft;
  bool get _busy => _confirming || _saving;

  /// Phiếu đã tách lô cách ly — backend khóa lô/kết quả/kg (giống web).
  bool get _lockedSplit => widget.inspection.wasSplit;

  List<QualityLotBag> get _bags => _lot?.bags ?? const <QualityLotBag>[];

  /// Chỉ bao đang chờ nhập mới tách cách ly được (khớp validate backend).
  bool _isSelectable(QualityLotBag bag) =>
      (bag.status ?? 'Pending').toLowerCase() == 'pending';

  double get _selectedBagWeightKg => _bags
      .where((bag) => _affectedBagIds.contains(bag.id))
      .fold<double>(0, (sum, bag) => sum + bag.weightKg);

  double get _totalBagWeightKg =>
      _bags.fold<double>(0, (sum, bag) => sum + bag.weightKg);

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiQualityInspectionRepository();
    _lot = widget.lot;
    final inspection = widget.inspection;
    _moistureController.text = inspection.moisturePercent == null
        ? ''
        : formatQuantityInput(inspection.moisturePercent, digits: 2);
    _impurityController.text = inspection.impurityPercent == null
        ? ''
        : formatQuantityInput(inspection.impurityPercent, digits: 2);
    _noteController.text = inspection.note ?? '';
    _moldLevel = _oneOf(inspection.moldLevel, QualityVocab.mold);
    _pestLevel = _oneOf(inspection.pestLevel, QualityVocab.pest);
    _packagingStatus =
        _oneOf(inspection.packagingStatus, QualityVocab.packaging);
    _handling = _oneOf(inspection.handling, QualityVocab.handling);
    _inspectedAt = inspection.inspectedAt ?? DateTime.now();
    if (_lot == null && inspection.paddyLotId > 0) _loadLot();
  }

  @override
  void dispose() {
    _moistureController.dispose();
    _impurityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Giá trị cũ không nằm trong danh mục thì bỏ, tránh dropdown crash.
  String? _oneOf(String? value, List<String> options) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return options.contains(trimmed) ? trimmed : null;
  }

  Future<void> _loadLot() async {
    setState(() => _loadingLot = true);
    try {
      final lot = await _repository.getLot(widget.inspection.paddyLotId);
      if (!mounted) return;
      setState(() {
        _lot = lot;
        _loadingLot = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingLot = false);
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _inspectedAt,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_inspectedAt),
    );
    if (!mounted) return;
    setState(() {
      _inspectedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _inspectedAt.hour,
        time?.minute ?? _inspectedAt.minute,
      );
    });
  }

  /// [passed] = true khi bấm "Lưu & duyệt đạt", false khi "Lưu & cách ly lô".
  Future<void> _save(bool passed) async {
    // A direct route must not bypass the detail CTA guard.
    if (_busy || !_canEditDraft) return;
    FocusScope.of(context).unfocus();

    // Phiếu đã tách cách ly: giữ nguyên kết quả và kg đã tách, backend từ chối
    // mọi thay đổi hai trường này.
    final effectivePassed = _lockedSplit ? false : passed;
    final affectedBagIds = _lockedSplit
        ? const <int>[]
        : (effectivePassed ? const <int>[] : _affectedBagIds.toList());
    double? affectedWeightKg;
    if (_lockedSplit) {
      affectedWeightKg = widget.inspection.affectedWeightKg;
    } else if (affectedBagIds.isNotEmpty) {
      affectedWeightKg = _selectedBagWeightKg;
    }

    if (affectedWeightKg != null && !_lockedSplit) {
      if (affectedWeightKg <= 0) {
        _showError('Khối lượng ảnh hưởng phải lớn hơn 0.');
        return;
      }
      final basis = _lot?.basisWeightKg;
      if (basis != null && affectedWeightKg >= basis) {
        _showError(
          'Khối lượng ảnh hưởng (${formatKg(affectedWeightKg)}) phải nhỏ hơn '
          'khối lượng của lô (${formatKg(basis)}). Bỏ chọn hết bao nếu muốn '
          'cách ly toàn bộ lô.',
        );
        return;
      }
    }

    setState(() => _confirming = true);
    final confirmed = await _confirm(effectivePassed, affectedWeightKg);
    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _confirming = false);
      return;
    }

    setState(() {
      _confirming = false;
      _saving = true;
      _error = null;
    });
    try {
      await _repository.update(
        QualityInspectionUpdate(
          id: widget.inspection.id,
          paddyLotId: widget.inspection.paddyLotId,
          // Người kiểm định luôn là người đang sửa phiếu — giống web.
          inspectorId: AuthSessionStore.current?.user.id,
          inspectedAt: _inspectedAt,
          passedInspection: effectivePassed,
          moisturePercent: parseDecimal(_moistureController.text),
          impurityPercent: parseDecimal(_impurityController.text),
          moldLevel: _moldLevel,
          pestLevel: _pestLevel,
          packagingStatus: _packagingStatus,
          handling: _handling,
          note: _noteController.text,
          affectedWeightKg: affectedWeightKg,
          affectedBagIds: affectedBagIds,
        ),
      );
      if (!mounted) return;
      // Giữ Navigator lại trước khi đóng màn: sau khi pop thì context của màn
      // này không dùng để điều hướng được nữa.
      final navigator = Navigator.of(context);
      final goInbound = await _askGoInbound();
      if (!mounted) return;
      navigator.pop(true);
      if (goInbound == true) navigator.pushNamed(AppRoutes.inboundPutaway);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$error';
      });
    }
  }

  Future<bool?> _confirm(bool passed, double? affectedWeightKg) {
    final isSplit = !passed && (affectedWeightKg ?? 0) > 0;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          passed
              ? 'Duyệt đạt lô này?'
              : isSplit
                  ? 'Tách một phần sang cách ly?'
                  : 'Cách ly toàn bộ lô này?',
        ),
        content: Text(
          passed
              ? 'Lô sẽ được ghi nhận ĐẠT chất lượng và hệ thống tạo phiếu nhập kho.'
              : isSplit
                  ? 'Tách ${formatKg(affectedWeightKg)} sang lô cách ly, phần còn lại giữ nguyên trạng thái.'
                  : 'Toàn bộ lô sẽ chuyển sang CÁCH LY.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor:
                  passed ? AppColors.primaryDark : AppColors.warning,
            ),
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );
  }

  /// Sau khi lưu, backend đã sinh phiếu nhập kho — mời người dùng sang thẳng
  /// màn Nhập kho như web.
  Future<bool?> _askGoInbound() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đã lưu phiếu kiểm định'),
        content: const Text(
          'Hệ thống đã tạo phiếu nhập kho cho lô này. Sang màn Nhập kho để xếp vị trí.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sang Nhập kho'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    setState(() => _error = message);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_canEditDraft) {
      return Scaffold(
        backgroundColor: AppColors.backgroundFor(context),
        appBar: AppBar(title: const Text('Chất lượng & cách ly')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              !_canUpdate
                  ? 'Bạn không có quyền cập nhật phiếu kiểm định.'
                  : 'Phiếu này không còn ở trạng thái chờ kiểm định và chỉ được phép xem.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final lot = _lot;
    // Đã chọn bao để tách thì chỉ còn đường "cách ly một phần" — giống web ẩn
    // nút duyệt đạt khi có bao được chọn.
    final canApprove = !_lockedSplit && _affectedBagIds.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppGradientHeader(
              overline: 'Lô + Chỉ số + Quyết định',
              title: 'Cập nhật phiếu kiểm tra',
              subtitle: widget.inspection.lotLabel,
              leading: IconButton(
                color: Colors.white,
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed:
                    _busy ? null : () => Navigator.of(context).pop(false),
              ),
            ),
            Expanded(
              child: _loadingLot && lot == null
                  ? const FormSkeleton()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      children: [
                        if (_lockedSplit)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: AppInfoBanner(
                              message:
                                  'Phiếu này đã tách lô cách ly — không thể đổi lô, '
                                  'kết quả hay khối lượng ảnh hưởng. Chỉ cập nhật '
                                  'được chỉ số, hướng xử lý và ghi chú.',
                            ),
                          ),
                        _lotSection(lot),
                        _metricsSection(),
                        _decisionSection(),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 8),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: AppColors.danger),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('quality_inspection_save_failed'),
                onPressed: _busy ? null : () => _save(false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: AppColors.warning,
                  side: const BorderSide(color: AppColors.warning),
                ),
                child: Text(_saving ? 'Đang lưu...' : 'Lưu & cách ly lô'),
              ),
            ),
            if (canApprove) ...[
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  key: const Key('quality_inspection_save_passed'),
                  onPressed: _busy ? null : () => _save(true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(_saving ? 'Đang lưu...' : 'Lưu & duyệt đạt'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lotSection(QualityLot? lot) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: '1. Lô được kiểm tra & phạm vi ảnh hưởng',
            icon: Icons.inventory_2_outlined,
          ),
          _readonly('Mã lô', widget.inspection.lotLabel),
          _readonly('Loại hàng', lot?.productVariantName ?? '—'),
          _readonly('Vị trí', lot?.locationLabel ?? '—'),
          _readonly(
            'Tổng tồn của lô',
            lot?.basisWeightKg == null ? '—' : formatKg(lot!.basisWeightKg),
          ),
          const SizedBox(height: 10),
          if (_lockedSplit)
            Text(
              'Đã tách ${formatKg(widget.inspection.affectedWeightKg)}. '
              'Danh sách bao được khóa theo lịch sử kiểm định.',
              style: TextStyle(color: AppColors.textSecondaryFor(context)),
            )
          else if (_bags.isEmpty)
            Text(
              'Lô chưa có dữ liệu bao hợp lệ. Không thể tách cách ly một phần; '
              'chỉ có thể duyệt đạt hoặc cách ly toàn bộ lô.',
              style: TextStyle(color: AppColors.textSecondaryFor(context)),
            )
          else ...[
            const Text(
              'Chọn bao cần tách sang cách ly',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Toàn lô: ${_bags.length} bao / ${formatKg(_totalBagWeightKg)}\n'
              'Cách ly: ${_affectedBagIds.length} bao / ${formatKg(_selectedBagWeightKg)}\n'
              'Còn lại: ${_bags.length - _affectedBagIds.length} bao / '
              '${formatKg((_totalBagWeightKg - _selectedBagWeightKg).clamp(0, double.infinity))}',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondaryFor(context),
              ),
            ),
            const SizedBox(height: 4),
            for (final bag in _bags)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _affectedBagIds.contains(bag.id),
                title: Text('Bao #${bag.bagNo} · ${formatKg(bag.weightKg)}'),
                subtitle: _isSelectable(bag)
                    ? null
                    : Text('Không tách được: ${bag.status}'),
                onChanged: _saving || !_isSelectable(bag)
                    ? null
                    : (checked) => setState(() {
                          if (checked == true) {
                            _affectedBagIds.add(bag.id);
                          } else {
                            _affectedBagIds.remove(bag.id);
                          }
                        }),
              ),
            Text(
              'Chọn một số bao để tách lô. Không chọn bao nào nếu muốn cách ly '
              'toàn bộ lô.',
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

  Widget _metricsSection() {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: '2. Chỉ số kiểm định',
            icon: Icons.science_outlined,
          ),
          TextField(
            controller: _moistureController,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Độ ẩm (%)',
              hintText: 'VD: 14.5',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _impurityController,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Tạp chất (%)',
              hintText: 'VD: 2.0',
            ),
          ),
          const SizedBox(height: 12),
          _dropdown(
            label: 'Tình trạng đóng gói',
            value: _packagingStatus,
            options: QualityVocab.packaging,
            onChanged: (value) => setState(() => _packagingStatus = value),
          ),
        ],
      ),
    );
  }

  Widget _decisionSection() {
    final inspector = AuthSessionStore.current?.user.fullName;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: '3. Đánh giá & quyết định',
            icon: Icons.rule_rounded,
          ),
          _dropdown(
            label: 'Mức độ mốc',
            value: _moldLevel,
            options: QualityVocab.mold,
            onChanged: (value) => setState(() => _moldLevel = value),
          ),
          const SizedBox(height: 12),
          _dropdown(
            label: 'Mức độ sâu mọt',
            value: _pestLevel,
            options: QualityVocab.pest,
            onChanged: (value) => setState(() => _pestLevel = value),
          ),
          const SizedBox(height: 12),
          _dropdown(
            label: 'Hướng xử lý',
            value: _handling,
            options: QualityVocab.handling,
            onChanged: (value) => setState(() => _handling = value),
          ),
          const SizedBox(height: 12),
          _readonly(
            'Người kiểm',
            (inspector == null || inspector.trim().isEmpty)
                ? 'Người đang đăng nhập'
                : inspector,
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _saving ? null : _pickDateTime,
            icon: const Icon(Icons.event_rounded),
            label:
                Text('Ngày kiểm: ${formatDate(_inspectedAt, withTime: true)}'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            enabled: !_saving,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Ghi chú',
              hintText: 'Lý do tách một phần, điều kiện mở khóa...',
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      hint: const Text('— Không đánh giá —'),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('— Không đánh giá —'),
        ),
        for (final option in options)
          DropdownMenuItem<String?>(value: option, child: Text(option)),
      ],
      onChanged: _saving ? null : onChanged,
    );
  }

  Widget _readonly(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 126,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondaryFor(context),
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}

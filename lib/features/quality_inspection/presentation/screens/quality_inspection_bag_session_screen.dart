import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../auth/data/auth_session_store.dart';
import '../../data/quality_inspection_repository.dart';
import '../../models/quality_inspection.dart';

class QualityInspectionBagSessionScreen extends StatefulWidget {
  const QualityInspectionBagSessionScreen({
    required this.inspectionId,
    required this.repository,
    this.title,
    super.key,
  });

  final int inspectionId;
  final QualityInspectionRepository repository;
  final String? title;

  @override
  State<QualityInspectionBagSessionScreen> createState() =>
      _QualityInspectionBagSessionScreenState();
}

class _QualityInspectionBagSessionScreenState
    extends State<QualityInspectionBagSessionScreen> {
  QualityInspectionBagProgress? _progress;
  Object? _error;
  bool _loading = true;
  bool _saving = false;
  bool _completing = false;
  bool _changed = false;
  final _completionNote = TextEditingController();

  QualityInspectionBagRepository get _bagRepository {
    final repository = widget.repository;
    if (repository is QualityInspectionBagRepository) {
      return repository as QualityInspectionBagRepository;
    }
    throw UnsupportedError(
      'Repository chưa hỗ trợ kiểm định theo từng bao.',
    );
  }

  bool get _canUpdate =>
      AuthSessionStore.current?.user.hasRole('PURCHASING') == true &&
      AuthSessionStore.current?.hasPermission(
        'QUALITY_INSPECTIONS',
        'UPDATE',
      ) ==
      true;

  bool get _canApprove =>
      AuthSessionStore.current?.user.hasRole('PURCHASING') == true &&
      AuthSessionStore.current?.hasPermission(
        'QUALITY_INSPECTIONS',
        'APPROVE',
      ) ==
      true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _completionNote.dispose();
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
      final progress = await _bagRepository.getBagProgress(
        widget.inspectionId,
      );
      if (!mounted) return;
      setState(() {
        _progress = progress;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _editBag(QualityInspectionBagResult bag) async {
    final progress = _progress;
    if (progress == null || _saving) {
      return;
    }
    final readOnly = progress.isCompleted || !_canUpdate;
    final payload = await showModalBottomSheet<SaveBagInspectionResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BagResultForm(
        bag: bag,
        inspectionType: progress.inspectionType,
        readOnly: readOnly,
      ),
    );
    if (readOnly || payload == null || !mounted || _saving) return;
    setState(() => _saving = true);
    try {
      await _bagRepository.saveBagResult(
        widget.inspectionId,
        bag.bagId,
        payload,
      );
      _changed = true;
      await _load(showLoading: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã lưu kết quả bao #${bag.bagNo}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không lưu được kết quả: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _complete() async {
    // Chỉ hoàn tất khi toàn bộ bao đã lưu kết quả. Sau mutation phải tải lại
    // và xác minh Backend thật sự trả trạng thái completed, không success giả.
    final progress = _progress;
    if (progress == null ||
        progress.isCompleted ||
        progress.remainingBags != 0 ||
        !_canApprove ||
        _completing) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hoàn tất phiên kiểm định?'),
        content: const Text(
          'Tất cả bao đã có kết quả. Sau khi hoàn tất, phiên sẽ chuyển sang chế độ chỉ xem.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hoàn tất'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _completing) return;
    setState(() => _completing = true);
    try {
      await _bagRepository.completeBagInspection(
        widget.inspectionId,
        note: _completionNote.text.trim(),
      );
      _changed = true;
      await _load(showLoading: false);
      if (mounted && _progress?.isCompleted != true) {
        throw StateError('Backend chưa xác nhận phiên đã hoàn tất.');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không hoàn tất được phiên: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final readyToComplete = progress != null &&
        !progress.isCompleted &&
        progress.totalBags > 0 &&
        progress.remainingBags == 0 &&
        progress.inspectedBags >= progress.totalBags;
    return Scaffold(
      key: const Key('quality_bag_session_screen'),
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppGradientHeader(
              overline: 'Chất lượng & cách ly',
              title: widget.title ?? progress?.lotCode ?? 'Kiểm tra từng bao',
              subtitle: progress == null
                  ? 'Đang tải dữ liệu…'
                  : '${progress.inspectedBags}/${progress.totalBags} bao đã kiểm',
              leading: IconButton(
                color: Colors.white,
                onPressed: () => Navigator.pop(context, _changed),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              trailing: IconButton(
                color: Colors.white,
                onPressed: () => _load(showLoading: false),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            Expanded(child: _body(progress)),
          ],
        ),
      ),
      bottomNavigationBar: readyToComplete
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_canApprove)
                    const AppInfoBanner(
                      message:
                          'Tất cả bao đã được cập nhật. Cần quyền Duyệt để hoàn tất phiếu.',
                    ),
                  if (_canApprove)
                    TextField(
                      controller: _completionNote,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                      labelText: 'Ghi chú hoàn tất',
                      hintText:
                          'Ghi chú chung cho phiên kiểm tra (không bắt buộc)',
                        counterText: '',
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('quality_bag_complete'),
                      onPressed:
                          !_canApprove || _completing ? null : _complete,
                      icon: _completing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.task_alt_rounded),
                      label: const Text('Hoàn tất phiếu'),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _body(QualityInspectionBagProgress? progress) {
    if (_loading && progress == null) return const FormSkeleton();
    if (_error != null && progress == null) {
      return HErrorState(
          message: 'Không tải được danh sách bao: $_error', onRetry: _load);
    }
    if (progress == null) return const SizedBox.shrink();
    return RefreshIndicator(
      onRefresh: () => _load(showLoading: false),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionHeader(
                  title: 'Tiến độ kiểm định',
                  icon: Icons.fact_check_outlined,
                ),
                LinearProgressIndicator(
                  value: progress.totalBags == 0
                      ? 0
                      : progress.inspectedBags / progress.totalBags,
                ),
                const SizedBox(height: 10),
                Text(
                  '${progress.inspectedBags}/${progress.totalBags} bao đã kiểm tra · Còn ${progress.remainingBags} bao',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _counterChip(
                        'Bình thường', progress.normalBags, AppTone.success),
                    _counterChip(
                        'Cách ly', progress.quarantineBags, AppTone.warning),
                    _counterChip(
                        'Từ chối', progress.rejectedBags, AppTone.danger),
                    _counterChip(
                        'Giải phóng', progress.releasedBags, AppTone.info),
                  ],
                ),
                if (progress.isCompleted)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: AppInfoBanner(
                      message: 'Phiên đã hoàn tất và hiện chỉ có thể xem.',
                    ),
                  ),
              ],
            ),
          ),
          if (progress.items.isEmpty)
            const AppCard(child: Text('Phiên này chưa có bao cần kiểm tra.'))
          else
            for (final bag in progress.items) _bagCard(progress, bag),
        ],
      ),
    );
  }

  Widget _counterChip(String label, int count, AppTone tone) =>
      AppStatusChip(label: '$label $count', tone: tone, dense: true);

  Widget _bagCard(
    QualityInspectionBagProgress progress,
    QualityInspectionBagResult bag,
  ) {
    final editable = _canUpdate && !progress.isCompleted && !_saving;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bao #${bag.bagNo} · ${formatKg(bag.weightKg)}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              AppStatusChip(
                label: bag.isInspected ? 'Đã kiểm' : 'Chưa kiểm',
                tone: bag.isInspected ? AppTone.success : AppTone.warning,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Vị trí: ${bag.locationCode ?? '—'}'),
          Text('Kết quả: ${_qualityResultLabel(bag.qualityResult)}'),
          Text('Xử lý: ${_dispositionLabel(bag.disposition)}'),
          if (bag.inspectedAt != null)
            Text(
              'Lưu lúc ${formatDate(bag.inspectedAt, withTime: true)}'
              '${(bag.inspectorName ?? '').trim().isEmpty ? '' : ' · ${bag.inspectorName}'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if ((bag.note ?? '').trim().isNotEmpty) Text('Ghi chú: ${bag.note}'),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              key: Key('quality_bag_edit_${bag.bagId}'),
              onPressed: _saving ? null : () => _editBag(bag),
              icon: Icon(
                  editable ? Icons.edit_outlined : Icons.visibility_outlined),
              label: Text(
                editable
                    ? (bag.isInspected ? 'Cập nhật' : 'Nhập kết quả')
                    : 'Xem chi tiết',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BagResultForm extends StatefulWidget {
  const _BagResultForm({
    required this.bag,
    required this.readOnly,
    this.inspectionType,
  });

  final QualityInspectionBagResult bag;
  final String? inspectionType;
  final bool readOnly;

  @override
  State<_BagResultForm> createState() => _BagResultFormState();
}

class _BagResultFormState extends State<_BagResultForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _moisture;
  late final TextEditingController _impurity;
  late final TextEditingController _handling;
  late final TextEditingController _note;
  late String _qualityResult;
  late String _disposition;
  String? _mold;
  String? _pest;
  String? _packaging;

  @override
  void initState() {
    super.initState();
    _moisture =
        TextEditingController(text: _number(widget.bag.moisturePercent));
    _impurity =
        TextEditingController(text: _number(widget.bag.impurityPercent));
    _handling = TextEditingController(text: widget.bag.handling ?? '');
    _note = TextEditingController(text: widget.bag.note ?? '');
    _qualityResult = widget.bag.qualityResult ?? 'PASS';
    _disposition =
        widget.bag.disposition ?? _defaultDisposition(_qualityResult);
    _mold = widget.bag.moldLevel;
    _pest = widget.bag.pestLevel;
    _packaging = widget.bag.packagingStatus;
  }

  @override
  void dispose() {
    _moisture.dispose();
    _impurity.dispose();
    _handling.dispose();
    _note.dispose();
    super.dispose();
  }

  String _defaultDisposition(String result) {
    final type = (widget.inspectionType ?? '').toUpperCase();
    if (result == 'PASS') {
      return type == 'RECEIVING'
          ? 'ACCEPT_NORMAL'
          : type == 'STORAGE'
              ? 'KEEP_STORED'
              : 'RELEASE';
    }
    if (type == 'RECEIVING') return 'ACCEPT_QUARANTINE';
    if (type == 'RECHECK') return 'KEEP_QUARANTINE';
    return 'QUARANTINE';
  }

  List<String> get _dispositions {
    final type = (widget.inspectionType ?? '').toUpperCase();
    if (type == 'RECEIVING') {
      return _qualityResult == 'PASS'
          ? const ['ACCEPT_NORMAL']
          : const ['ACCEPT_QUARANTINE', 'REJECT_RETURN'];
    }
    if (type == 'STORAGE') {
      return _qualityResult == 'PASS'
          ? const ['KEEP_STORED']
          : const ['QUARANTINE'];
    }
    if (type == 'RECHECK') {
      return _qualityResult == 'PASS'
          ? const ['RELEASE']
          : const ['KEEP_QUARANTINE'];
    }
    return _qualityResult == 'PASS' ? const ['RELEASE'] : const ['QUARANTINE'];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .92,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundFor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Kiểm tra chất lượng bao #${widget.bag.bagNo}',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatKg(widget.bag.weightKg)} · ${widget.bag.locationCode ?? 'Chưa có vị trí'} · ${_bagStatusLabel(widget.bag.status)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (widget.bag.inspectedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Đã lưu ${formatDate(widget.bag.inspectedAt, withTime: true)}'
                    '${(widget.bag.inspectorName ?? '').trim().isEmpty ? '' : ' · ${widget.bag.inspectorName}'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 14),
                const Text('Kết quả *',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: _resultButton(
                        value: 'PASS',
                        label: 'Đạt yêu cầu',
                        icon: Icons.check_circle_outline_rounded,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _resultButton(
                        value: 'ISSUE_DETECTED',
                        label: 'Có vấn đề',
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: ValueKey('quality_bag_disposition_$_qualityResult'),
                  initialValue: _dispositions.contains(_disposition)
                      ? _disposition
                      : _dispositions.first,
                  decoration:
                      const InputDecoration(labelText: 'Quyết định xử lý *'),
                  items: [
                    for (final value in _dispositions)
                      DropdownMenuItem(
                          value: value, child: Text(_dispositionLabel(value))),
                  ],
                  onChanged: widget.readOnly
                      ? null
                      : (value) => setState(
                            () => _disposition = value ?? _dispositions.first,
                          ),
                ),
                if (widget.bag.isInspected) ...[
                  const SizedBox(height: 10),
                  InputDecorator(
                    decoration:
                        const InputDecoration(labelText: 'Trạng thái đã lưu'),
                    child: Text(_dispositionLabel(widget.bag.disposition)),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _percentField(_moisture, 'Độ ẩm %')),
                    const SizedBox(width: 10),
                    Expanded(child: _percentField(_impurity, 'Tạp chất %')),
                  ],
                ),
                const SizedBox(height: 10),
                _option('Mức độ mốc', _mold, const ['Không', 'Nhẹ', 'Nặng'],
                    (v) => _mold = v),
                const SizedBox(height: 10),
                _option(
                    'Mức độ sâu mọt',
                    _pest,
                    const ['Không', 'Có dấu hiệu', 'Cần xử lý'],
                    (v) => _pest = v),
                const SizedBox(height: 10),
                _option('Đóng gói', _packaging, const ['Nguyên', 'Rách', 'Ẩm'],
                    (v) => _packaging = v),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: const [
                    'Phơi',
                    'Sấy',
                    'Đảo kho',
                    'Cách ly',
                    'Bán nhanh'
                  ].contains(_handling.text)
                      ? _handling.text
                      : null,
                  decoration:
                      const InputDecoration(labelText: 'Hướng xử lý bổ sung'),
                  items: const [
                    DropdownMenuItem(value: 'Phơi', child: Text('Phơi')),
                    DropdownMenuItem(value: 'Sấy', child: Text('Sấy')),
                    DropdownMenuItem(value: 'Đảo kho', child: Text('Đảo kho')),
                    DropdownMenuItem(value: 'Cách ly', child: Text('Cách ly')),
                    DropdownMenuItem(
                        value: 'Bán nhanh', child: Text('Bán nhanh')),
                  ],
                  onChanged: widget.readOnly
                      ? null
                      : (value) => _handling.text = value ?? '',
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('quality_bag_note'),
                  controller: _note,
                  enabled: !widget.readOnly,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: _disposition == 'REJECT_RETURN'
                        ? 'Ghi chú bao *'
                        : 'Ghi chú bao',
                    hintText: _disposition == 'REJECT_RETURN'
                        ? 'Bắt buộc nhập lý do trả nhà cung cấp…'
                        : 'Mô tả dấu hiệu, mẫu đo hoặc lý do xử lý…',
                  ),
                  validator: (value) => _disposition == 'REJECT_RETURN' &&
                          (value ?? '').trim().isEmpty
                      ? 'Cần nhập lý do trả lại'
                      : null,
                ),
                if (!widget.readOnly) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('quality_bag_save'),
                    onPressed: _submit,
                    child: const Text('Lưu bao này'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultButton({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final selected = _qualityResult == value;
    return OutlinedButton.icon(
      key: Key('quality_bag_result_$value'),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: selected ? color.withValues(alpha: .10) : null,
        side: BorderSide(color: selected ? color : AppColors.border),
        minimumSize: const Size(0, 52),
      ),
      onPressed: widget.readOnly
          ? null
          : () => setState(() {
                _qualityResult = value;
                _disposition = _defaultDisposition(value);
              }),
      icon: Icon(icon, size: 18),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _percentField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        enabled: !widget.readOnly,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          if ((value ?? '').trim().isEmpty) return null;
          final parsed = double.tryParse(value!.replaceAll(',', '.'));
          return parsed == null ||
                  !parsed.isFinite ||
                  parsed < 0 ||
                  parsed > 100
              ? 'Nhập từ 0 đến 100'
              : null;
        },
      );

  Widget _option(
    String label,
    String? value,
    List<String> values,
    ValueChanged<String?> changed,
  ) =>
      DropdownButtonFormField<String>(
        initialValue: values.contains(value) ? value : null,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final item in values)
            DropdownMenuItem(value: item, child: Text(item))
        ],
        onChanged: widget.readOnly ? null : changed,
      );

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.pop(
      context,
      SaveBagInspectionResult(
        bagId: widget.bag.bagId,
        qualityResult: _qualityResult,
        disposition: _disposition,
        moisturePercent: _parse(_moisture.text),
        impurityPercent: _parse(_impurity.text),
        moldLevel: _mold,
        pestLevel: _pest,
        packagingStatus: _packaging,
        handling: _handling.text,
        note: _note.text,
      ),
    );
  }
}

double? _parse(String value) =>
    value.trim().isEmpty ? null : double.tryParse(value.replaceAll(',', '.'));

String _number(double? value) =>
    value == null ? '' : formatNumber(value, digits: 2);

String _qualityResultLabel(String? value) {
  switch ((value ?? '').trim().toUpperCase()) {
    case 'PASS':
      return 'Đạt yêu cầu';
    case 'ISSUE_DETECTED':
      return 'Phát hiện vấn đề';
    default:
      return 'Chưa kiểm';
  }
}

String _dispositionLabel(String? value) {
  switch ((value ?? '').trim().toUpperCase()) {
    case 'ACCEPT_NORMAL':
      return 'Chấp nhận nhập kho thường';
    case 'ACCEPT_QUARANTINE':
      return 'Chấp nhận nhưng cách ly';
    case 'REJECT_RETURN':
      return 'Từ chối và trả nhà cung cấp';
    case 'KEEP_STORED':
      return 'Giữ nguyên trong kho';
    case 'QUARANTINE':
      return 'Chuyển bao sang cách ly';
    case 'RELEASE':
      return 'Giải phóng / cho phép xuất';
    case 'KEEP_QUARANTINE':
      return 'Tiếp tục giữ cách ly';
    default:
      return 'Chưa có quyết định';
  }
}

String _bagStatusLabel(String value) {
  switch (value.trim().toUpperCase()) {
    case 'ACTIVE':
      return 'Đang hoạt động';
    case 'QUARANTINED':
    case 'QUARANTINE':
      return 'Đang cách ly';
    case 'RELEASED':
      return 'Đã giải phóng';
    case 'REJECTED':
      return 'Đã từ chối';
    default:
      return value.trim().isEmpty ? 'Không rõ trạng thái' : value;
  }
}

import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_data_view.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/quality_inspection_repository.dart';
import '../../models/quality_inspection.dart';

class QualityInspectionScreen extends StatefulWidget {
  const QualityInspectionScreen({this.repository, super.key});

  final QualityInspectionRepository? repository;

  @override
  State<QualityInspectionScreen> createState() =>
      _QualityInspectionScreenState();
}

class _QualityInspectionScreenState extends State<QualityInspectionScreen> {
  late final QualityInspectionRepository _repository;
  final RealtimeDataController _controller = RealtimeDataController();
  bool _isCreating = false;

  static const Set<String> _entities = {
    'QualityInspection',
    'PaddyLot',
    'InboundOrder',
  };

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiQualityInspectionRepository();
  }

  Future<void> _createInspection() async {
    if (_isCreating) return;
    setState(() => _isCreating = true);
    try {
      final lots = await _repository.getPaddyLots();
      if (!mounted) return;
      if (lots.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa có lô lúa/gạo để kiểm chất.')),
        );
        return;
      }
      final draft = await showDialog<QualityInspectionDraft>(
        context: context,
        builder: (_) => _QualityInspectionDialog(lots: lots),
      );
      if (draft == null) return;
      await _repository.createInspection(draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tạo phiếu kiểm chất.')),
      );
      _controller.reload();
    } on QualityInspectionException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      appBar: AppBar(
        title: const Text('Kiểm chất lô lúa/gạo'),
        actions: [
          IconButton(
            onPressed: _controller.reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isCreating ? null : _createInspection,
        icon: _isCreating
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(_isCreating ? 'Đang xử lý...' : 'Tạo phiếu kiểm chất'),
      ),
      body: RealtimeDataView<List<QualityInspection>>(
        loader: _repository.getInspections,
        controller: _controller,
        entities: _entities,
        loadingBuilder: (_) => const ListSkeleton(),
        errorBuilder: (context, error, retry) => HErrorState(
          message: 'Không tải được phiếu kiểm chất: $error',
          onRetry: retry,
        ),
        builder: (context, inspections) {
          if (inspections.isEmpty) {
            return const HEmptyState(
              title: 'Chưa có phiếu kiểm chất',
              description:
                  'Backend chưa có kết quả kiểm tra chất lượng lô lúa/gạo.',
              icon: Icons.science_outlined,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: inspections.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) =>
                _InspectionCard(inspection: inspections[index]),
          );
        },
      ),
    );
  }
}

class _QualityInspectionDialog extends StatefulWidget {
  const _QualityInspectionDialog({required this.lots});

  final List<PaddyLotOption> lots;

  @override
  State<_QualityInspectionDialog> createState() =>
      _QualityInspectionDialogState();
}

class _QualityInspectionDialogState extends State<_QualityInspectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late int _lotId = widget.lots.first.id;
  bool _passed = true;
  final _moisture = TextEditingController();
  final _impurity = TextEditingController();
  final _mold = TextEditingController();
  final _pest = TextEditingController();
  final _packaging = TextEditingController();
  final _handling = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    for (final controller in [
      _moisture,
      _impurity,
      _mold,
      _pest,
      _packaging,
      _handling,
      _note,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Phiếu kiểm chất'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _lotId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Lô lúa/gạo'),
                  items: [
                    for (final lot in widget.lots)
                      DropdownMenuItem(
                        value: lot.id,
                        child: Text(
                          lot.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _lotId = value ?? _lotId),
                ),
                _field(
                  _moisture,
                  'Độ ẩm (%)',
                  numeric: true,
                  required: true,
                ),
                _field(
                  _impurity,
                  'Tạp chất (%)',
                  numeric: true,
                  required: true,
                ),
                _field(_mold, 'Mức nấm mốc'),
                _field(_pest, 'Mức sâu mọt'),
                _field(_packaging, 'Tình trạng bao bì'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Đạt chất lượng'),
                  value: _passed,
                  onChanged: (value) => setState(() => _passed = value),
                ),
                _field(_handling, 'Hướng xử lý'),
                _field(_note, 'Ghi chú'),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.of(context).pop(
              QualityInspectionDraft(
                paddyLotId: _lotId,
                passed: _passed,
                moisturePercent: _parseDecimal(_moisture.text),
                impurityPercent: _parseDecimal(_impurity.text),
                moldLevel: _emptyToNull(_mold.text),
                pestLevel: _emptyToNull(_pest.text),
                packagingStatus: _emptyToNull(_packaging.text),
                handling: _emptyToNull(_handling.text),
                note: _emptyToNull(_note.text),
              ),
            );
          },
          child: const Text('Lưu kiểm chất'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool numeric = false,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (value) {
                final parsed = _parseDecimal(value ?? '');
                if (parsed == null) return 'Vui lòng nhập $label';
                if (parsed < 0 || parsed > 100) {
                  return 'Giá trị phải từ 0 đến 100';
                }
                return null;
              }
            : null,
      ),
    );
  }
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double? _parseDecimal(String value) {
  return double.tryParse(value.trim().replaceAll(',', '.'));
}

class _InspectionCard extends StatelessWidget {
  const _InspectionCard({required this.inspection});

  final QualityInspection inspection;

  @override
  Widget build(BuildContext context) {
    final color =
        inspection.passed ? const Color(0xFF15803D) : const Color(0xFFDC2626);
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            inspection.passed
                ? Icons.verified_outlined
                : Icons.gpp_bad_outlined,
            color: color,
          ),
        ),
        title: Text(
          inspection.lotCode,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${_formatDate(inspection.inspectedAt)} • '
          '${inspection.passed ? 'Đạt chất lượng' : 'Không đạt'}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _InfoRow(
            label: 'Người kiểm',
            value: inspection.inspectorName ?? 'Chưa ghi nhận',
          ),
          _InfoRow(
            label: 'Độ ẩm',
            value: _percent(inspection.moisturePercent),
          ),
          _InfoRow(
            label: 'Tạp chất',
            value: _percent(inspection.impurityPercent),
          ),
          _InfoRow(label: 'Mức nấm mốc', value: inspection.moldLevel ?? '-'),
          _InfoRow(label: 'Mức sâu mọt', value: inspection.pestLevel ?? '-'),
          _InfoRow(
            label: 'Bao bì',
            value: inspection.packagingStatus ?? '-',
          ),
          if (inspection.handling?.isNotEmpty ?? false)
            _InfoRow(label: 'Xử lý', value: inspection.handling!),
          if (inspection.note?.isNotEmpty ?? false)
            _InfoRow(label: 'Ghi chú', value: inspection.note!),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String _percent(double? value) =>
    value == null ? 'Chưa đo' : '${value.toStringAsFixed(2)}%';

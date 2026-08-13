import 'package:flutter/material.dart';

import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/api_milling_repository.dart';
import '../../data/milling_repository.dart';
import '../../models/milling_order.dart';

class MillingCreateOrderScreen extends StatefulWidget {
  const MillingCreateOrderScreen({this.repository, super.key});

  final MillingRepository? repository;

  @override
  State<MillingCreateOrderScreen> createState() =>
      _MillingCreateOrderScreenState();
}

class _MillingCreateOrderScreenState extends State<MillingCreateOrderScreen> {
  late final MillingRepository _repository;
  late Future<List<MillingPaddyLotOption>> _lotsFuture;
  final _formKey = GlobalKey<FormState>();
  final _inputController = TextEditingController();
  final _yieldController = TextEditingController(text: '0.65');
  final _reasonController = TextEditingController();
  final _moistureController = TextEditingController();
  final _millingCostController = TextEditingController();
  final _incidentalCostController = TextEditingController();
  MillingPaddyLotOption? _selectedLot;
  int? _selectedWarehouseId;
  DateTime? _expectedCompletionDate;
  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiMillingRepository();
    _lotsFuture = _repository.getPaddyLots();
    _inputController.addListener(_refreshOutput);
    _yieldController.addListener(_refreshOutput);
  }

  @override
  void dispose() {
    _inputController
      ..removeListener(_refreshOutput)
      ..dispose();
    _yieldController
      ..removeListener(_refreshOutput)
      ..dispose();
    _reasonController.dispose();
    _moistureController.dispose();
    _millingCostController.dispose();
    _incidentalCostController.dispose();
    super.dispose();
  }

  void _refreshOutput() {
    if (mounted) setState(() {});
  }

  void _retryLots() => setState(() => _lotsFuture = _repository.getPaddyLots());

  double? _number(TextEditingController controller) {
    final value = double.tryParse(controller.text.trim().replaceAll(',', '.'));
    return value != null && value.isFinite ? value : null;
  }

  double? get _expectedOutput {
    final input = _number(_inputController);
    final yieldRate = _number(_yieldController);
    return input == null || yieldRate == null ? null : input * yieldRate;
  }

  List<MillingPaddyLotOption> _filteredLots(
    List<MillingPaddyLotOption> lots,
  ) => _selectedWarehouseId == null
      ? const []
      : lots.where((lot) => lot.warehouseId == _selectedWarehouseId).toList();

  String? _validateInput(String? value) {
    final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      return 'Nhập khối lượng lớn hơn 0';
    }
    if (_selectedLot != null && parsed > _selectedLot!.remainingWeightKg) {
      return 'Không vượt quá ${_selectedLot!.remainingWeightKg.toStringAsFixed(1)} kg còn lại';
    }
    return null;
  }

  String? _validateYield(String? value) {
    final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
    return parsed == null || !parsed.isFinite || parsed <= 0 || parsed > 1
        ? 'Nhập tỷ lệ trong khoảng 0 đến 1 (ví dụ 0.65)'
        : null;
  }

  double? _optionalNumber(TextEditingController controller) {
    if (controller.text.trim().isEmpty) return null;
    return _number(controller);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitError = null);
    if (!_formKey.currentState!.validate()) return;
    final lot = _selectedLot;
    final input = _number(_inputController);
    final yieldRate = _number(_yieldController);
    if (lot == null || input == null || yieldRate == null) return;
    if (lot.riceVarietyId == null || lot.riceVarietyId! <= 0) {
      setState(() => _submitError = 'Lô chưa có giống lúa hợp lệ.');
      return;
    }
    final moisture = _optionalNumber(_moistureController);
    final millingCost = _optionalNumber(_millingCostController);
    final incidentalCost = _optionalNumber(_incidentalCostController);
    final invalidOptional =
        (_moistureController.text.trim().isNotEmpty && moisture == null) ||
        (_millingCostController.text.trim().isNotEmpty && millingCost == null) ||
        (_incidentalCostController.text.trim().isNotEmpty && incidentalCost == null);
    if (invalidOptional) {
      setState(() => _submitError = 'Kiểm tra các giá trị số đã nhập.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final id = await _repository.createOrder(
        lot: lot,
        inputWeightKg: input,
        expectedYield: yieldRate,
        reason: _reasonController.text,
        moisturePercent: moisture,
        millingCost: millingCost,
        incidentalCost: incidentalCost,
        expectedCompletionDate: _expectedCompletionDate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tạo lệnh xay ở trạng thái nháp.')),
      );
      Navigator.of(context).pop(id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = 'Không thể tạo lệnh xay: $error';
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
      initialDate: _expectedCompletionDate ?? now,
    );
    if (picked != null && mounted) setState(() => _expectedCompletionDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            AppGradientHeader(
              title: 'Tạo lệnh xay',
              subtitle: 'Tạo phiếu nháp từ lô lúa còn khả dụng',
              leading: IconButton(
                tooltip: 'Quay lại',
                onPressed: _submitting ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
            ),
            Expanded(
            child: FutureBuilder<List<MillingPaddyLotOption>>(
              future: _lotsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const FormSkeleton();
                }
                if (snapshot.hasError) {
                  return HErrorState(
                    message: 'Không tải được kho và lô đầu vào: ${snapshot.error}',
                    onRetry: _retryLots,
                  );
                }
                final lots = snapshot.data ?? const <MillingPaddyLotOption>[];
                if (lots.isEmpty) {
                  return const HEmptyState(
                    title: 'Chưa có lô lúa khả dụng',
                    description: 'Cần có lô lúa còn khối lượng để tạo lệnh xay.',
                  );
                }
                return _buildForm(lots);
              },
            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(List<MillingPaddyLotOption> lots) {
    final warehouses = <int, String>{
      for (final lot in lots) lot.warehouseId: lot.warehouseName,
    };
    final filteredLots = _filteredLots(lots);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _section('Nguồn và kho', Icons.account_tree_rounded, [
            DropdownButtonFormField<String>(
              initialValue: 'independent',
              decoration: const InputDecoration(
                labelText: 'Nguồn lệnh',
                helperText: 'API hiện hỗ trợ tạo lệnh độc lập',
              ),
              items: const [
                DropdownMenuItem(value: 'independent', child: Text('Lệnh độc lập')),
              ],
              onChanged: _submitting ? null : (_) {},
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: warehouses.containsKey(_selectedWarehouseId)
                  ? _selectedWarehouseId
                  : null,
              decoration: const InputDecoration(labelText: 'Kho thực hiện *'),
              hint: const Text('Chọn kho'),
              items: warehouses.entries
                  .map((entry) => DropdownMenuItem<int>(
                        value: entry.key,
                        child: Text(entry.value, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              validator: (value) => value == null ? 'Chọn kho' : null,
              onChanged: _submitting
                  ? null
                  : (value) => setState(() {
                        _selectedWarehouseId = value;
                        if (_selectedLot?.warehouseId != value) _selectedLot = null;
                      }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MillingPaddyLotOption>(
              initialValue: filteredLots.contains(_selectedLot) ? _selectedLot : null,
              decoration: const InputDecoration(labelText: 'Lô/cột đầu vào *'),
              hint: const Text('Chọn lô lúa'),
              items: filteredLots
                  .map((lot) => DropdownMenuItem<MillingPaddyLotOption>(
                        value: lot,
                        child: Text(
                          '${lot.code} · còn ${lot.remainingWeightKg.toStringAsFixed(1)} kg',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              validator: (value) => value == null ? 'Chọn lô đầu vào' : null,
              onChanged: _submitting ? null : (value) => setState(() => _selectedLot = value),
            ),
            if (_selectedLot != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Giống: ${_selectedLot!.riceVarietyName ?? 'Chưa có tên giống'}'),
              ),
          ]),
          _section('Lúa đầu vào', Icons.scale_rounded, [
            TextFormField(
              controller: _inputController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Khối lượng lúa dự kiến (kg) *'),
              validator: _validateInput,
              enabled: !_submitting,
            ),
            if (_selectedLot != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Khả dụng: ${_selectedLot!.remainingWeightKg.toStringAsFixed(1)} kg'),
              ),
          ]),
          _section('Yield và sản lượng', Icons.percent_rounded, [
            TextFormField(
              controller: _yieldController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Yield dự kiến *', hintText: 'Ví dụ 0.65'),
              validator: _validateYield,
              enabled: !_submitting,
            ),
            const SizedBox(height: 10),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Gạo dự kiến'),
              child: Text(
                _expectedOutput == null
                    ? '—'
                    : '${_expectedOutput!.toStringAsFixed(2)} kg',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          _section('Thời gian và chi phí', Icons.event_note_rounded, [
            TextFormField(
              controller: _moistureController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Độ ẩm (%) · tùy chọn'),
              enabled: !_submitting,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _submitting ? null : _pickDate,
              icon: const Icon(Icons.calendar_today_rounded),
              label: Text(_expectedCompletionDate == null
                  ? 'Chọn ngày dự kiến hoàn thành'
                  : 'Hoàn thành: ${_expectedCompletionDate!.day.toString().padLeft(2, '0')}/${_expectedCompletionDate!.month.toString().padLeft(2, '0')}/${_expectedCompletionDate!.year}'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _millingCostController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Chi phí xay · tùy chọn'),
              enabled: !_submitting,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _incidentalCostController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Chi phí phát sinh · tùy chọn'),
              enabled: !_submitting,
            ),
          ]),
          _section('Ghi chú', Icons.notes_rounded, [
            TextFormField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Ghi chú cho lệnh xay'),
              enabled: !_submitting,
            ),
          ]),
          if (_submitError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _submitError!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_task_rounded),
              label: Text(_submitting ? 'Đang tạo...' : 'Tạo lệnh nháp'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

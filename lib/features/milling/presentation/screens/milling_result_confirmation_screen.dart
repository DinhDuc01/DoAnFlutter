import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../auth/data/auth_session_store.dart';
import '../../data/milling_repository.dart';
import '../../models/milling_location.dart';
import '../../models/milling_order.dart';
import '../../models/milling_output_form.dart';

/// Summarizes output weights and completes the milling order.
class MillingResultConfirmationScreen extends StatefulWidget {
  const MillingResultConfirmationScreen({
    required this.order,
    required this.repository,
    this.initialOutputForms,
    super.key,
  });

  final MillingOrder order;
  final MillingRepository repository;
  final List<MillingOutputFormValue>? initialOutputForms;

  @override
  State<MillingResultConfirmationScreen> createState() =>
      _MillingResultConfirmationScreenState();
}

class _MillingResultConfirmationScreenState
    extends State<MillingResultConfirmationScreen> {
  bool get _canUpdate =>
      AuthSessionStore.current?.hasPermission('MILLING_ORDERS', 'UPDATE') ==
      true;

  bool _isCompleting = false;
  String? _errorMessage;

  late String _selectedMachineRef;
  final TextEditingController _lossController = TextEditingController();
  final TextEditingController _millingCostController = TextEditingController();
  final TextEditingController _incidentalCostController =
      TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  int? _selectedOperatorId;
  late final List<_MillingOutputForm> _outputForms;

  List<MillingProductOption> _products = const [];
  List<MillingOperator> _operators = const [];
  String? _loadError;

  /// Vị trí nhập kho backend gợi ý cho từng dòng đầu ra (khóa theo `form.type`).
  final Map<String, List<MillingPutawaySuggestion>> _formSuggestions = {};
  final Map<String, String> _suggestionErrors = {};
  final Map<String, MillingLocation> _pickedLocations = {};
  final Set<String> _suggestingTypes = <String>{};
  final Map<String, Timer> _suggestDebounce = {};

  List<String> get _machineOptions => <String>{
        if (widget.order.machineRef != null &&
            widget.order.machineRef!.trim().isNotEmpty)
          widget.order.machineRef!.trim()
        else
          'máy xay 1',
      }.toList();

  @override
  void initState() {
    super.initState();
    final initialMachine = widget.order.machineRef?.trim();
    _selectedMachineRef =
        (initialMachine != null && initialMachine.isNotEmpty)
            ? initialMachine
            : 'máy xay 1';

    _selectedOperatorId = widget.order.operatorId;
    _lossController.text = widget.order.lossKg != null
        ? widget.order.lossKg!.toStringAsFixed(1)
        : '0';

    if (widget.order.millingCost != null && widget.order.millingCost! > 0) {
      _millingCostController.text =
          widget.order.millingCost!.toStringAsFixed(0);
    }
    if (widget.order.incidentalCost != null &&
        widget.order.incidentalCost! > 0) {
      _incidentalCostController.text =
          widget.order.incidentalCost!.toStringAsFixed(0);
    }
    if (widget.order.reason != null) {
      _noteController.text = widget.order.reason!;
    }

    final initial = widget.initialOutputForms;
    _outputForms = [
      for (final value in (initial == null || initial.isEmpty
          ? const [MillingOutputFormValue(type: MillingOutputType.rice)]
          : initial))
        _MillingOutputForm.fromValue(value),
    ];
    _loadData();
  }

  @override
  void dispose() {
    _lossController.dispose();
    _millingCostController.dispose();
    _incidentalCostController.dispose();
    _noteController.dispose();
    for (final timer in _suggestDebounce.values) {
      timer.cancel();
    }
    for (final form in _outputForms) {
      form.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        widget.repository.getOutputProducts(),
        widget.repository.getMillingOperators(),
      ]);
      if (!mounted) return;
      setState(() {
        _products = results[0] as List<MillingProductOption>;
        _operators = results[1] as List<MillingOperator>;
      });
      for (final form in _outputForms) {
        if (form.productVariantId != null) {
          _refreshOutputLocation(form);
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loadError = 'Không tải được dữ liệu: $error');
      }
    }
  }

  Future<void> _refreshOutputLocation(_MillingOutputForm form) async {
    final variantId = form.productVariantId;
    final weight = form.outputWeightKg ??
        (form.type == 'RICE' ? widget.order.totalRiceOutputKg : 0);
    if (variantId == null || variantId <= 0 || !weight.isFinite || weight < 0) {
      if (mounted) {
        setState(() {
          _formSuggestions.remove(form.type);
          if (variantId == null) {
            form.locationId = null;
            _pickedLocations.remove(form.type);
          }
        });
      }
      return;
    }
    if (_suggestingTypes.contains(form.type)) return;
    setState(() => _suggestingTypes.add(form.type));
    try {
      final suggestions = await widget.repository.getPutawaySuggestions(
        warehouseId: widget.order.warehouseId,
        productVariantId: variantId,
        requiredWeightKg: weight,
      );
      if (!mounted) return;
      setState(() {
        _suggestionErrors.remove(form.type);
        _formSuggestions[form.type] = suggestions;
        final ids = suggestions.map((item) => item.locationId).toSet();
        if (suggestions.isEmpty) {
          form.locationId = null;
          _pickedLocations.remove(form.type);
        }
        if (suggestions.isNotEmpty &&
            (form.locationId == null || !ids.contains(form.locationId))) {
          form.locationId = suggestions.first.locationId;
          _pickedLocations.remove(form.type);
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _formSuggestions.remove(form.type);
          _suggestionErrors[form.type] = '$error';
        });
      }
    } finally {
      if (mounted) setState(() => _suggestingTypes.remove(form.type));
    }
  }

  void _scheduleLocationRefresh(_MillingOutputForm form) {
    _suggestDebounce[form.type]?.cancel();
    _suggestDebounce[form.type] = Timer(
      const Duration(milliseconds: 450),
      () {
        if (mounted) _refreshOutputLocation(form);
      },
    );
  }

  String _locationLabel(_MillingOutputForm form) {
    final id = form.locationId;
    if (id == null) return 'Chọn vị trí nhập kho *';
    for (final suggestion in _formSuggestions[form.type] ?? const []) {
      if (suggestion.locationId == id) {
        return 'Vị trí: ${suggestion.displayName}';
      }
    }
    final picked = _pickedLocations[form.type];
    if (picked != null && picked.id == id) {
      return 'Vị trí: ${picked.displayName}';
    }
    return 'Vị trí #$id';
  }

  void _addOutput(String type, String label) {
    setState(() => _outputForms.add(
          _MillingOutputForm(
            type: type,
            label: label,
            isByproduct: type != 'RICE',
          ),
        ));
  }

  void _removeOutput(_MillingOutputForm form) {
    if (_outputForms.length <= 1) return;
    setState(() {
      _outputForms.remove(form);
      form.dispose();
    });
  }

  double get _totalRiceKg => _outputForms
      .where((f) => f.type == 'RICE')
      .fold<double>(0, (sum, f) => sum + (f.outputWeightKg ?? 0));

  double get _totalByproductKg => _outputForms
      .where((f) => f.type != 'RICE')
      .fold<double>(0, (sum, f) => sum + (f.outputWeightKg ?? 0));

  double get _totalAllOutputsKg => _totalRiceKg + _totalByproductKg;

  double get _lossKg =>
      double.tryParse(_lossController.text.trim().replaceAll(',', '.')) ?? 0;

  double get _completeInputKg {
    final inputs = widget.order.inputs;
    if (inputs.isNotEmpty) {
      final fromInputs = inputs.fold<double>(
        0,
        (sum, input) =>
            sum + (input.reservedWeightKg ?? input.consumedWeightKg),
      );
      if (fromInputs > 0) return fromInputs;
    }
    return widget.order.inputWeightKg;
  }

  double get _computedPaddyToConsumeKg {
    final inputs = widget.order.inputs;
    if (inputs.isNotEmpty) {
      final total = inputs.fold<double>(
        0,
        (sum, input) => sum + (input.reservedWeightKg ?? 0),
      );
      if (total > 0) return total;
    }
    return _completeInputKg;
  }

  double get _actualYieldRate => _computedPaddyToConsumeKg > 0
      ? (_totalRiceKg / _computedPaddyToConsumeKg)
      : 0;

  double get _configuredYieldRate => widget.order.yieldRateUsed;

  double get _yieldDeltaPoints =>
      (_actualYieldRate - _configuredYieldRate) * 100;

  double get _targetRiceExpected {
    if (widget.order.totalRiceOutputKg > 0) {
      return widget.order.totalRiceOutputKg;
    }
    return _computedPaddyToConsumeKg * _configuredYieldRate;
  }

  double get _yieldDevPercent => _targetRiceExpected > 0
      ? ((_totalRiceKg - _targetRiceExpected) / _targetRiceExpected) * 100
      : 0;

  double get _massBalanceDeltaKg =>
      _computedPaddyToConsumeKg - _totalAllOutputsKg - _lossKg;

  List<String> _validate() {
    final errors = <String>[];
    if (_selectedMachineRef.trim().isEmpty) {
      errors.add('Vui lòng chọn mã máy xay.');
    }
    if (_selectedOperatorId == null) {
      errors.add('Vui lòng chọn người vận hành máy xay.');
    }
    if (_configuredYieldRate <= 0 || _configuredYieldRate > 1) {
      errors.add('Yield cấu hình phải lớn hơn 0 và không vượt quá 1.');
    }
    if (_outputForms.isEmpty) {
      errors.add('Vui lòng thêm ít nhất một dòng đầu ra.');
    }
    if (_outputForms.where((f) => f.type == 'RICE').isEmpty) {
      errors.add('Phải có ít nhất một dòng gạo thành phẩm.');
    }
    for (final form in _outputForms) {
      if (form.productVariantId == null) {
        errors.add('${form.label}: chưa chọn SKU đầu ra.');
      }
      if (form.locationId == null) {
        errors.add('${form.label}: chưa chọn vị trí nhập kho.');
      }
      if (form.outputWeightKg == null ||
          !form.outputWeightKg!.isFinite ||
          form.outputWeightKg! <= 0) {
        errors.add('${form.label}: khối lượng phải lớn hơn 0.');
      }
    }
    if (_totalRiceKg <= 0) {
      errors.add('Khối lượng gạo thành phẩm phải lớn hơn 0.');
    }
    if (_computedPaddyToConsumeKg > 0 &&
        _totalAllOutputsKg + _lossKg > _computedPaddyToConsumeKg * 1.02) {
      errors.add(
          'Tổng đầu ra và hao hụt vượt quá lượng lúa nguyên bao thực tế + 2% dung sai.');
    }
    if (_yieldDevPercent.abs() > 2 && _noteController.text.trim().isEmpty) {
      errors.add(
          'Sản lượng gạo thực tế lệch kế hoạch trên 2%. Vui lòng nhập ghi chú/lý do.');
    }
    return errors;
  }

  List<MillingOutputFormValue> _currentOutputValues() => [
        for (final form in _outputForms)
          MillingOutputFormValue(
            type: switch (form.type) {
              'RICE' => MillingOutputType.rice,
              'BROKEN' => MillingOutputType.broken,
              'BRAN' => MillingOutputType.bran,
              _ => MillingOutputType.husk,
            },
            productVariantId: form.productVariantId,
            locationId: form.locationId,
            bagCount: form.bagCount,
            kgPerBag: form.kgPerBag,
            outputWeightKg: form.outputWeightKg,
          ),
      ];

  Future<void> _submitComplete() async {
    if (!_canUpdate) {
      setState(() => _errorMessage = 'Bạn không có quyền hoàn tất lệnh xay.');
      return;
    }
    final errors = _validate();
    if (errors.isNotEmpty) {
      setState(() => _errorMessage = errors.first);
      return;
    }
    if (_isCompleting) return;
    setState(() {
      _isCompleting = true;
      _errorMessage = null;
    });

    try {
      final millingCost = double.tryParse(
          _millingCostController.text.trim().replaceAll(',', '.'));
      final incidentalCost = double.tryParse(
          _incidentalCostController.text.trim().replaceAll(',', '.'));

      await widget.repository.completeOrder(
        widget.order,
        machineRef: _selectedMachineRef.trim(),
        operatorId: _selectedOperatorId,
        lossKg: _lossKg,
        byproductKg: _totalByproductKg,
        millingCost: millingCost,
        incidentalCost: incidentalCost,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        outputForms: _currentOutputValues(),
      );

      final detail =
          await widget.repository.getMillingOrderDetail(widget.order.id);
      if ((detail.statusCode ?? '').trim().toUpperCase() != 'COMPLETED') {
        throw StateError('Backend chưa xác nhận COMPLETED.');
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  String _friendlyError(Object error) {
    if (error is ApiException) {
      return switch (error.statusCode) {
        401 => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        403 => 'Bạn không có quyền hoàn tất lệnh xay.',
        404 => 'Lệnh xay không còn tồn tại.',
        409 => 'Dữ liệu bao đầu vào đã thay đổi. Vui lòng tải lại nguồn lúa.',
        422 => error.message,
        _ when (error.statusCode ?? 0) >= 500 =>
          'Backend đang gặp lỗi. Vui lòng thử lại sau.',
        _ => error.message,
      };
    }
    return error.toString();
  }

  Widget _outputFormCard(_MillingOutputForm form) {
    final candidates = _products
        .where((item) => item.outputType.trim().toUpperCase() == form.type)
        .toList();

    return Card(
      key: Key('milling_output_card_${form.type.toLowerCase()}'),
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DropdownButton<String>(
                  value: form.type,
                  underline: const SizedBox(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    fontSize: 15,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'RICE', child: Text('Gạo')),
                    DropdownMenuItem(value: 'BROKEN', child: Text('Tấm')),
                    DropdownMenuItem(value: 'BRAN', child: Text('Cám')),
                    DropdownMenuItem(value: 'HUSK', child: Text('Trấu')),
                  ],
                  onChanged: (newType) {
                    if (newType == null || newType == form.type) return;
                    setState(() {
                      form.type = newType;
                      form.label = switch (newType) {
                        'RICE' => 'Gạo',
                        'BROKEN' => 'Tấm',
                        'BRAN' => 'Cám',
                        _ => 'Trấu',
                      };
                      form.isByproduct = newType != 'RICE';
                      form.productVariantId = null;
                      form.locationId = null;
                    });
                  },
                ),
                const Spacer(),
                if (_outputForms.length > 1)
                  IconButton(
                    tooltip: 'Xóa dòng ${form.label}',
                    onPressed: () => _removeOutput(form),
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: form.productVariantId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'SKU đầu ra *',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              hint: const Text('Chọn SKU'),
              items: [
                for (final product in candidates)
                  DropdownMenuItem(
                    value: product.id,
                    child: Text(
                      '${product.sku} · ${product.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                MillingProductOption? selectedProduct;
                for (final item in _products) {
                  if (item.id == value) {
                    selectedProduct = item;
                    break;
                  }
                }
                setState(() {
                  form.productVariantId = value;
                  form.locationId = null;
                  _pickedLocations.remove(form.type);
                  final targetWeight = selectedProduct?.targetWeightKg;
                  if (targetWeight != null && targetWeight > 0) {
                    form.kgPerBagController.text = targetWeight
                        .toStringAsFixed(targetWeight % 1 == 0 ? 0 : 2);
                    final weight = form.outputWeightKg;
                    if (weight != null && weight > 0) {
                      final bags = (weight / targetWeight).ceil();
                      form.bagController.text = bags.toString();
                    }
                  }
                });
                _refreshOutputLocation(form);
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                alignment: Alignment.centerLeft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _suggestingTypes.contains(form.type)
                  ? null
                  : () async {
                      final suggestions = _formSuggestions[form.type] ??
                          const <MillingPutawaySuggestion>[];
                      const locations = <MillingLocation>[];
                      if (!mounted) return;
                      final selected = await showModalBottomSheet<int>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => _LocationPickerSheet(
                          outputLabel: form.label,
                          suggestions: suggestions,
                          locations: locations,
                        ),
                      );
                      if (selected != null && mounted) {
                        setState(() {
                          form.locationId = selected;
                          for (final location in locations) {
                            if (location.id == selected) {
                              _pickedLocations[form.type] = location;
                            }
                          }
                        });
                      }
                    },
              icon: _suggestingTypes.contains(form.type)
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.warehouse_outlined, size: 18),
              label: Text(
                _suggestingTypes.contains(form.type)
                    ? 'Đang tìm vị trí phù hợp...'
                    : _locationLabel(form),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_suggestionErrors[form.type] case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Không lấy được gợi ý tự động: $error',
                  style:
                      const TextStyle(color: Colors.redAccent, fontSize: 11),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: form.bagController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Số bao *',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    onChanged: (_) {
                      final count = form.bagCount;
                      final kgPerBag = form.kgPerBag;
                      if (count != null &&
                          count > 0 &&
                          kgPerBag != null &&
                          kgPerBag > 0) {
                        form.weightController.text =
                            (count * kgPerBag).toStringAsFixed(2);
                      }
                      setState(() {});
                      _scheduleLocationRefresh(form);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: form.kgPerBagController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Kg/bao *',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    onChanged: (_) {
                      final weight = form.outputWeightKg;
                      final kgPerBag = form.kgPerBag;
                      if (weight != null &&
                          weight > 0 &&
                          kgPerBag != null &&
                          kgPerBag > 0) {
                        final bags = (weight / kgPerBag).ceil();
                        form.bagController.text = bags.toString();
                      }
                      setState(() {});
                      _scheduleLocationRefresh(form);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: form.weightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Khối lượng thực tế (kg) *',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    onChanged: (_) {
                      final weight = form.outputWeightKg;
                      final kgPerBag = form.kgPerBag;
                      if (weight != null &&
                          weight > 0 &&
                          kgPerBag != null &&
                          kgPerBag > 0) {
                        final bags = (weight / kgPerBag).ceil();
                        form.bagController.text = bags.toString();
                      }
                      setState(() {});
                      _scheduleLocationRefresh(form);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMassBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Đối chiếu mẻ xay',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          _balanceRow(
              'Lúa đã giữ', '${_completeInputKg.toStringAsFixed(1)} kg'),
          _balanceRow(
              'Gạo thành phẩm', '${_totalRiceKg.toStringAsFixed(1)} kg'),
          _balanceRow(
              'Phụ phẩm', '${_totalByproductKg.toStringAsFixed(1)} kg'),
          _balanceRow('Hao hụt', '${_lossKg.toStringAsFixed(1)} kg'),
          const Divider(height: 16),
          _balanceRow('Lúa thực tế sẽ trừ',
              '${_computedPaddyToConsumeKg.toStringAsFixed(1)} kg',
              isBold: true),
          _balanceRow(
            'Chênh cân bằng',
            '${_massBalanceDeltaKg.toStringAsFixed(1)} kg',
            color: _massBalanceDeltaKg.abs() < 0.01
                ? const Color(0xFF16A34A)
                : (_massBalanceDeltaKg < 0
                    ? const Color(0xFFDC2626)
                    : const Color(0xFFD97706)),
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _balanceRow(String label, String value,
      {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
                color: const Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập kết quả xay và thành phẩm',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            Text(
              '${order.millingCode} · Lúa đã giữ: ${_completeInputKg.toStringAsFixed(1)} kg',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        children: [
          // Section 1: Gạo thành phẩm và phụ phẩm
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gạo thành phẩm và phụ phẩm',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                'Mỗi dòng đầu ra sẽ tạo một lô và nhập vào vị trí đã chọn.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _addChipButton(
                    '＋ Gạo thành phẩm', () => _addOutput('RICE', 'Gạo')),
                const SizedBox(width: 6),
                _addChipButton('＋ Tấm', () => _addOutput('BROKEN', 'Tấm')),
                const SizedBox(width: 6),
                _addChipButton('＋ Cám', () => _addOutput('BRAN', 'Cám')),
                const SizedBox(width: 6),
                _addChipButton('＋ Trấu', () => _addOutput('HUSK', 'Trấu')),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_loadError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          for (final form in _outputForms) _outputFormCard(form),

          const SizedBox(height: 14),

          // Section 2: Bảng đối chiếu mẻ xay
          _buildMassBalanceCard(),

          const SizedBox(height: 14),

          // Section 3: Thông số & Vận hành
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Yield đã đóng dấu',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${(_configuredYieldRate * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Yield thực tế',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF166534)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${(_actualYieldRate * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF15803D)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Chênh yield kế hoạch ${_yieldDeltaPoints >= 0 ? '+' : ''}${_yieldDeltaPoints.toStringAsFixed(2)} điểm % · So với mục tiêu gạo ${_yieldDevPercent >= 0 ? '+' : ''}${_yieldDevPercent.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _yieldDevPercent.abs() > 2
                        ? const Color(0xFFD97706)
                        : const Color(0xFF64748B),
                  ),
                ),
                if (_yieldDevPercent.abs() > 2) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Sản lượng gạo thực tế lệch kế hoạch trên 2%. Vui lòng nhập ghi chú/lý do.',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E)),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _lossController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Hao hụt (kg)',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedMachineRef,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Mã máy xay',
                    border: OutlineInputBorder(),
                    prefixIcon:
                        Icon(Icons.precision_manufacturing_outlined, size: 20),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: [
                    for (final machine in _machineOptions)
                      DropdownMenuItem<String>(
                        value: machine,
                        child: Text(
                          machine == 'máy xay 1' ? 'Máy xay 1' : machine,
                        ),
                      ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedMachineRef = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: _selectedOperatorId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Người vận hành',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Chọn nhân viên xay'),
                    ),
                    for (final op in _operators)
                      DropdownMenuItem<int?>(
                        value: op.id,
                        child: Text(op.name),
                      ),
                  ],
                  onChanged: (val) =>
                      setState(() => _selectedOperatorId = val),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _millingCostController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Chi phí xay',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _incidentalCostController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Chi phí phát sinh',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú kết quả / lý do lệch mục tiêu',
                    hintText:
                        'Nêu nguyên nhân khi kết quả lệch mục tiêu trên 2% (ví dụ: phải lấy nguyên bao)',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          color: Color(0xFF991B1B), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đóng'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed:
                      _canUpdate && !_isCompleting ? _submitComplete : null,
                  icon: _isCompleting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    _isCompleting ? 'Đang hoàn tất...' : 'Nhập kho & Hoàn tất',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addChipButton(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF15803D),
        ),
      ),
      backgroundColor: const Color(0xFFF0FDF4),
      side: const BorderSide(color: Color(0xFFBBF7D0)),
      onPressed: onTap,
    );
  }
}

class _MillingOutputForm {
  _MillingOutputForm(
      {required this.type, required this.label, required this.isByproduct});

  factory _MillingOutputForm.fromValue(MillingOutputFormValue value) {
    final label = switch (value.type) {
      MillingOutputType.rice => 'Gạo',
      MillingOutputType.broken => 'Tấm',
      MillingOutputType.bran => 'Cám',
      MillingOutputType.husk => 'Trấu',
    };
    return _MillingOutputForm(
        type: value.type.code,
        label: label,
        isByproduct: value.type.isByproduct)
      ..productVariantId = value.productVariantId
      ..locationId = value.locationId
      ..bagController.text = value.bagCount?.toString() ?? ''
      ..kgPerBagController.text = value.kgPerBag?.toString() ?? ''
      ..weightController.text = value.outputWeightKg?.toString() ?? '';
  }

  String type;
  String label;
  bool isByproduct;
  int? productVariantId;
  int? locationId;
  final bagController = TextEditingController();
  final kgPerBagController = TextEditingController();
  final weightController = TextEditingController();

  int? get bagCount => int.tryParse(bagController.text.trim());
  double? get kgPerBag =>
      double.tryParse(kgPerBagController.text.trim().replaceAll(',', '.'));
  double? get outputWeightKg =>
      double.tryParse(weightController.text.trim().replaceAll(',', '.'));

  void dispose() {
    bagController.dispose();
    kgPerBagController.dispose();
    weightController.dispose();
  }
}

class _LocationPickerSheet extends StatelessWidget {
  const _LocationPickerSheet({
    required this.outputLabel,
    required this.suggestions,
    required this.locations,
  });

  final String outputLabel;
  final List<MillingPutawaySuggestion> suggestions;
  final List<MillingLocation> locations;

  @override
  Widget build(BuildContext context) {
    final hasSuggestions = suggestions.isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 520),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                'Chọn vị trí nhập $outputLabel',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              if (!hasSuggestions && locations.isEmpty)
                const Text('Không có vị trí phù hợp. Hãy thử lại sau.'),
              for (final suggestion in suggestions)
                ListTile(
                  leading: const Icon(Icons.auto_awesome, color: Color(0xFF16A34A)),
                  title: Text(suggestion.displayName),
                  subtitle: Text(
                    'Còn ${suggestion.freeCapacityKg.toStringAsFixed(1)} kg'
                    '${suggestion.reason == null ? '' : ' · ${suggestion.reason}'}',
                  ),
                  onTap: () => Navigator.of(context).pop(suggestion.locationId),
                ),
              for (final location in locations)
                ListTile(
                  leading: const Icon(Icons.warehouse_outlined),
                  title: Text(location.displayName),
                  subtitle: Text(
                    'Đang chứa ${location.currentOccupancy.toStringAsFixed(1)} kg',
                  ),
                  onTap: () => Navigator.of(context).pop(location.id),
                ),
            ],
          ),
        ),
      ),
    );
  }
}





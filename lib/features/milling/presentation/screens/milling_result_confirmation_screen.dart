import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/routes/app_routes.dart';
import '../../data/api_milling_repository.dart';
import '../../data/milling_repository.dart';
import '../../models/milling_location.dart';
import '../../models/milling_order.dart';
import '../../models/milling_output_form.dart';
import '../widgets/milling_widgets.dart';

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
  bool _isCompleting = false;
  String? _errorMessage;
  String? _loadingLocationType;
  final TextEditingController _noteController = TextEditingController();
  final Map<String, int> _outputLocationIds = {};
  late final List<_MillingOutputForm> _outputForms;
  List<MillingProductOption> _products = const [];
  String? _productsError;

  /// Vị trí nhập kho backend gợi ý cho từng dòng đầu ra (khóa theo `form.type`).
  final Map<String, List<MillingPutawaySuggestion>> _formSuggestions = {};
  final Map<String, MillingLocation> _pickedLocations = {};
  final Set<String> _suggestingTypes = <String>{};
  final Map<String, Timer> _suggestDebounce = {};

  @override
  void dispose() {
    _noteController.dispose();
    for (final timer in _suggestDebounce.values) timer.cancel();
    for (final form in _outputForms) form.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialOutputForms;
    _outputForms = [
      for (final value in (initial == null || initial.isEmpty
          ? const [MillingOutputFormValue(type: MillingOutputType.rice)]
          : initial))
        _MillingOutputForm.fromValue(value),
    ];
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await widget.repository.getOutputProducts();
      if (!mounted) return;
      setState(() => _products = products);
      // Dòng đã có sẵn SKU (mở lại từ bước cân) thì lấy gợi ý vị trí ngay.
      for (final form in _outputForms) {
        if (form.productVariantId != null) _refreshOutputLocation(form);
      }
    } catch (error) {
      if (mounted) setState(() => _productsError = 'Không tải được SKU: $error');
    }
  }

  /// Gọi API gợi ý vị trí nhập kho cho một dòng đầu ra rồi TỰ chọn vị trí tốt
  /// nhất — giống web: đổi SKU hoặc đổi khối lượng là `locationId` được gán lại
  /// bằng vị trí phù hợp đầu tiên, và bỏ chọn nếu vị trí cũ không còn hợp lệ.
  Future<void> _refreshOutputLocation(_MillingOutputForm form) async {
    final variantId = form.productVariantId;
    final weight = form.outputWeightKg ?? 0;
    if (variantId == null || variantId <= 0 || weight <= 0) {
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
        _formSuggestions[form.type] = suggestions;
        final ids = suggestions.map((item) => item.locationId).toSet();
        if (suggestions.isNotEmpty &&
            (form.locationId == null || !ids.contains(form.locationId))) {
          form.locationId = suggestions.first.locationId;
          _pickedLocations.remove(form.type);
        }
      });
    } catch (_) {
      // Không lấy được gợi ý thì vẫn cho chọn tay ở bảng vị trí bên dưới.
      if (mounted) setState(() => _formSuggestions.remove(form.type));
    } finally {
      if (mounted) setState(() => _suggestingTypes.remove(form.type));
    }
  }

  /// Gõ khối lượng thì chờ ngắt nhịp rồi mới gọi API, tránh gọi mỗi ký tự.
  void _scheduleLocationRefresh(_MillingOutputForm form) {
    _suggestDebounce[form.type]?.cancel();
    _suggestDebounce[form.type] = Timer(
      const Duration(milliseconds: 450),
      () {
        if (mounted) _refreshOutputLocation(form);
      },
    );
  }

  /// Nhãn vị trí đang chọn: ưu tiên tên từ gợi ý, sau đó tên đã chọn tay.
  String _locationLabel(_MillingOutputForm form) {
    final id = form.locationId;
    if (id == null) return 'Chọn vị trí nhập kho *';
    for (final suggestion in _formSuggestions[form.type] ?? const []) {
      if (suggestion.locationId == id) return 'Vị trí: ${suggestion.displayName}';
    }
    final picked = _pickedLocations[form.type];
    if (picked != null && picked.id == id) return 'Vị trí: ${picked.displayName}';
    return 'Vị trí #$id';
  }

  void _addOutput(String type, String label) {
    if (_outputForms.any((form) => form.type == type)) return;
    setState(() => _outputForms.add(
          _MillingOutputForm(type: type, label: label, isByproduct: true),
        ));
  }

  void _removeOutput(_MillingOutputForm form) {
    if (!form.isByproduct) return;
    setState(() {
      _outputForms.remove(form);
      form.dispose();
    });
  }

  List<String> _validateOutputDrafts() {
    final errors = <String>[];
    if (widget.order.inputWeightKg <= 0) {
      errors.add('Khối lượng lúa đầu vào không hợp lệ.');
    }
    if (_outputForms.where((form) => form.type == 'RICE').length != 1) {
      errors.add('Cần đúng một đầu ra Gạo.');
    }
    final types = <String>{};
    for (final form in _outputForms) {
      if (!types.add(form.type)) errors.add('${form.label} bị trùng.');
      if (form.productVariantId == null) errors.add('${form.label}: chưa chọn SKU.');
      if (form.locationId == null) errors.add('${form.label}: chưa chọn vị trí.');
      if (form.bagCount == null || form.bagCount! <= 0) errors.add('${form.label}: số bao phải lớn hơn 0.');
      if (form.kgPerBag == null || !form.kgPerBag!.isFinite || form.kgPerBag! <= 0) errors.add('${form.label}: kg/bao không hợp lệ.');
      if (form.outputWeightKg == null || !form.outputWeightKg!.isFinite || form.outputWeightKg! <= 0) errors.add('${form.label}: khối lượng thực tế không hợp lệ.');
    }
    final total = _outputForms.fold<double>(0, (sum, form) => sum + (form.outputWeightKg ?? 0));
    if (total > widget.order.inputWeightKg * 1.02) errors.add('Tổng đầu ra vượt khối lượng lúa đầu vào.');
    final rice = _outputForms.where((form) => form.type == 'RICE').fold<double>(0, (sum, form) => sum + (form.outputWeightKg ?? 0));
    final yieldValue = widget.order.inputWeightKg > 0 ? rice / widget.order.inputWeightKg : 0;
    if ((yieldValue - widget.order.yieldRateUsed).abs() > 0.02 && _noteController.text.trim().isEmpty) {
      errors.add('Yield gạo lệch trên 2%; cần nhập ghi chú.');
    }
    return errors;
  }

  Map<String, dynamic> buildCompletePayloadPreview() => {
        'outputs': [
          for (final form in _outputForms)
            if (form.productVariantId != null &&
                form.locationId != null &&
                (form.outputWeightKg ?? 0) > 0)
              {
                'productVariantId': form.productVariantId,
                'locationId': form.locationId,
                'outputType': form.type,
                'outputWeightKg': form.outputWeightKg,
                'bagCount': form.bagCount,
                'isByproduct': form.isByproduct,
                'unitCost': null,
              },
        ],
        'note': _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      };

  double _formTotal(String type) => _outputForms
      .where((form) => form.type == type)
      .fold<double>(0, (sum, form) => sum + (form.outputWeightKg ?? 0));

  Widget _draftSummary() {
    final rice = _formTotal('RICE');
    final byproduct = _formTotal('BROKEN') + _formTotal('BRAN') + _formTotal('HUSK');
    final total = rice + byproduct;
    final loss = widget.order.inputWeightKg - total;
    final yieldValue = widget.order.inputWeightKg > 0 ? rice / widget.order.inputWeightKg * 100 : 0;
    return Card(
      key: const Key('milling_output_summary'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(spacing: 16, runSpacing: 8, children: [
          Text('Lúa đầu vào: ${widget.order.inputWeightKg.toStringAsFixed(1)} kg'),
          Text('Gạo: ${rice.toStringAsFixed(1)} kg'),
          Text('Phụ phẩm: ${byproduct.toStringAsFixed(1)} kg'),
          Text('Tổng đầu ra: ${total.toStringAsFixed(1)} kg'),
          Text('Hao hụt: ${loss.toStringAsFixed(1)} kg'),
          Text('Yield thực tế: ${yieldValue.toStringAsFixed(1)}%'),
        ]),
      ),
    );
  }

  Future<void> _showLocalPreview() async {
    final errors = _validateOutputDrafts();
    if (errors.isNotEmpty) {
      setState(() => _errorMessage = errors.first);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(shrinkWrap: true, children: [
            const Text('Xác nhận kết quả xay', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            _draftSummary(),
            for (final form in _outputForms)
              ListTile(
                title: Text(form.label),
                subtitle: Text('SKU ${form.productVariantId} · Vị trí ${form.locationId} · ${form.outputWeightKg} kg'),
              ),
            FilledButton(
              onPressed: () => _completeFromForms(sheetContext),
              child: const Text('Xác nhận & hoàn tất xay'),
            ),
          ]),
        ),
      ),
    );
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

  Future<void> _completeFromForms(BuildContext sheetContext) async {
    final errors = _validateOutputDrafts();
    if (errors.isNotEmpty) {
      Navigator.of(sheetContext).pop();
      if (mounted) setState(() => _errorMessage = errors.first);
      return;
    }
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    try {
      await widget.repository.completeOrder(
        widget.order,
        note: _noteController.text,
        outputForms: _currentOutputValues(),
      );
      final detail = await widget.repository.getMillingOrderDetail(widget.order.id);
      if ((detail.statusCode ?? '').trim().toUpperCase() != 'COMPLETED') {
        throw StateError('Backend chưa xác nhận COMPLETED.');
      }
      if (!mounted) return;
      Navigator.of(sheetContext).pop();
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        Navigator.of(sheetContext).pop();
        setState(() => _errorMessage = 'Không hoàn tất được lệnh xay: $error');
      }
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  Widget _outputFormCard(_MillingOutputForm form) {
    final candidates = _products
        .where((item) => item.outputType.trim().toUpperCase() == form.type)
        .toList();
    final productItems = candidates.isEmpty ? _products : candidates;
    return Card(
      key: Key('milling_output_card_${form.type.toLowerCase()}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(form.label, style: const TextStyle(fontWeight: FontWeight.w900))),
            if (form.isByproduct)
              IconButton(
                tooltip: 'Xóa ${form.label}',
                onPressed: () => _removeOutput(form),
                icon: const Icon(Icons.delete_outline),
              ),
          ]),
          DropdownButtonFormField<int>(
            value: form.productVariantId,
            decoration: const InputDecoration(labelText: 'SKU đầu ra *'),
            hint: const Text('Chọn SKU'),
            items: [
              for (final product in productItems)
                DropdownMenuItem(
                  value: product.id,
                  child: SizedBox(
                    width: 220,
                    child: Text(
                      '${product.sku} · ${product.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
            onChanged: (value) {
              setState(() {
                form.productVariantId = value;
                form.locationId = null;
                _pickedLocations.remove(form.type);
              });
              // Đổi SKU là lấy lại gợi ý và tự chọn vị trí phù hợp, như web.
              _refreshOutputLocation(form);
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _suggestingTypes.contains(form.type)
                ? null
                : () async {
                    final suggestions =
                        _formSuggestions[form.type] ?? const <MillingPutawaySuggestion>[];
                    // Chỉ tải danh sách vị trí thô khi backend không gợi ý được.
                    var locations = const <MillingLocation>[];
                    if (suggestions.isEmpty) {
                      locations = (await widget.repository.getLocations())
                          .where((item) =>
                              item.warehouseId == widget.order.warehouseId &&
                              item.isActive &&
                              !item.isQuarantine)
                          .toList();
                    }
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
                : const Icon(Icons.warehouse_outlined),
            label: Text(
              _suggestingTypes.contains(form.type)
                  ? 'Đang tìm vị trí phù hợp...'
                  : _locationLabel(form),
            ),
          ),
          TextField(controller: form.bagController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số bao *'), onChanged: (_) { setState(() {}); _scheduleLocationRefresh(form); }),
          TextField(controller: form.kgPerBagController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Kg/bao *'), onChanged: (_) { setState(() {}); _scheduleLocationRefresh(form); }),
          TextField(controller: form.weightController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Khối lượng thực tế (kg) *'), onChanged: (_) { setState(() {}); _scheduleLocationRefresh(form); }),
          if (form.bagCount != null && form.kgPerBag != null)
            Text('Theo bao: ${(form.bagCount! * form.kgPerBag!).toStringAsFixed(2)} kg', style: const TextStyle(color: Color(0xFF64748B))),
        ]),
      ),
    );
  }

  bool get _isInProgress =>
      switch ((widget.order.statusCode ?? '').trim().toUpperCase()) {
        'IN_PROGRESS' || 'MILLING' => true,
        _ => false,
      };

  List<_OutputDraft> _outputs(MillingOrder order) => [
        _OutputDraft('RICE', 'Gạo', order.riceProductVariantId, order.riceBags),
        _OutputDraft('BRAN', 'Cám', order.branProductVariantId, order.branBags),
        _OutputDraft(
          'BROKEN',
          'Tấm',
          order.brokenProductVariantId,
          order.brokenBags,
        ),
      ].where((item) => item.totalWeightKg > 0).toList();

  String? _validate(MillingOrder order) {
    if (!_isInProgress) return 'Chỉ có thể hoàn tất lệnh đang xay.';
    final outputs = _outputs(order);
    final rice = outputs.where((item) => item.type == 'RICE').firstOrNull;
    if (rice == null || rice.totalWeightKg <= 0) {
      return 'Cần có ít nhất một bao gạo thành phẩm.';
    }
    for (final output in outputs) {
      if (output.productVariantId <= 0) {
        return 'Chưa xác định được sản phẩm ${output.label}.';
      }
      if (!_outputLocationIds.containsKey(output.type)) {
        return 'Vui lòng chọn vị trí nhập kho cho ${output.label}.';
      }
      if (output.bags.any((bag) => !bag.weightKg.isFinite || bag.weightKg <= 0)) {
        return 'Khối lượng bao ${output.label} không hợp lệ.';
      }
    }
    final totalOutput = outputs.fold<double>(
      0,
      (sum, output) => sum + output.totalWeightKg,
    );
    if (order.inputWeightKg > 0 && totalOutput > order.inputWeightKg * 1.02) {
      return 'Tổng đầu ra vượt quá khối lượng lúa đầu vào cho phép.';
    }
    final expectedRice = order.totalRiceOutputKg;
    final riceDeviation = expectedRice > 0
        ? ((rice.totalWeightKg - expectedRice).abs() / expectedRice) * 100
        : 0;
    if (riceDeviation > 2 && _noteController.text.trim().isEmpty) {
      return 'Sản lượng gạo lệch trên 2%. Vui lòng nhập ghi chú giải thích.';
    }
    return null;
  }

  Future<void> _chooseLocation(_OutputDraft output) async {
    if (_loadingLocationType != null) return;
    setState(() {
      _loadingLocationType = output.type;
      _errorMessage = null;
    });
    try {
      List<MillingPutawaySuggestion> suggestions = const [];
      try {
        suggestions = await widget.repository.getPutawaySuggestions(
          warehouseId: widget.order.warehouseId,
          productVariantId: output.productVariantId,
          requiredWeightKg: output.totalWeightKg,
        );
      } catch (_) {
        // Fallback read-only locations are loaded below.
      }
      var locations = const <MillingLocation>[];
      if (suggestions.isEmpty) {
        locations = (await widget.repository.getLocations())
            .where(
              (location) =>
                  location.warehouseId == widget.order.warehouseId &&
                  location.isActive &&
                  !location.isQuarantine &&
                  (location.maxCapacity == null ||
                      location.maxCapacity! - location.currentOccupancy >=
                          output.totalWeightKg) &&
                  (location.currentProductVariantId == null ||
                      location.currentProductVariantId ==
                          output.productVariantId),
            )
            .toList();
      }
      if (!mounted) return;
      final selectedId = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => _LocationPickerSheet(
          outputLabel: output.label,
          suggestions: suggestions,
          locations: locations,
        ),
      );
      if (selectedId != null && mounted) {
        setState(() => _outputLocationIds[output.type] = selectedId);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = 'Không tải được vị trí nhập kho: $error');
      }
    } finally {
      if (mounted) setState(() => _loadingLocationType = null);
    }
  }

  Future<void> _complete() async {
    final validation = _validate(widget.order);
    if (validation != null) {
      setState(() => _errorMessage = validation);
      return;
    }
    setState(() => _isCompleting = true);
    try {
      await widget.repository.completeOrder(
        widget.order,
        outputLocationIds: Map<String, int>.of(_outputLocationIds),
        note: _noteController.text,
      );
      final detail = await widget.repository.getMillingOrderDetail(widget.order.id);
      if ((detail.statusCode ?? '').trim().toUpperCase() != 'COMPLETED') {
        throw const MillingApiException(
          'Backend chưa xác nhận lệnh đã hoàn tất. Vui lòng tải lại.',
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.milling,
        (route) => false,
      );
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _friendlyError(error));
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

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final validation = _validateOutputDrafts().firstOrNull;
    return Scaffold(
      backgroundColor: millingBackground,
      appBar: const MillingAppBar(title: 'Nhập kết quả xay'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: millingGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mẻ ${order.millingCode} đã đủ dữ liệu cân',
                        style: const TextStyle(
                          color: Color(0xFF166534),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Lúa ${order.inputLotCode} · đầu vào ${order.inputWeightKg.toStringAsFixed(0)}kg',
                        style: const TextStyle(
                          color: Color(0xFF15803D),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ResultStat(
                  label: 'Gạo',
                  value: '${order.totalRiceKg.toStringAsFixed(0)}kg',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ResultStat(
                  label: 'Cám',
                  value: '${order.totalBranKg.toStringAsFixed(1)}kg',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ResultStat(
                  label: 'Yield gạo',
                  value: '${order.riceYieldPercent.toStringAsFixed(1)}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Các đầu ra', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          _draftSummary(),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final item in const [('BROKEN', 'Tấm'), ('BRAN', 'Cám'), ('HUSK', 'Trấu')])
              OutlinedButton(
                onPressed: _outputForms.any((form) => form.type == item.$1)
                    ? null
                    : () => _addOutput(item.$1, item.$2),
                child: Text('+ ${item.$2}'),
              ),
          ]),
          if (_productsError != null)
            Text(_productsError!, style: const TextStyle(color: Colors.red)),
          for (final form in _outputForms) _outputFormCard(form),
          TextField(
            controller: _noteController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Ghi chú hoàn tất (nếu cần)',
              hintText: 'Bắt buộc nếu sản lượng gạo lệch trên 2%',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if ((_errorMessage ?? validation) != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_errorMessage ?? validation!)),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: MillingPrimaryButton(
        label: 'Tiếp tục xác nhận',
        onPressed: _showLocalPreview,
      ),
    );
  }
}

class _MillingOutputForm {
  _MillingOutputForm({required this.type, required this.label, required this.isByproduct});

  factory _MillingOutputForm.fromValue(MillingOutputFormValue value) {
    final label = switch (value.type) {
      MillingOutputType.rice => 'Gạo',
      MillingOutputType.broken => 'Tấm',
      MillingOutputType.bran => 'Cám',
      MillingOutputType.husk => 'Trấu',
    };
    return _MillingOutputForm(type: value.type.code, label: label, isByproduct: value.type.isByproduct)
      ..productVariantId = value.productVariantId
      ..locationId = value.locationId
      ..bagController.text = value.bagCount?.toString() ?? ''
      ..kgPerBagController.text = value.kgPerBag?.toString() ?? ''
      ..weightController.text = value.outputWeightKg?.toString() ?? '';
  }

  final String type;
  final String label;
  final bool isByproduct;
  int? productVariantId;
  int? locationId;
  final bagController = TextEditingController();
  final kgPerBagController = TextEditingController();
  final weightController = TextEditingController();

  int? get bagCount => int.tryParse(bagController.text.trim());
  double? get kgPerBag => double.tryParse(kgPerBagController.text.trim().replaceAll(',', '.'));
  double? get outputWeightKg => double.tryParse(weightController.text.trim().replaceAll(',', '.'));

  void dispose() {
    bagController.dispose();
    kgPerBagController.dispose();
    weightController.dispose();
  }
}

class _OutputDraft {
  const _OutputDraft(this.type, this.label, this.productVariantId, this.bags);

  final String type;
  final String label;
  final int productVariantId;
  final List<MillingBag> bags;

  double get totalWeightKg =>
      bags.fold<double>(0, (sum, bag) => sum + bag.weightKg);
}

class _OutputLocationCard extends StatelessWidget {
  const _OutputLocationCard({
    required this.output,
    required this.selectedLocationId,
    required this.isLoading,
    required this.onChoose,
  });

  final _OutputDraft output;
  final int? selectedLocationId;
  final bool isLoading;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final selected = selectedLocationId == null
        ? 'Chưa chọn vị trí nhập kho'
        : 'Đã chọn vị trí #$selectedLocationId';
    return Card(
      child: ListTile(
        leading: Icon(
          output.type == 'RICE' ? Icons.rice_bowl_outlined : Icons.inventory_2_outlined,
          color: selectedLocationId == null ? Colors.orange : millingGreen,
        ),
        title: Text('${output.label} · ${output.totalWeightKg.toStringAsFixed(1)} kg'),
        subtitle: Text('$selected · ${output.bags.length} bao'),
        trailing: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: onChoose,
                child: Text(selectedLocationId == null ? 'Chọn' : 'Đổi'),
              ),
      ),
    );
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
                  leading: const Icon(Icons.auto_awesome, color: millingGreen),
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

class _ResultStat extends StatelessWidget {
  const _ResultStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactBagColumn extends StatelessWidget {
  const _CompactBagColumn({
    required this.title,
    required this.bags,
    required this.color,
  });

  final String title;
  final List<MillingBag> bags;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          for (final bag in bags)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Bao ${bag.index}: ${bag.weightKg.toStringAsFixed(1)}kg',
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

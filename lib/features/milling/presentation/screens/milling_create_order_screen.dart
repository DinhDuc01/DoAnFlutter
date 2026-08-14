import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../sales_orders/data/sales_order_repository.dart';
import '../../../sales_orders/models/sales_order.dart';
import '../../../thu_mua/data/paddy_variety_api.dart';
import '../../data/api_milling_repository.dart';
import '../../data/milling_repository.dart';
import '../../models/milling_order.dart';
import '../../models/milling_plan_args.dart';

class MillingCreateOrderScreen extends StatefulWidget {
  const MillingCreateOrderScreen({
    this.repository,
    this.salesOrderRepository,
    this.riceVarietiesLoader,
    this.args,
    this.order,
    super.key,
  });

  final MillingRepository? repository;
  final SalesOrderRepository? salesOrderRepository;
  final Future<List<RiceVarietyOption>> Function()? riceVarietiesLoader;
  final MillingPlanArgs? args;
  final MillingOrder? order;

  @override
  State<MillingCreateOrderScreen> createState() =>
      _MillingCreateOrderScreenState();
}

class _MillingCreateOrderScreenState extends State<MillingCreateOrderScreen> {
  late final MillingRepository _repository;
  late final SalesOrderRepository _salesOrderRepository;
  final PaddyVarietyApi _varietyApi = PaddyVarietyApi();
  late Future<List<dynamic>> _dataFuture;

  final _formKey = GlobalKey<FormState>();
  final _inputController = TextEditingController(); // Nhập gạo dự kiến (kg)
  final _yieldController = TextEditingController(text: '0.68'); // Mặc định giống web
  final _reasonController = TextEditingController();
  final _moistureController = TextEditingController();
  final _millingCostController = TextEditingController();
  final _incidentalCostController = TextEditingController();

  MillingPaddyLotOption? _selectedLot;
  int? _selectedWarehouseId;
  int? _selectedRiceVarietyId;
  int? _selectedSalesOrderId;
  String _millingSource = 'production_plan';
  DateTime? _expectedCompletionDate;
  bool _submitting = false;
  String? _submitError;

  bool _initialAutoFilled = false;

  bool get _canEditOrder {
    if (widget.order == null) return true;
    return widget.order!.statusCode?.trim().toUpperCase() == 'DRAFT';
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiMillingRepository();
    _salesOrderRepository = widget.salesOrderRepository ?? ApiSalesOrderRepository();
    if (widget.order != null) {
      _selectedWarehouseId = widget.order!.warehouseId;
      _selectedRiceVarietyId = widget.order!.riceVarietyId;
      _selectedSalesOrderId = widget.order!.salesOrderId;
      _millingSource = widget.order!.salesOrderId != null ? 'sales_order' : 'production_plan';
      _inputController.text = widget.order!.totalRiceOutputKg.toStringAsFixed(1);
      _yieldController.text = widget.order!.yieldRateUsed.toStringAsFixed(2);
      _reasonController.text = widget.order!.reason ?? '';
      _moistureController.text = widget.order!.moisturePercent?.toString() ?? '';
      _millingCostController.text = widget.order!.millingCost?.toString() ?? '';
      _incidentalCostController.text = widget.order!.incidentalCost?.toString() ?? '';
      _expectedCompletionDate = widget.order!.expectedCompletionDate;
      _initialAutoFilled = true;
    } else if (widget.args != null) {
      _millingSource = widget.args!.isSalesOrder ? 'sales_order' : 'production_plan';
      _selectedSalesOrderId = widget.args!.salesOrderId;
      if (widget.args!.remainingRiceKg != null) {
        _inputController.text = widget.args!.remainingRiceKg!.toStringAsFixed(1);
      }
    }
    _loadData();
    _inputController.addListener(_refreshOutput);
    _yieldController.addListener(_refreshOutput);
  }

  void _loadData() {
    final salesOrderId = widget.order?.salesOrderId ?? widget.args?.salesOrderId;
    _dataFuture = Future.wait([
      _repository.getPaddyLots(),
      widget.riceVarietiesLoader != null
          ? widget.riceVarietiesLoader!()
          : _varietyApi.getRiceVarieties(),
      _salesOrderRepository.getPaged(pageSize: 100),
      _repository.getWarehouses(),
      if (salesOrderId != null)
        _loadLinkedSalesOrder(salesOrderId)
      else
        Future.value(null),
    ]);
  }

  Future<SalesOrderDetail?> _loadLinkedSalesOrder(int id) async {
    try {
      return await _salesOrderRepository.getById(id);
    } catch (_) {
      // The linked ID is part of the milling order contract. Keep the form
      // usable and preserve it even when the optional detail lookup fails.
      return null;
    }
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

  void _retryData() => setState(_loadData);

  double? _number(TextEditingController controller) {
    final value = double.tryParse(controller.text.trim().replaceAll(',', '.'));
    return value != null && value.isFinite ? value : null;
  }

  /// Lúa dự kiến tính ngược = Gạo dự kiến / Yield
  double? get _calculatedPaddyInput {
    final targetRice = _number(_inputController);
    final yieldRate = _number(_yieldController);
    return targetRice == null || yieldRate == null || yieldRate <= 0
        ? null
        : targetRice / yieldRate;
  }

  List<MillingPaddyLotOption> _filteredLots(
    List<MillingPaddyLotOption> lots,
  ) {
    if (_selectedWarehouseId == null) return const [];
    return lots.where((lot) {
      final matchesWarehouse = lot.warehouseId == _selectedWarehouseId;
      final matchesVariety = _selectedRiceVarietyId == null ||
          lot.riceVarietyId == _selectedRiceVarietyId;
      return matchesWarehouse && matchesVariety;
    }).toList();
  }

  String? _validateTargetRice(String? value) {
    final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      return 'Nhập khối lượng lớn hơn 0';
    }
    final paddy = _calculatedPaddyInput;
    if (_selectedLot != null && paddy != null && paddy > _selectedLot!.remainingWeightKg) {
      return 'Cần ${paddy.toStringAsFixed(1)} kg lúa, vượt quá ${_selectedLot!.remainingWeightKg.toStringAsFixed(1)} kg khả dụng';
    }
    return null;
  }

  String? _validateYield(String? value) {
    final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
    return parsed == null || !parsed.isFinite || parsed <= 0 || parsed > 1
        ? 'Nhập tỷ lệ trong khoảng 0 đến 1 (ví dụ 0.68)'
        : null;
  }

  double? _optionalNumber(TextEditingController controller) {
    if (controller.text.trim().isEmpty) return null;
    return _number(controller);
  }

  Future<void> _submit() async {
    if (!_canEditOrder) {
      setState(() => _submitError = 'Chỉ có thể cập nhật lệnh ở trạng thái Nháp.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _submitError = null);
    if (!_formKey.currentState!.validate()) return;
    
    final warehouseId = _selectedWarehouseId;
    if (warehouseId == null) {
      setState(() => _submitError = 'Vui lòng chọn kho thực hiện.');
      return;
    }

    final targetRice = _number(_inputController);
    final yieldRate = _number(_yieldController);
    if (targetRice == null || yieldRate == null) return;

    final lot = _selectedLot;
    final calculatedPaddy = targetRice / yieldRate;

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
      if (widget.order != null) {
        await _repository.updateOrder(
          id: widget.order!.id,
          warehouseId: warehouseId,
          riceVarietyId: _selectedRiceVarietyId,
          expectedYield: yieldRate,
          targetRiceKg: targetRice,
          salesOrderId: _selectedSalesOrderId,
          reason: _reasonController.text,
          moisturePercent: moisture,
          millingCost: millingCost,
          incidentalCost: incidentalCost,
          expectedCompletionDate: _expectedCompletionDate,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật lệnh xay thành công.')),
        );
        Navigator.of(context).pop(true);
      } else {
        final id = await _repository.createOrder(
          warehouseId: warehouseId,
          riceVarietyId: _selectedRiceVarietyId,
          expectedYield: yieldRate,
          targetRiceKg: targetRice,
          salesOrderId: _selectedSalesOrderId,
          lot: lot,
          inputWeightKg: lot != null ? calculatedPaddy : null,
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
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = 'Không thể lưu lệnh xay: $error';
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
    if (picked != null && mounted) {
      setState(() => _expectedCompletionDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canEditOrder) {
      return Scaffold(
        backgroundColor: AppColors.backgroundFor(context),
        body: SafeArea(
          child: Column(
            children: [
              AppGradientHeader(
                title: 'Cập nhật lệnh xay',
                subtitle: 'Lệnh này không còn ở trạng thái Nháp',
                leading: IconButton(
                  tooltip: 'Quay lại',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
              ),
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Lệnh đã được giữ lúa hoặc xử lý tiếp nên không thể chỉnh sửa.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            AppGradientHeader(
              title: widget.order != null ? 'Cập nhật lệnh xay' : 'Tạo lệnh xay',
              subtitle: 'Đồng bộ cấu hình theo giống và độ ẩm',
              leading: IconButton(
                tooltip: 'Quay lại',
                onPressed: _submitting ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _dataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const FormSkeleton();
                  }
                  if (snapshot.hasError) {
                    return HErrorState(
                      message: 'Không tải được cấu hình từ hệ thống: ${snapshot.error}',
                      onRetry: _retryData,
                    );
                  }
                  final data = snapshot.data!;
                  final lots = data[0] as List<MillingPaddyLotOption>;
                  final varieties = data[1] as List<RiceVarietyOption>;
                  final salesOrdersPage = data[2] as SalesOrderPage;
                  final salesOrders = List<SalesOrderSummary>.from(salesOrdersPage.items);
                  final warehouses = data[3] as List<MillingFilterOption>;
                  final detailSo = (data.length > 4) ? data[4] as SalesOrderDetail? : null;

                  if (widget.order?.salesOrderId != null &&
                      !salesOrders.any((so) => so.id == widget.order!.salesOrderId) &&
                      detailSo == null) {
                    salesOrders.add(SalesOrderSummary(
                      id: widget.order!.salesOrderId!,
                      soCode: 'SO-${widget.order!.salesOrderId}',
                      customerId: 0,
                      customerName: '',
                      statusId: 0,
                      statusName: '',
                      statusCode: '',
                      channel: '',
                      orderDate: null,
                      requiresMilling: true,
                      totalAmount: 0,
                      totalRiceRequiredKg: widget.order!.totalRiceOutputKg,
                      remainingMillingRiceKg: 0,
                    ));
                  }

                  if (detailSo != null && !salesOrders.any((so) => so.id == detailSo.id)) {
                    salesOrders.add(SalesOrderSummary(
                      id: detailSo.id,
                      soCode: detailSo.soCode,
                      customerId: detailSo.customerId,
                      customerName: detailSo.customerName,
                      statusId: detailSo.statusId,
                      statusName: detailSo.statusName,
                      statusCode: detailSo.statusCode,
                      channel: detailSo.channel,
                      warehouseId: detailSo.warehouseId,
                      warehouseName: detailSo.warehouseName,
                      orderDate: detailSo.orderDate,
                      expectedDeliveryDate: detailSo.expectedDeliveryDate,
                      requiresMilling: detailSo.requiresMilling,
                      totalRiceRequiredKg: detailSo.items.fold(0.0, (sum, item) => sum + item.quantityOrdered),
                      remainingMillingRiceKg: detailSo.remainingAmount,
                      totalAmount: detailSo.totalAmount,
                    ));
                  }

                  // Perform one-time auto-fill check
                  if (!_initialAutoFilled && _selectedSalesOrderId != null) {
                    final index = salesOrders.indexWhere((so) => so.id == _selectedSalesOrderId);
                    if (index != -1) {
                      final matchingSo = salesOrders[index];
                      _selectedWarehouseId ??= matchingSo.warehouseId;
                      _selectedRiceVarietyId ??= matchingSo.riceVarietyId;
                      if (_inputController.text.isEmpty) {
                        _inputController.text = matchingSo.remainingMillingRiceKg.toStringAsFixed(1);
                      }
                      _initialAutoFilled = true;
                    }
                  }

                  return _buildForm(lots, varieties, salesOrders, warehouses);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(
    List<MillingPaddyLotOption> lots,
    List<RiceVarietyOption> varieties,
    List<SalesOrderSummary> salesOrders,
    List<MillingFilterOption> systemWarehouses,
  ) {
    final warehouses = <int, String>{
      for (final w in systemWarehouses) w.id: w.name,
    };
    final uniqueVarieties = <int, RiceVarietyOption>{
      for (final variety in varieties) variety.id: variety,
    }.values.toList();
    final uniqueSalesOrders = <int, SalesOrderSummary>{
      for (final salesOrder in salesOrders) salesOrder.id: salesOrder,
    }.values.toList();
    final isEditing = widget.order != null;
    final isSalesOrderLocked = _millingSource == 'sales_order' && _selectedSalesOrderId != null;
    final filteredLots = _filteredLots(lots);
    final filteredSalesOrders = uniqueSalesOrders
        .where((so) =>
            (so.requiresMilling && so.remainingMillingRiceKg > 0) ||
            (isEditing && so.id == _selectedSalesOrderId))
        .toList();

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _section('Thông tin chung', Icons.account_tree_rounded, [
            DropdownButtonFormField<String>(
              initialValue: _millingSource,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Nguồn lệnh *',
              ),
              items: const [
                DropdownMenuItem(value: 'production_plan', child: Text('Kế hoạch sản xuất')),
                DropdownMenuItem(value: 'sales_order', child: Text('Đơn bán cần xay')),
              ],
              onChanged: _submitting || isEditing || isSalesOrderLocked
                  ? null
                  : (value) => setState(() {
                        _millingSource = value ?? 'production_plan';
                        if (_millingSource != 'sales_order') {
                          _selectedSalesOrderId = null;
                        }
                      }),
            ),
            if (_millingSource == 'sales_order') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: filteredSalesOrders.any((so) => so.id == _selectedSalesOrderId)
                    ? _selectedSalesOrderId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Đơn bán *'),
                hint: const Text('Chọn đơn bán'),
                items: filteredSalesOrders
                    .map((so) => DropdownMenuItem<int>(
                          value: so.id,
                          child: Text(
                            '${so.soCode} · còn thiếu ${so.remainingMillingRiceKg.toStringAsFixed(1)} kg',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                validator: (value) =>
                    _millingSource == 'sales_order' && value == null ? 'Chọn đơn bán' : null,
                onChanged: _submitting || isSalesOrderLocked
                    ? null
                    : (value) {
                        setState(() {
                          _selectedSalesOrderId = value;
                          if (value != null) {
                            final selectedSo =
                                filteredSalesOrders.firstWhere((so) => so.id == value);
                            if (selectedSo.warehouseId != null) {
                              _selectedWarehouseId = selectedSo.warehouseId;
                            }
                            if (selectedSo.riceVarietyId != null) {
                              _selectedRiceVarietyId = selectedSo.riceVarietyId;
                            }
                            _inputController.text =
                                selectedSo.remainingMillingRiceKg.toStringAsFixed(1);
                          }
                        });
                      },
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: warehouses.containsKey(_selectedWarehouseId)
                  ? _selectedWarehouseId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Kho thực hiện *',
              ),
              items: warehouses.entries
                  .map((entry) => DropdownMenuItem<int>(
                        value: entry.key,
                        child: Text(entry.value, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              validator: (value) => value == null ? 'Chọn kho' : null,
              onChanged: _submitting || isSalesOrderLocked
                  ? null
                  : (value) => setState(() {
                        _selectedWarehouseId = value;
                        if (_selectedLot?.warehouseId != value) _selectedLot = null;
                      }),
            ),
            if (_selectedWarehouseId == null)
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Ch\u1ecdn kho'),
                ),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: uniqueVarieties.any((v) => v.id == _selectedRiceVarietyId)
                  ? _selectedRiceVarietyId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Giống lúa'),
              hint: const Text('Chọn giống lúa'),
              items: uniqueVarieties
                  .map((variety) => DropdownMenuItem<int>(
                        value: variety.id,
                        child: Text(variety.name, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: _submitting || isSalesOrderLocked
                  ? null
                  : (value) => setState(() {
                        _selectedRiceVarietyId = value;
                        if (_selectedLot != null && _selectedLot!.riceVarietyId != value) {
                          _selectedLot = null;
                        }
                      }),
            ),
          ]),
          _section('Sản lượng & Yield', Icons.percent_rounded, [
            TextFormField(
              controller: _yieldController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Yield áp dụng *',
                hintText: 'Ví dụ: 0.68',
              ),
              validator: _validateYield,
              enabled: !_submitting,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _inputController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Gạo dự kiến (kg) *',
                hintText: 'Nhập sản lượng gạo đầu ra mong muốn',
              ),
              validator: _validateTargetRice,
              enabled: !_submitting && !isEditing && !isSalesOrderLocked,
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Lúa dự kiến tính ngược',
                filled: true,
              ),
              child: Text(
                _calculatedPaddyInput == null
                    ? '0 kg'
                    : '${_calculatedPaddyInput!.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.success,
                  fontSize: 16.5,
                ),
              ),
            ),
          ]),
          if (widget.order == null)
            _section('Phân bổ lô lúa', Icons.scale_rounded, [
              DropdownButtonFormField<MillingPaddyLotOption>(
                value: filteredLots.contains(_selectedLot) ? _selectedLot : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Phân bổ lô/cột đầu vào',
                ),
                items: filteredLots
                    .map((lot) => DropdownMenuItem<MillingPaddyLotOption>(
                          value: lot,
                          child: Text(
                            '${lot.code} · còn ${lot.remainingWeightKg.toStringAsFixed(1)} kg',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (value) => setState(() {
                          _selectedLot = value;
                          if (value != null && value.riceVarietyId != null) {
                            _selectedRiceVarietyId = value.riceVarietyId;
                          }
                        }),
              ),
              if (_selectedLot == null)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Ch\u1ecdn l\u00f4 l\u00faa (kh\u00f4ng b\u1eaft bu\u1ed9c)',
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _selectedLot == null
                      ? 'Chưa phân bổ lô. Lệnh sẽ được lưu ở trạng thái Nháp.'
                      : 'Đã phân bổ từ: ${_selectedLot!.code} (khả dụng ${_selectedLot!.remainingWeightKg.toStringAsFixed(1)} kg)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _selectedLot == null ? AppColors.warning : AppColors.success,
                  ),
                ),
              ),
            ]),
          _section('Thời gian & Chi phí', Icons.event_note_rounded, [
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
              maxLines: 1,
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
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_task_rounded),
              label: Text(_submitting
                  ? 'Đang lưu...'
                  : widget.order != null
                      ? 'Cập nhật'
                      : 'Tạo lệnh nháp'),
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

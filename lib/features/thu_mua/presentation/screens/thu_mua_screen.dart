import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/auth_session_store.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../home/presentation/widgets/main_bottom_navigation.dart';
import '../../../products/data/product_variant_api.dart';
import '../../../scale/models/weight_reading.dart';
import '../../../scale/presentation/screens/scale_screen.dart';
import '../../data/api_thu_mua_repository.dart';
import '../../data/thu_mua_repository.dart';
import '../../models/thu_mua_receipt.dart';
import '../../models/purchase_schedule.dart';
import '../widgets/thu_mua_header.dart';
import '../widgets/thu_mua_note_field.dart';
import '../widgets/thu_mua_product_card.dart';
import '../widgets/thu_mua_quantity_stepper.dart';
import '../widgets/thu_mua_receipt_fields.dart';

class ThuMuaScreen extends StatefulWidget {
  const ThuMuaScreen({this.repository, this.schedule, this.draft, super.key});

  final ThuMuaRepository? repository;
  final PurchaseSchedule? schedule;
  final ThuMuaReceipt? draft;

  @override
  State<ThuMuaScreen> createState() => _ThuMuaScreenState();
}

class _ThuMuaScreenState extends State<ThuMuaScreen> {
  late final ThuMuaRepository _repository;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _unitCostController = TextEditingController();
  final TextEditingController _actualWeightController = TextEditingController();
  final TextEditingController _moistureController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();

  late final Future<ThuMuaReceipt> _receiptFuture;
  late final Future<List<ProductVariantStock>> _productsFuture;
  late final Future<List<ThuMuaSupplier>> _suppliersFuture;
  List<ProductVariantStock> _products = const [];
  ThuMuaReceipt? _receipt;
  int _quantity = 0;
  bool _quantityInitialized = false;
  bool _isSubmitting = false;
  bool _isChangingProduct = false;
  bool _useIotScale = true;

  double get _enteredWeight =>
      double.tryParse(_actualWeightController.text.trim()) ?? 0;

  double get _enteredUnitPrice =>
      double.tryParse(_unitCostController.text.trim()) ?? 0;

  double get _totalPurchaseAmount => _enteredWeight * _enteredUnitPrice;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiThuMuaRepository();
    _receiptFuture = _loadReceipt();
    _productsFuture = _loadProducts();
    _suppliersFuture = _loadSuppliers();
  }

  Future<ThuMuaReceipt> _loadReceipt() async {
    if (widget.draft != null) return widget.draft!;
    final receipt = await _repository.getDraftReceipt();
    final schedule = widget.schedule;
    if (schedule == null) return receipt;

    return receipt.copyWith(
      supplier: ThuMuaSupplier(
        id: schedule.farmerId,
        code: '',
        name: schedule.farmerName,
      ),
      scheduleId: schedule.id,
      riceVarietyId: schedule.riceVarietyId,
      actualWeightKg: schedule.estimatedWeightKg,
      expectedDate: schedule.scheduledAt,
      unitCostPrice: schedule.expectedPrice,
      warehouseId: schedule.warehouseId ?? 0,
      warehouseName: schedule.warehouseName ?? '',
    );
  }

  Future<List<ThuMuaSupplier>> _loadSuppliers() async {
    return _repository.getSuppliers();
  }

  Future<List<ProductVariantStock>> _loadProducts() async {
    final products = await _repository.getSelectableProducts();
    _products = products;
    return products;
  }

  @override
  void dispose() {
    _noteController.dispose();
    _unitCostController.dispose();
    _actualWeightController.dispose();
    _moistureController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  void _setInitialQuantity(ThuMuaReceipt receipt) {
    if (_quantityInitialized) return;
    _receipt = receipt;
    _quantity = receipt.quantity;
    if (_unitCostController.text.isEmpty && receipt.unitCostPrice > 0) {
      _unitCostController.text = receipt.unitCostPrice.toStringAsFixed(0);
    }
    if (_actualWeightController.text.isEmpty && receipt.actualWeightKg > 0) {
      _actualWeightController.text = receipt.actualWeightKg.toStringAsFixed(1);
    }
    if (_moistureController.text.isEmpty && receipt.moisturePercent != null) {
      _moistureController.text = receipt.moisturePercent!.toStringAsFixed(1);
    }
    _quantityInitialized = true;
  }

  void _changeQuantity(int value) {
    if (_isSubmitting) return;
    setState(() => _quantity = value);
  }

  Future<void> _changeProduct(int? productVariantId) async {
    if (productVariantId == null ||
        productVariantId == _receipt?.productVariantId ||
        _isChangingProduct ||
        _isSubmitting) {
      return;
    }
    final product =
        _products.where((item) => item.id == productVariantId).firstOrNull;
    if (product == null) return;

    setState(() => _isChangingProduct = true);
    try {
      final receipt = await _repository.getDraftReceiptForProduct(product);
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _quantity = receipt.quantity;
        _quantityInitialized = true;
        _noteController.clear();
        _unitCostController.text = receipt.unitCostPrice > 0
            ? receipt.unitCostPrice.toStringAsFixed(0)
            : '';
        _actualWeightController.clear();
        _moistureController.clear();
        _paidAmountController.clear();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không chọn được sản phẩm: $error')),
      );
    } finally {
      if (mounted) setState(() => _isChangingProduct = false);
    }
  }

  Future<void> _showProductPicker(ThuMuaReceipt receipt) async {
    if (_isChangingProduct || _isSubmitting || _products.isEmpty) return;

    final selectedId = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  'Chọn sản phẩm cần thu mua',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: _products.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    final isSelected = product.id == receipt.productVariantId;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : AppColors.surfaceFor(context),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondaryFor(context),
                        ),
                      ),
                      title: Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${product.sku} · Tồn hiện tại ${product.quantityOnHand} kg',
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: AppColors.primary,
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).pop(product.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedId != null && mounted) {
      await _changeProduct(selectedId);
    }
  }

  Future<void> _confirmInbound() async {
    final receipt = _receipt;
    if (receipt == null || _isSubmitting) return;

    if (_quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số lượng nhập phải lớn hơn 0')),
      );
      return;
    }
    if (receipt.warehouseId <= 0 || receipt.warehouseName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chưa xác định kho nhập. Vui lòng chọn kho trước khi lưu phiếu.',
          ),
        ),
      );
      return;
    }
    final unitCostPrice = double.tryParse(_unitCostController.text.trim()) ?? 0;
    final actualWeightKg =
        double.tryParse(_actualWeightController.text.trim()) ?? 0;
    final moisturePercent = double.tryParse(_moistureController.text.trim());
    final paidAmount = double.tryParse(_paidAmountController.text.trim()) ?? 0;
    if (receipt.supplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn nông dân')),
      );
      return;
    }
    if (unitCostPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đơn giá nhập phải lớn hơn 0')),
      );
      return;
    }
    if (actualWeightKg <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Khối lượng thực tế phải lớn hơn 0')),
      );
      return;
    }
    if (moisturePercent == null ||
        moisturePercent < 0 ||
        moisturePercent > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Độ ẩm phải nằm trong khoảng 0-100%')),
      );
      return;
    }
    final totalAmount = actualWeightKg * unitCostPrice;
    if (paidAmount < 0 || paidAmount > totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số tiền đã trả không hợp lệ')),
      );
      return;
    }

    if (receipt.id != null) {
      final shouldUpdate = await _confirmDraftUpdate();
      if (!shouldUpdate || !mounted) return;
    }

    setState(() => _isSubmitting = true);

    try {
      final submission = await _repository.confirmInbound(
        receipt: receipt.copyWith(
          actualWeightKg: actualWeightKg,
          moisturePercent: moisturePercent,
          paidAmount: paidAmount,
        ),
        quantity: _quantity,
        unitCostPrice: unitCostPrice,
        note: _noteController.text,
      );

      if (!mounted) return;

      if (receipt.id != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu thay đổi phiếu nháp.')),
        );
        Navigator.of(context).pop(true);
        return;
      }

      final user = AuthSessionStore.current?.user;
      final result = ThuMuaSuccessResult(
        receiptCode: submission.code,
        quantity: _quantity,
        productName: receipt.productName,
        sku: receipt.sku,
        warehouseName: receipt.warehouseName,
        performedBy: user?.fullName.isNotEmpty == true
            ? user!.fullName
            : 'Nhân viên kho',
        completedAt: DateTime.now(),
        orderId: submission.id,
        status: submission.status,
        unitCostPrice: unitCostPrice,
        expectedDate: receipt.expectedDate,
        actualWeightKg: actualWeightKg,
        moisturePercent: moisturePercent,
        debtAmount: (actualWeightKg * unitCostPrice - paidAmount)
            .clamp(0, double.infinity),
      );

      Navigator.of(context).pushReplacementNamed(
        AppRoutes.thuMuaSuccess,
        arguments: result,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            receipt.id != null
                ? 'Không lưu được phiếu nháp: $error'
                : 'Không tạo được phiếu nhập: $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<bool> _confirmDraftUpdate() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lưu thay đổi phiếu nháp?'),
        content: const Text(
          'Thông tin hiện tại sẽ được cập nhật lên hệ thống. Phiếu vẫn ở trạng thái nháp và chưa được chốt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Lưu thay đổi'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _readIotWeight() async {
    final reading = await Navigator.of(context).push<WeightReading>(
      MaterialPageRoute(builder: (_) => const ScaleScreen()),
    );
    if (!mounted || reading == null) return;
    setState(() {
      _actualWeightController.text = reading.weight.toStringAsFixed(3);
    });
  }

  void _openMainTab(int index) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => HomeScreen(initialIndex: index),
      ),
      (route) => false,
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SkeletonBox(height: 80),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(child: _SkeletonBox(height: 64)),
              SizedBox(width: 10),
              Expanded(child: _SkeletonBox(height: 64)),
            ],
          ),
          const SizedBox(height: 12),
          const _SkeletonBox(height: 110),
          const SizedBox(height: 12),
          const _SkeletonBox(height: 80),
          const SizedBox(height: 60),
          Center(
            child: Column(
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  'Đang tải thông tin sản phẩm...',
                  style: TextStyle(
                    color: AppColors.textSecondaryFor(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object? error) {
    final message = error is ProductVariantApiException
        ? error.message
        : 'Không tải được phiếu nhập kho';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimaryFor(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptForm(ThuMuaReceipt receipt) {
    _setInitialQuantity(receipt);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FutureBuilder<List<ProductVariantStock>>(
            future: _productsFuture,
            builder: (context, snapshot) {
              final products = snapshot.data ?? const [];
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (products.isEmpty) return const SizedBox.shrink();
              return InkWell(
                key: ValueKey('inbound_product_${receipt.productVariantId}'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showProductPicker(receipt),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Chọn sản phẩm thu mua',
                    prefixIcon: const Icon(Icons.inventory_2_outlined),
                    suffixIcon: _isChangingProduct
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.expand_more),
                  ),
                  child: Text(
                    '${receipt.productName} · ${receipt.sku}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<ThuMuaSupplier>>(
            future: _suppliersFuture,
            builder: (context, snapshot) {
              final suppliers = snapshot.data ?? const [];
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              return DropdownButtonFormField<int>(
                initialValue: receipt.supplier?.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Nông dân',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                items: [
                  for (final supplier in suppliers)
                    DropdownMenuItem(
                      value: supplier.id,
                      child: Text(
                        '${supplier.code} - ${supplier.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) {
                  final supplier =
                      suppliers.where((item) => item.id == id).firstOrNull;
                  if (supplier != null) {
                    setState(() {
                      _receipt = receipt.copyWith(supplier: supplier);
                    });
                  }
                },
              );
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _unitCostController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Đơn giá',
              suffixText: 'đ/kg',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                icon: Icon(Icons.bluetooth),
                label: Text('Cân IoT'),
              ),
              ButtonSegment(
                value: false,
                icon: Icon(Icons.edit_outlined),
                label: Text('Cân thường'),
              ),
            ],
            selected: {_useIotScale},
            onSelectionChanged: (values) {
              setState(() => _useIotScale = values.first);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('thu_mua_actual_weight'),
            controller: _actualWeightController,
            readOnly: _useIotScale,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Khối lượng thực tế',
              suffixText: 'kg',
              prefixIcon: const Icon(Icons.scale_outlined),
              helperText: _useIotScale
                  ? 'Mở cân IoT để nhận khối lượng ổn định'
                  : 'Nhập khối lượng khi dùng cân thường',
              suffixIcon: _useIotScale
                  ? IconButton(
                      tooltip: 'Mở cân IoT',
                      onPressed: _readIotWeight,
                      icon: const Icon(Icons.bluetooth_searching),
                    )
                  : null,
            ),
            onTap: _useIotScale ? _readIotWeight : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('thu_mua_moisture'),
            controller: _moistureController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Độ ẩm',
              suffixText: '%',
              prefixIcon: Icon(Icons.water_drop_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _paidAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Số tiền đã trả',
              suffixText: 'đ',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _PurchaseAmountSummary(
            unitPrice: _enteredUnitPrice,
            actualWeightKg: _enteredWeight,
            totalAmount: _totalPurchaseAmount,
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            tileColor: AppColors.surfaceFor(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.borderFor(context)),
            ),
            leading: const Icon(Icons.event_outlined),
            title: const Text('Ngày dự kiến nhập kho'),
            subtitle: Text(_formatDate(receipt.expectedDate)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final selected = await showDatePicker(
                context: context,
                initialDate: receipt.expectedDate ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (selected != null && mounted) {
                setState(() {
                  _receipt = receipt.copyWith(expectedDate: selected);
                });
              }
            },
          ),
          const SizedBox(height: 12),
          ThuMuaProductCard(receipt: receipt),
          const SizedBox(height: 12),
          ThuMuaReceiptFields(receipt: receipt),
          const SizedBox(height: 12),
          ThuMuaQuantityStepper(
            quantity: _quantity,
            onChanged: _changeQuantity,
          ),
          const SizedBox(height: 12),
          ThuMuaNoteField(
            controller: _noteController,
            labelText: 'Ghi chú',
            hintText: receipt.noteHint,
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _isSubmitting ? null : _confirmInbound,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor:
                  AppColors.primary.withValues(alpha: 0.55),
              minimumSize: const Size.fromHeight(48),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    receipt.id != null
                        ? 'Lưu thay đổi phiếu nháp'
                        : 'Tạo phiếu chờ xác nhận',
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        child: FutureBuilder<ThuMuaReceipt>(
          future: _receiptFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) _setInitialQuantity(snapshot.data!);
            final receipt = _receipt ?? snapshot.data;

            return Column(
              children: [
                ThuMuaHeader(status: receipt?.status ?? 'Chờ xác nhận'),
                Expanded(
                  child: switch (snapshot.connectionState) {
                    ConnectionState.done when snapshot.hasData =>
                      _buildReceiptForm(receipt!),
                    ConnectionState.done => _buildErrorState(
                        context,
                        snapshot.error,
                      ),
                    _ => _buildLoadingState(context),
                  },
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: MainBottomNavigation(
        currentIndex: 1,
        onTap: _openMainTab,
      ),
    );
  }
}

class _PurchaseAmountSummary extends StatelessWidget {
  const _PurchaseAmountSummary({
    required this.unitPrice,
    required this.actualWeightKg,
    required this.totalAmount,
  });

  final double unitPrice;
  final double actualWeightKg;
  final double totalAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7EE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB7E4C7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TỔNG TIỀN PHIẾU NÀY',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '${totalAmount.toStringAsFixed(0)} đ',
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${actualWeightKg.toStringAsFixed(1)} kg × ${unitPrice.toStringAsFixed(0)} đ/kg',
            style: TextStyle(
              color: AppColors.textSecondaryFor(context),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Đơn giá chỉ áp dụng cho phiếu này; giá gốc sản phẩm không thay đổi.',
            style: TextStyle(
              color: AppColors.textSecondaryFor(context),
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) return 'Chưa chọn';
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.isDark(context)
            ? Colors.grey.shade800
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

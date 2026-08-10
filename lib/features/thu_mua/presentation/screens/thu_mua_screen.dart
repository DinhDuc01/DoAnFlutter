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
import '../../data/paddy_variety_api.dart';
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

  final PaddyVarietyApi _varietyApi = PaddyVarietyApi();
  late final Future<ThuMuaReceipt> _receiptFuture;
  late final Future<List<ProductVariantStock>> _productsFuture;
  late final Future<List<ThuMuaSupplier>> _suppliersFuture;
  late final Future<List<RiceVarietyOption>> _varietiesFuture;
  List<ProductVariantStock> _products = const [];
  List<RiceVarietyOption> _varieties = const [];
  // variantId -> riceVarietyId (để lọc sản phẩm theo giống đã chọn)
  Map<int, int?> _variantVarietyMap = const {};
  int? _riceVarietyId;
  /// Ngưỡng khối lượng trung bình tối đa cho mỗi bao lúa (kg). Vượt ngưỡng này
  /// coi là nhập sai (ví dụ nhầm tổng khối lượng với số bao).
  static const int _maxKgPerBag = 200;

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
    _varietiesFuture = _loadVarieties();
  }

  /// Tải danh sách giống lúa + bản đồ variant→giống (đồng bộ web: chọn giống
  /// trước, sau đó lọc sản phẩm theo giống).
  Future<List<RiceVarietyOption>> _loadVarieties() async {
    try {
      final varieties = await _varietyApi.getRiceVarieties();
      final variants = await _varietyApi.getProductVariants();
      _varieties = varieties;
      _variantVarietyMap = {
        for (final v in variants) v.id: v.riceVarietyId,
      };
      return varieties;
    } catch (_) {
      // Không chặn form nếu API giống lúa lỗi — vẫn cho chọn sản phẩm như cũ.
      _varieties = const [];
      _variantVarietyMap = const {};
      return const [];
    }
  }

  int? _varietyOf(int variantId) => _variantVarietyMap[variantId];

  /// Sản phẩm hiện chọn đã khớp giống đã chọn chưa (khi có dữ liệu giống).
  bool _productMatchesVariety(int productVariantId) {
    if (_riceVarietyId == null) return true;
    if (_variantVarietyMap.isEmpty) return true; // không có dữ liệu → không chặn
    return _varietyOf(productVariantId) == _riceVarietyId;
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
    _riceVarietyId ??= receipt.riceVarietyId;
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
      final varietyId =
          _varietyOf(product.id) ?? _riceVarietyId ?? receipt.riceVarietyId;
      setState(() {
        _riceVarietyId = varietyId;
        _receipt = receipt.copyWith(riceVarietyId: varietyId);
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

    // Lọc sản phẩm theo giống lúa đã chọn (khi có dữ liệu giống).
    final products = (_riceVarietyId != null && _variantVarietyMap.isNotEmpty)
        ? _products
            .where((item) => _varietyOf(item.id) == _riceVarietyId)
            .toList()
        : _products;
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giống lúa này chưa có sản phẩm tương ứng.'),
        ),
      );
      return;
    }

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
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = products[index];
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
    // Bắt buộc chọn giống lúa trước, rồi sản phẩm thuộc giống đó (đồng bộ web).
    if (_varieties.isNotEmpty && _riceVarietyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn giống lúa')),
      );
      return;
    }
    if (receipt.productVariantId <= 0 ||
        !_productMatchesVariety(receipt.productVariantId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn sản phẩm thuộc giống lúa đã chọn'),
        ),
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
    // Ràng buộc tỉ lệ khối lượng/số bao: chặn giá trị vô lý
    // (ví dụ 500000 kg cho 2 bao). Bao lúa thực tế hiếm khi vượt _maxKgPerBag.
    final avgKgPerBag = actualWeightKg / _quantity;
    if (avgKgPerBag > _maxKgPerBag) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Trung bình ${avgKgPerBag.toStringAsFixed(0)} kg/bao vượt mức hợp lý '
            '(tối đa $_maxKgPerBag kg/bao). Kiểm tra lại số bao hoặc khối lượng.',
          ),
        ),
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
          riceVarietyId: _riceVarietyId ?? receipt.riceVarietyId,
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
          // 1) Chọn GIỐNG LÚA trước (đồng bộ web).
          FutureBuilder<List<RiceVarietyOption>>(
            future: _varietiesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              final varieties = _varieties;
              if (varieties.isEmpty) return const SizedBox.shrink();
              final value =
                  varieties.any((v) => v.id == _riceVarietyId)
                      ? _riceVarietyId
                      : null;
              return DropdownButtonFormField<int>(
                initialValue: value,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Giống lúa',
                  prefixIcon: Icon(Icons.grass_outlined),
                ),
                items: [
                  for (final v in varieties)
                    DropdownMenuItem(
                      value: v.id,
                      child: Text(
                        v.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _isSubmitting || _isChangingProduct
                    ? null
                    : (id) => setState(() => _riceVarietyId = id),
              );
            },
          ),
          const SizedBox(height: 12),
          // 2) Chọn SẢN PHẨM — lọc theo giống đã chọn; khoá tới khi có giống.
          FutureBuilder<List<ProductVariantStock>>(
            future: _productsFuture,
            builder: (context, snapshot) {
              final products = snapshot.data ?? const [];
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (products.isEmpty) return const SizedBox.shrink();
              final hasVarietyData = _varieties.isNotEmpty;
              final varietyChosen = _riceVarietyId != null || !hasVarietyData;
              final matches = _productMatchesVariety(receipt.productVariantId);
              final showProduct = receipt.productVariantId > 0 && matches;
              return InkWell(
                key: ValueKey(
                  'inbound_product_${receipt.productVariantId}_$_riceVarietyId',
                ),
                borderRadius: BorderRadius.circular(12),
                onTap:
                    varietyChosen ? () => _showProductPicker(receipt) : null,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Chọn sản phẩm thu mua',
                    prefixIcon: const Icon(Icons.inventory_2_outlined),
                    helperText:
                        varietyChosen ? null : 'Vui lòng chọn giống lúa trước',
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
                    showProduct
                        ? '${receipt.productName} · ${receipt.sku}'
                        : 'Chọn sản phẩm thu mua',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: showProduct
                          ? AppColors.textPrimaryFor(context)
                          : AppColors.textTertiary,
                    ),
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
          const SizedBox(height: 8),
          _QuantityWeightHint(
            quantity: _quantity,
            actualWeightKg: _enteredWeight,
            maxKgPerBag: _maxKgPerBag,
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

/// Dòng nhắc đơn vị + trung bình kg/bao, cảnh báo khi tỉ lệ vô lý.
class _QuantityWeightHint extends StatelessWidget {
  const _QuantityWeightHint({
    required this.quantity,
    required this.actualWeightKg,
    required this.maxKgPerBag,
  });

  final int quantity;
  final double actualWeightKg;
  final int maxKgPerBag;

  @override
  Widget build(BuildContext context) {
    final hasData = quantity > 0 && actualWeightKg > 0;
    final avg = hasData ? actualWeightKg / quantity : 0;
    final tooHigh = hasData && avg > maxKgPerBag;

    final Color fg;
    final Color bg;
    final IconData icon;
    final String text;
    if (!hasData) {
      fg = AppColors.textSecondary;
      bg = AppColors.canvasAlt;
      icon = Icons.info_outline_rounded;
      text = 'Đơn vị: bao • nhập khối lượng (kg) để tính trung bình mỗi bao';
    } else if (tooHigh) {
      fg = AppColors.danger;
      bg = AppColors.dangerTint;
      icon = Icons.error_outline_rounded;
      text =
          'Trung bình ${avg.toStringAsFixed(0)} kg/bao — vượt mức hợp lý (tối đa $maxKgPerBag kg/bao). Kiểm tra lại số bao hoặc khối lượng.';
    } else {
      fg = AppColors.primaryDark;
      bg = AppColors.brandTint;
      icon = Icons.check_circle_outline_rounded;
      text =
          'Đơn vị: bao • trung bình ${avg.toStringAsFixed(1)} kg/bao ($quantity bao · ${actualWeightKg.toStringAsFixed(1)} kg)';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: fg,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
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

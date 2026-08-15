import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../auth/data/auth_session_store.dart';
import '../../../products/data/product_variant_api.dart';
import '../../../scale/models/weight_reading.dart';
import '../../../scale/presentation/widgets/scale_bar.dart';
import '../../data/api_thu_mua_repository.dart';
import '../../data/paddy_variety_api.dart';
import '../../data/thu_mua_repository.dart';
import '../../models/thu_mua_receipt.dart';
import '../../models/purchase_schedule.dart';
import '../widgets/thu_mua_header.dart';
import '../widgets/thu_mua_note_field.dart';
import '../widgets/thu_mua_product_card.dart';
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
  final TextEditingController _moistureController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();
  final List<TextEditingController> _bagWeightControllers = [];
  List<String?> _bagWeightErrors = [];

  /// Bao nào có số đến từ cân điện tử (phần còn lại là gõ tay).
  final List<bool> _bagFromScale = [];

  /// Bao sẽ nhận số cân kế tiếp. Trỏ vào bao đang trống; nếu bao đó đã có số
  /// thì lần cân sau sinh thêm một bao mới ngay dưới.
  int _bagTargetIndex = 0;

  /// Tên cân đã dùng — chỉ hiện khi thật sự có bao cân bằng cân điện tử.
  String? _scaleDevice;

  final GlobalKey<ScaleBarState> _scaleBarKey = GlobalKey<ScaleBarState>();

  final PaddyVarietyApi _varietyApi = PaddyVarietyApi();
  late final Future<ThuMuaReceipt> _receiptFuture;
  late final Future<List<ProductVariantStock>> _productsFuture;
  late final Future<List<ThuMuaSupplier>> _suppliersFuture;
  late Future<List<ThuMuaWarehouse>> _warehousesFuture;
  late final Future<List<RiceVarietyOption>> _varietiesFuture;
  List<ProductVariantStock> _products = const [];
  List<ThuMuaWarehouse> _warehouses = const [];
  List<RiceVarietyOption> _varieties = const [];
  Map<int, PaddyVariantOption> _paddyVariantOptions = const {};
  // variantId -> riceVarietyId (để lọc sản phẩm theo giống đã chọn)
  Map<int, int?> _variantVarietyMap = const {};
  int? _riceVarietyId;

  /// Ngưỡng khối lượng trung bình tối đa cho mỗi bao lúa (kg). Vượt ngưỡng này
  /// coi là nhập sai (ví dụ nhầm tổng khối lượng với số bao).
  static const int _maxKgPerBag = 200;

  ThuMuaReceipt? _receipt;
  bool _quantityInitialized = false;
  bool _isSubmitting = false;
  bool _isChangingProduct = false;

  /// Tổng khối lượng = tổng các bao ĐÃ làm tròn lên 0,1 kg, để con số hiển thị
  /// khớp đúng con số sẽ ghi vào phiếu.
  double get _enteredWeight => _bagWeightControllers.fold<double>(
        0,
        (sum, controller) => sum + ceilKg(parseDecimal(controller.text) ?? 0),
      );

  bool get _anyBagFromScale => _bagFromScale.any((item) => item);

  /// Nhãn cho thanh cân: bao đang trống thì cân vào chính nó, không thì cân
  /// tiếp sẽ sinh bao mới.
  String get _scaleTargetLabel {
    final index = _bagTargetIndex;
    final isEmpty = index >= 0 &&
        index < _bagWeightControllers.length &&
        (parseDecimal(_bagWeightControllers[index].text) ?? 0) <= 0;
    return isEmpty
        ? 'bao ${index + 1}'
        : 'bao ${_bagWeightControllers.length + 1} (mới)';
  }

  double get _enteredUnitPrice =>
      double.tryParse(_unitCostController.text.trim()) ?? 0;

  double get _totalPurchaseAmount => _enteredWeight * _enteredUnitPrice;

  String get _submitLabel =>
      widget.draft != null ? 'Cập nhật phiếu mua' : 'Lưu phiếu mua';

  String get _headerTitle =>
      widget.draft != null ? 'Chỉnh sửa phiếu mua lúa' : 'Tạo phiếu mua lúa';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiThuMuaRepository();
    _receiptFuture = _loadReceipt();
    _productsFuture = _loadProducts();
    _suppliersFuture = _loadSuppliers();
    _warehousesFuture = _loadWarehouses();
    _varietiesFuture = _loadVarieties();
  }

  /// Tải danh sách giống lúa + bản đồ variant→giống (đồng bộ web: chọn giống
  /// trước, sau đó lọc sản phẩm theo giống).
  Future<List<RiceVarietyOption>> _loadVarieties() async {
    try {
      final varieties = await _varietyApi.getRiceVarieties();
      final variants = await _varietyApi.getProductVariants();
      _varieties = varieties;
      _paddyVariantOptions = {
        for (final variant in variants) variant.id: variant,
      };
      _variantVarietyMap = {
        for (final v in variants) v.id: v.riceVarietyId,
      };
      return varieties;
    } catch (_) {
      // Không chặn form nếu API giống lúa lỗi — vẫn cho chọn sản phẩm như cũ.
      _varieties = const [];
      _paddyVariantOptions = const {};
      _variantVarietyMap = const {};
      return const [];
    }
  }

  int? _varietyOf(int variantId) => _variantVarietyMap[variantId];

  /// Sản phẩm hiện chọn đã khớp giống đã chọn chưa (khi có dữ liệu giống).
  bool _productMatchesVariety(int productVariantId) {
    if (_riceVarietyId == null) return true;
    if (_variantVarietyMap.isEmpty) {
      return true; // không có dữ liệu → không chặn
    }
    return _varietyOf(productVariantId) == _riceVarietyId;
  }

  Future<ThuMuaReceipt> _loadReceipt() async {
    if (widget.draft != null) return widget.draft!;
    final schedule = widget.schedule;
    if (schedule != null) {
      // Chốt chặn cuối ở client: lịch đã hủy / đã nhập kho / đã đủ phiếu thì không mở form.
      if (!schedule.canCreateReceipt) {
        final reason = schedule.blockedReason.isEmpty
            ? 'Lịch này không còn lập được phiếu mua.'
            : '${schedule.blockedReason}. Không thể lập thêm phiếu mua cho lịch ${schedule.code}.';
        throw ApiException(message: reason);
      }
      return _receiptFromSchedule(schedule);
    }
    return _repository.getDraftReceipt();
  }

  ThuMuaReceipt _receiptFromSchedule(PurchaseSchedule schedule) {
    return ThuMuaReceipt(
      productVariantId: 0,
      warehouseId: schedule.warehouseId ?? 0,
      warehouseName: schedule.warehouseName ?? '',
      status: 'Phiếu nháp',
      productName: '',
      sku: '',
      currentStock: 0,
      receiptCode: 'Tự động sau khi lưu',
      weightKg: 0,
      quantity: 0,
      noteHint: 'Nhập ghi chú nếu có...',
      unitCostPrice: schedule.expectedPrice ?? 0,
      supplier: ThuMuaSupplier(
        id: schedule.farmerId,
        code: '',
        name: schedule.farmerName,
      ),
      expectedDate: schedule.scheduledAt,
      scheduleId: schedule.id,
      scheduleCode: schedule.code,
      riceVarietyId: schedule.riceVarietyId,
      riceVarietyName: schedule.riceVariety,
    );
  }

  Future<List<ThuMuaSupplier>> _loadSuppliers() async {
    return _repository.getSuppliers();
  }

  Future<List<ThuMuaWarehouse>> _loadWarehouses() async {
    final warehouses = await _repository.getWarehouses();
    _warehouses = warehouses;
    return warehouses;
  }

  Future<List<ProductVariantStock>> _loadProducts() async {
    final products = await _repository.getSelectableProducts();
    _products = products;
    return products;
  }

  ThuMuaReceipt _receiptForDisplay(ThuMuaReceipt receipt) {
    if (receipt.productVariantId <= 0) return receipt;
    final product = _products
        .where((item) => item.id == receipt.productVariantId)
        .firstOrNull;
    final paddyProduct = _paddyVariantOptions[receipt.productVariantId];
    if (product == null && paddyProduct == null) return receipt;

    final missingName = receipt.productName.trim().isEmpty ||
        receipt.productName.trim().toLowerCase() == 'lúa';
    final missingSku = receipt.sku.trim().isEmpty;
    if (!missingName && !missingSku) return receipt;

    return receipt.copyWith(
      productName: missingName
          ? paddyProduct?.name ?? product?.name ?? receipt.productName
          : receipt.productName,
      sku: missingSku
          ? paddyProduct?.sku ?? product?.sku ?? receipt.sku
          : receipt.sku,
      currentStock: product?.quantityOnHand ?? receipt.currentStock,
      weightKg: product?.weightKg ?? receipt.weightKg,
    );
  }

  List<ThuMuaWarehouse> _warehouseOptions(
    ThuMuaReceipt receipt,
    List<ThuMuaWarehouse>? loaded,
  ) {
    final rows = <ThuMuaWarehouse>[
      ...?loaded,
    ];
    if (receipt.warehouseId > 0 &&
        receipt.warehouseName.trim().isNotEmpty &&
        !rows.any((item) => item.id == receipt.warehouseId)) {
      rows.insert(
        0,
        ThuMuaWarehouse(
          id: receipt.warehouseId,
          name: receipt.warehouseName,
        ),
      );
    }
    return rows;
  }

  @override
  void dispose() {
    _noteController.dispose();
    _unitCostController.dispose();
    _moistureController.dispose();
    _paidAmountController.dispose();
    for (final controller in _bagWeightControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _setInitialQuantity(ThuMuaReceipt receipt) {
    if (_quantityInitialized) return;
    _receipt = receipt;
    _riceVarietyId ??= receipt.riceVarietyId;
    if (_unitCostController.text.isEmpty && receipt.unitCostPrice > 0) {
      _unitCostController.text = receipt.unitCostPrice.toStringAsFixed(0);
    }
    if (_noteController.text.isEmpty &&
        receipt.note?.trim().isNotEmpty == true) {
      _noteController.text = receipt.note!.trim();
    }
    _initializeBagControllers(receipt);
    if (_moistureController.text.isEmpty && receipt.moisturePercent != null) {
      _moistureController.text = receipt.moisturePercent!.toStringAsFixed(1);
    }
    _quantityInitialized = true;
  }

  void _initializeBagControllers(ThuMuaReceipt receipt) {
    if (_bagWeightControllers.isNotEmpty) return;
    final weights = receipt.bags.isNotEmpty
        ? receipt.bags.map((bag) => bag.weightKg).toList()
        : receipt.hasBagDetails && receipt.id != null && receipt.quantity > 0
            ? List<double>.filled(receipt.quantity, 0)
            : receipt.actualWeightKg > 0
                ? [receipt.actualWeightKg]
                : <double>[];
    for (final weight in weights) {
      _bagWeightControllers.add(
        TextEditingController(
          text:
              weight > 0 ? formatQuantityInput(ceilKg(weight), digits: 1) : '',
        ),
      );
    }
    if (_bagWeightControllers.isEmpty) {
      _bagWeightControllers.add(TextEditingController());
    }
    _syncBagMetadata();
    _bagTargetIndex = _firstEmptyBagIndex() ?? _bagWeightControllers.length - 1;
  }

  /// Giữ độ dài hai danh sách phụ (lỗi, nguồn số) khớp danh sách bao.
  void _syncBagMetadata() {
    final length = _bagWeightControllers.length;
    _bagWeightErrors = List<String?>.filled(length, null);
    while (_bagFromScale.length < length) {
      _bagFromScale.add(false);
    }
    while (_bagFromScale.length > length) {
      _bagFromScale.removeLast();
    }
    if (_bagTargetIndex >= length) _bagTargetIndex = length - 1;
    if (_bagTargetIndex < 0) _bagTargetIndex = 0;
    if (!_anyBagFromScale) _scaleDevice = null;
  }

  int? _firstEmptyBagIndex() {
    for (var i = 0; i < _bagWeightControllers.length; i++) {
      if ((parseDecimal(_bagWeightControllers[i].text) ?? 0) <= 0) return i;
    }
    return null;
  }

  void _addBag() {
    if (_isSubmitting) return;
    setState(() {
      _bagWeightControllers.add(TextEditingController());
      _syncBagMetadata();
      _bagTargetIndex = _bagWeightControllers.length - 1;
    });
  }

  void _removeBag(int index) {
    if (_isSubmitting || index < 0 || index >= _bagWeightControllers.length) {
      return;
    }
    setState(() {
      final controller = _bagWeightControllers.removeAt(index);
      controller.dispose();
      if (index < _bagFromScale.length) _bagFromScale.removeAt(index);
      if (_bagWeightControllers.isEmpty) {
        _bagWeightControllers.add(TextEditingController());
      }
      _syncBagMetadata();
    });
    // Bao vừa bỏ có thể vẫn đang nằm trên cân — đừng nhận lại nó ngay.
    _scaleBarKey.currentState?.suppressCurrentReading();
  }

  /// Người dùng gõ tay vào ô bao nào thì bao đó không còn là số từ cân nữa.
  void _onBagEdited(int index) {
    setState(() {
      if (index >= 0 && index < _bagFromScale.length) {
        _bagFromScale[index] = false;
      }
      if (!_anyBagFromScale) _scaleDevice = null;
    });
  }

  // ── Nhận số từ cân điện tử ─────────────────────────────────────────
  /// Mỗi lần cân đứng yên đủ lâu = MỘT BAO. Bao đích đang trống thì điền vào
  /// nó, đã có số thì sinh thêm bao mới — nhờ vậy cân liên tiếp nhiều bao chỉ
  /// việc đặt lên rồi nhấc ra, không phải chạm màn hình.
  void _onScaleCapture(WeightReading reading, bool automatic) {
    if (_isSubmitting) return;
    final weight = ceilKg(reading.weight);
    if (weight <= 0) return;

    var index = _bagTargetIndex;
    if (index < 0 || index >= _bagWeightControllers.length) {
      index = _bagWeightControllers.length - 1;
    }
    final appended = (parseDecimal(_bagWeightControllers[index].text) ?? 0) > 0;

    setState(() {
      if (appended) {
        _bagWeightControllers.add(TextEditingController());
        index = _bagWeightControllers.length - 1;
      }
      _bagWeightControllers[index].text =
          formatQuantityInput(weight, digits: 1);
      _syncBagMetadata();
      _bagFromScale[index] = true;
      _bagTargetIndex = index;
      _scaleDevice = reading.deviceName?.trim().isNotEmpty == true
          ? reading.deviceName!.trim()
          : 'Cân BLE StockLite';
    });

    if (!automatic) return;
    // Tự nhận thì phải có đường lùi: một chạm là bỏ bao vừa cân.
    final capturedIndex = index;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Text(
            'Đã nhận ${formatNumber(weight, digits: 1)} kg '
            '→ bao ${capturedIndex + 1}',
          ),
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () => _undoCapture(capturedIndex, appended),
          ),
        ),
      );
  }

  void _undoCapture(int index, bool appended) {
    if (index < 0 || index >= _bagWeightControllers.length) return;
    if (appended && _bagWeightControllers.length > 1) {
      _removeBag(index);
      return;
    }
    setState(() {
      _bagWeightControllers[index].text = '';
      if (index < _bagFromScale.length) _bagFromScale[index] = false;
      _syncBagMetadata();
      _bagTargetIndex = index;
    });
    _scaleBarKey.currentState?.suppressCurrentReading();
  }

  /// Kiểm tra danh sách bao và LÀM TRÒN LÊN 0,1 kg từng bao, kể cả bao gõ tay,
  /// rồi ghi ngược số đã tròn vào ô để người dùng thấy đúng con số sẽ lưu.
  List<ThuMuaBag>? _validatedBags() {
    final bags = <ThuMuaBag>[];
    final errors = List<String?>.filled(_bagWeightControllers.length, null);
    for (var i = 0; i < _bagWeightControllers.length; i++) {
      final raw = _bagWeightControllers[i].text.trim();
      final value = parseDecimal(raw);
      if (raw.isEmpty) {
        errors[i] = 'Khối lượng bao ${i + 1} là bắt buộc';
      } else if (value == null) {
        errors[i] = 'Khối lượng bao ${i + 1} không hợp lệ';
      } else if (value <= 0) {
        errors[i] = 'Khối lượng phải lớn hơn 0';
      } else {
        final rounded = ceilKg(value);
        _bagWeightControllers[i].text = formatQuantityInput(rounded, digits: 1);
        bags.add(ThuMuaBag(sequenceNumber: i + 1, weightKg: rounded));
      }
    }
    if (bags.isEmpty && errors.every((item) => item == null)) {
      errors[0] = 'Vui lòng thêm ít nhất một bao';
    }
    if (errors.any((item) => item != null)) {
      setState(() => _bagWeightErrors = errors);
      return null;
    }
    setState(() => _bagWeightErrors = errors);
    return bags;
  }

  void _retryWarehouses() {
    if (_isSubmitting) return;
    setState(() {
      _warehousesFuture = _loadWarehouses();
    });
  }

  void _changeWarehouse(int? warehouseId) {
    if (warehouseId == null || _isSubmitting) return;
    final warehouse =
        _warehouses.where((item) => item.id == warehouseId).firstOrNull;
    final receipt = _receipt;
    if (warehouse == null || receipt == null) return;
    setState(() {
      _receipt = receipt.copyWith(
        warehouseId: warehouse.id,
        warehouseName: warehouse.name,
      );
    });
  }

  void _changeRiceVariety(int? id) {
    if (_isSubmitting || _isChangingProduct) return;
    final receipt = _receipt;
    setState(() {
      _riceVarietyId = id;
      if (receipt != null &&
          receipt.productVariantId > 0 &&
          id != null &&
          _variantVarietyMap.isNotEmpty &&
          _varietyOf(receipt.productVariantId) != id) {
        _receipt = receipt.copyWith(
          productVariantId: 0,
          productName: '',
          sku: '',
          currentStock: 0,
          weightKg: 0,
          riceVarietyId: id,
        );
      } else if (receipt != null) {
        _receipt = receipt.copyWith(riceVarietyId: id);
      }
    });
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
      final current = _receipt;
      if (current == null) return;
      final varietyId =
          _varietyOf(product.id) ?? _riceVarietyId ?? current.riceVarietyId;
      setState(() {
        _riceVarietyId = varietyId;
        _receipt = current.copyWith(
          productVariantId: product.id,
          productName: product.name,
          sku: product.sku,
          currentStock: product.quantityOnHand,
          weightKg: product.weightKg,
          riceVarietyId: varietyId,
          unitCostPrice: _unitCostController.text.trim().isEmpty
              ? product.costPrice
              : current.unitCostPrice,
        );
        _quantityInitialized = true;
        if (_unitCostController.text.trim().isEmpty && product.costPrice > 0) {
          _unitCostController.text = product.costPrice.toStringAsFixed(0);
        }
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

    if (receipt.isConfirmed || (receipt.paddyLotId ?? 0) > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Phiếu đã chốt và đang chờ kiểm định; không chỉnh sửa từ màn Thu mua.',
          ),
        ),
      );
      return;
    }

    final bags = _validatedBags();
    if (bags == null) return;
    final bagCount = bags.length;
    // Cộng dồn số thực sinh đuôi lẻ (12,4 + 13,1 = 25,500000000000004) →
    // chuẩn hoá lại về bội của 0,1 trước khi tính tiền và gửi lên BE.
    final actualWeightKg =
        ceilKg(bags.fold<double>(0, (sum, bag) => sum + bag.weightKg));
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
    // Độ ẩm không nhập trên mobile ở luồng Thu mua; kiểm định sẽ xử lý sau.
    const double? moisturePercent = null;
    final paidAmount = double.tryParse(_paidAmountController.text.trim()) ?? 0;
    if (receipt.supplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn nông dân')),
      );
      return;
    }
    if (unitCostPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giá mua phải lớn hơn 0')),
      );
      return;
    }
    // Ràng buộc tỉ lệ khối lượng/số bao: chặn giá trị vô lý
    // (ví dụ 500000 kg cho 2 bao). Bao lúa thực tế hiếm khi vượt _maxKgPerBag.
    final avgKgPerBag = actualWeightKg / bagCount;
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
          bags: bags,
        ),
        quantity: bagCount,
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
        quantity: bagCount,
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
                : 'Không lưu được phiếu mua lúa: $error',
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
    final message = switch (error) {
      ProductVariantApiException e => e.message,
      // Lỗi nghiệp vụ (VD: lịch đã đủ phiếu) cần hiển thị nguyên văn cho người dùng.
      ApiException e => e.message,
      _ => 'Không tải được phiếu mua lúa',
    };

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
    final schedule = widget.schedule;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (schedule != null) ...[
            _PurchaseSourceCard(schedule: schedule),
            const SizedBox(height: 12),
          ],
          FutureBuilder<List<ThuMuaWarehouse>>(
            future: _warehousesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return _WarehouseErrorField(
                  error: snapshot.error,
                  onRetry: _retryWarehouses,
                );
              }
              final warehouses = _warehouseOptions(receipt, snapshot.data);
              if (warehouses.isEmpty) {
                return _WarehouseErrorField(
                  error: 'Không có kho nhập khả dụng.',
                  onRetry: _retryWarehouses,
                );
              }
              final selected =
                  warehouses.any((item) => item.id == receipt.warehouseId)
                      ? receipt.warehouseId
                      : null;
              return DropdownButtonFormField<int>(
                key: const ValueKey('thu_mua_warehouse'),
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Kho nhập *',
                  prefixIcon: Icon(Icons.warehouse_outlined),
                ),
                items: [
                  for (final warehouse in warehouses)
                    DropdownMenuItem(
                      value: warehouse.id,
                      child: Text(
                        warehouse.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _isSubmitting ? null : _changeWarehouse,
              );
            },
          ),
          const SizedBox(height: 12),
          // 1) Chọn GIỐNG LÚA trước (đồng bộ web).
          FutureBuilder<List<RiceVarietyOption>>(
            future: _varietiesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              final varieties = _varieties;
              if (varieties.isEmpty) {
                // Lookup giống lúa lỗi/rỗng: vẫn hiển thị giống đã lưu trên phiếu
                // thay vì giấu luôn thông tin.
                final saved = receipt.riceVarietyName?.trim();
                if (saved == null || saved.isEmpty)
                  return const SizedBox.shrink();
                return InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Giống lúa',
                    prefixIcon: Icon(Icons.grass_outlined),
                  ),
                  child: Text(
                    saved,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                );
              }
              final value = varieties.any((v) => v.id == _riceVarietyId)
                  ? _riceVarietyId
                  : null;
              return DropdownButtonFormField<int>(
                initialValue: value,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Giống lúa *',
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
                    : _changeRiceVariety,
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
              if (products.isEmpty && receipt.productVariantId <= 0) {
                return const _MissingProductField();
              }
              final hasVarietyData = _varieties.isNotEmpty;
              final varietyChosen = _riceVarietyId != null || !hasVarietyData;
              final matches = _productMatchesVariety(receipt.productVariantId);
              final selectedProduct = products
                  .where((item) => item.id == receipt.productVariantId)
                  .firstOrNull;
              final paddyProduct =
                  _paddyVariantOptions[receipt.productVariantId];
              final displayName = paddyProduct?.name ??
                  selectedProduct?.name ??
                  receipt.productName;
              final displaySku =
                  paddyProduct?.sku ?? selectedProduct?.sku ?? receipt.sku;
              // Khi mo lai draft, productVariantId/productName tu detail la
              // du lieu da luu. Lookup co the khong tra lai san pham da ngung
              // ban, nhung khong duoc lam mat san pham tren phieu.
              final showProduct = receipt.productVariantId > 0 &&
                  (matches || receipt.productName.trim().isNotEmpty);
              return InkWell(
                key: ValueKey('inbound_product_${receipt.productVariantId}'),
                borderRadius: BorderRadius.circular(12),
                onTap: varietyChosen ? () => _showProductPicker(receipt) : null,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Sản phẩm *',
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
                        ? '$displayName · $displaySku'
                        : 'Chưa xác định sản phẩm',
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
            key: const ValueKey('thu_mua_unit_price'),
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
          // Thanh cân dính ngay trên danh sách bao: cân là nguồn nhập chạy nền,
          // không phải một màn hình riêng. Nhập tay vẫn dùng được như cũ.
          ScaleBar(
            key: _scaleBarKey,
            enabled: !_isSubmitting,
            targetLabel: _scaleTargetLabel,
            onCapture: _onScaleCapture,
          ),
          const SizedBox(height: 12),
          _BagWeightsSection(
            controllers: _bagWeightControllers,
            errors: _bagWeightErrors,
            fromScale: _bagFromScale,
            targetIndex: _bagTargetIndex,
            totalWeightKg: _enteredWeight,
            scaleDevice: _anyBagFromScale ? _scaleDevice : null,
            onAdd: _addBag,
            onRemove: _removeBag,
            onSelect: (index) => setState(() => _bagTargetIndex = index),
            onChanged: _onBagEdited,
            isEnabled: !_isSubmitting,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('thu_mua_paid_amount'),
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
            title: const Text('Ngày mua thực tế'),
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
          if (receipt.productVariantId > 0) ...[
            ThuMuaProductCard(receipt: _receiptForDisplay(receipt)),
            const SizedBox(height: 12),
          ],
          ThuMuaReceiptFields(receipt: receipt),
          const SizedBox(height: 12),
          _QuantityWeightHint(
            quantity: _bagWeightControllers.length,
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
                : Text(_submitLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AuthSessionStore.current?.user.isWarehouseWorker == true) {
      return Scaffold(
        backgroundColor: AppColors.backgroundFor(context),
        appBar: AppBar(title: const Text('Lịch thu mua')),
        body: const Center(
          child: Text('Nhân viên kho chỉ được xem lịch thu mua.'),
        ),
      );
    }
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
                ThuMuaHeader(
                  title: _headerTitle,
                  status: receipt?.status ?? 'Phiếu nháp',
                  subtitle: widget.schedule == null
                      ? null
                      : 'Từ lịch ${widget.schedule!.code}',
                ),
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
    );
  }
}

class _WarehouseErrorField extends StatelessWidget {
  const _WarehouseErrorField({
    required this.error,
    required this.onRetry,
  });

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('thu_mua_warehouse_error'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warehouse_outlined, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Không tải được danh sách kho nhập: $error',
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}

class _MissingProductField extends StatelessWidget {
  const _MissingProductField();

  @override
  Widget build(BuildContext context) {
    return const InputDecorator(
      decoration: InputDecoration(
        labelText: 'Sản phẩm *',
        prefixIcon: Icon(Icons.inventory_2_outlined),
        helperText: 'Chưa có sản phẩm phù hợp từ dữ liệu hiện tại',
      ),
      child: Text(
        'Chưa xác định sản phẩm',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

class _PurchaseSourceCard extends StatelessWidget {
  const _PurchaseSourceCard({required this.schedule});

  final PurchaseSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final expectedWeight = schedule.estimatedWeightKg <= 0
        ? 'Chưa có'
        : '${schedule.estimatedWeightKg.toStringAsFixed(0)} kg';
    final expectedPrice = schedule.expectedPrice == null
        ? 'Chưa có'
        : '${schedule.expectedPrice!.toStringAsFixed(0)} đ/kg';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nguồn phiếu',
            style: TextStyle(
              color: AppColors.textSecondaryFor(context),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            schedule.code,
            style: TextStyle(
              color: AppColors.textPrimaryFor(context),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            schedule.farmerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondaryFor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _SourcePill(label: 'Dự kiến theo lịch', value: expectedWeight),
              _SourcePill(
                  label: 'Ngày hẹn', value: _formatDate(schedule.scheduledAt)),
              _SourcePill(label: 'Giá dự kiến', value: expectedPrice),
              _SourcePill(label: 'Giống', value: schedule.riceVariety),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourcePill extends StatelessWidget {
  const _SourcePill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
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

class _BagWeightsSection extends StatelessWidget {
  const _BagWeightsSection({
    required this.controllers,
    required this.errors,
    required this.fromScale,
    required this.targetIndex,
    required this.totalWeightKg,
    required this.scaleDevice,
    required this.onAdd,
    required this.onRemove,
    required this.onSelect,
    required this.onChanged,
    required this.isEnabled,
  });

  final List<TextEditingController> controllers;
  final List<String?> errors;
  final List<bool> fromScale;
  final int targetIndex;
  final double totalWeightKg;
  final String? scaleDevice;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onChanged;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondaryFor(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Danh sách bao *',
                  style: TextStyle(
                    color: AppColors.textPrimaryFor(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${controllers.length} bao · ${formatNumber(totalWeightKg, digits: 1)} kg',
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            scaleDevice == null
                ? 'Đặt từng bao lên cân — mỗi lần cân đứng yên là một bao. Khối lượng làm tròn lên 0,1 kg.'
                : 'Đang lấy số từ $scaleDevice. Khối lượng làm tròn lên 0,1 kg.',
            style: TextStyle(fontSize: 11.5, color: secondary),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < controllers.length; index++) ...[
            _BagRow(
              index: index,
              controller: controllers[index],
              errorText: index < errors.length ? errors[index] : null,
              fromScale: index < fromScale.length && fromScale[index],
              isTarget: index == targetIndex,
              canRemove: isEnabled && controllers.length > 1,
              isEnabled: isEnabled,
              onRemove: () => onRemove(index),
              onSelect: () => onSelect(index),
              onChanged: () => onChanged(index),
            ),
          ],
          OutlinedButton.icon(
            onPressed: isEnabled ? onAdd : null,
            icon: const Icon(Icons.add),
            label: const Text('Thêm bao'),
          ),
        ],
      ),
    );
  }
}

/// Một bao lúa: ô kg + cờ chọn làm bao đích của cân + nhãn nguồn số.
class _BagRow extends StatelessWidget {
  const _BagRow({
    required this.index,
    required this.controller,
    required this.errorText,
    required this.fromScale,
    required this.isTarget,
    required this.canRemove,
    required this.isEnabled,
    required this.onRemove,
    required this.onSelect,
    required this.onChanged,
  });

  final int index;
  final TextEditingController controller;
  final String? errorText;
  final bool fromScale;
  final bool isTarget;
  final bool canRemove;
  final bool isEnabled;
  final VoidCallback onRemove;
  final VoidCallback onSelect;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondaryFor(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTarget
            ? AppColors.brandTintFor(context)
            : AppColors.backgroundFor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTarget ? AppColors.primary : AppColors.borderFor(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InkWell(
                onTap: isEnabled && !isTarget ? onSelect : null,
                borderRadius: BorderRadius.circular(99),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    isTarget
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: isTarget ? AppColors.primary : secondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bao ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: fromScale
                      ? AppColors.primary.withValues(alpha: 0.14)
                      : AppColors.borderFor(context).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      fromScale
                          ? Icons.scale_rounded
                          : Icons.keyboard_alt_outlined,
                      size: 12,
                      color: fromScale ? AppColors.primary : secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      fromScale ? 'Từ cân' : 'Nhập tay',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: fromScale ? AppColors.primary : secondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Xóa bao',
                onPressed: canRemove ? onRemove : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          TextFormField(
            key: ValueKey('thu_mua_bag_weight_$index'),
            controller: controller,
            enabled: isEnabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Khối lượng (kg) *',
              suffixText: 'kg',
              prefixIcon: const Icon(Icons.scale_outlined),
              errorText: errorText,
            ),
            onTap: isEnabled && !isTarget ? onSelect : null,
            onChanged: (_) => onChanged(),
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

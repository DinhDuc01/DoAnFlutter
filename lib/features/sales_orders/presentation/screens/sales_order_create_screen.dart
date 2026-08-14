import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/sales_order_repository.dart';

/// Màn tạo đơn bán trên mobile — đủ trường như web.
///
/// Đơn tạo ra ở trạng thái "Mới tạo". Bước XÁC NHẬN đơn chỉ thực hiện trên web;
/// mobile chỉ tạo đơn rồi sau đó "Kiểm tra & giữ hàng" ở màn chi tiết.
class SalesOrderCreateScreen extends StatefulWidget {
  const SalesOrderCreateScreen({this.repository, super.key});

  final SalesOrderRepository? repository;

  @override
  State<SalesOrderCreateScreen> createState() => _SalesOrderCreateScreenState();
}

/// Một dòng hàng đang soạn trên form (giữ controller để nhập liệu).
class _LineDraft {
  _LineDraft({
    required this.product,
    required this.quantity,
    required this.price,
    required this.discount,
    required this.note,
  });

  final SalesProductOption product;
  final TextEditingController quantity;
  final TextEditingController price;
  final TextEditingController discount;
  final TextEditingController note;

  void dispose() {
    quantity.dispose();
    price.dispose();
    discount.dispose();
    note.dispose();
  }

  double get lineAmount {
    final qty = parseDecimal(quantity.text) ?? 0;
    final unit = parseDecimal(price.text) ?? 0;
    final disc = parseDecimal(discount.text) ?? 0;
    final amount = qty * unit - disc;
    return amount < 0 ? 0 : amount;
  }
}

class _SalesOrderCreateScreenState extends State<SalesOrderCreateScreen> {
  late final SalesOrderRepository _repository;

  final _shippingAddressController = TextEditingController();
  final _noteController = TextEditingController();
  final _depositController = TextEditingController();

  List<SalesCustomerOption> _customers = const [];
  List<SalesWarehouseOption> _warehouses = const [];
  List<SalesProductOption> _products = const [];
  final List<_LineDraft> _lines = [];

  int? _customerId;
  int? _warehouseId;
  String _channel = 'DIRECT';
  DateTime? _expectedDeliveryDate;
  bool _requiresMilling = false;

  bool _loading = true;
  bool _submitting = false;
  Object? _loadError;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiSalesOrderRepository();
    _loadLookups();
  }

  @override
  void dispose() {
    _shippingAddressController.dispose();
    _noteController.dispose();
    _depositController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLookups() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final customers = await _repository.getCustomers();
      final warehouses = await _repository.getWarehouses();
      final products = await _repository.getProductVariants();
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _warehouses = warehouses;
        _products = products;
        // Chỉ có 1 kho thì chọn sẵn để bớt một thao tác ngoài hiện trường.
        _warehouseId = warehouses.length == 1 ? warehouses.first.id : null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  double get _itemsTotal =>
      _lines.fold<double>(0, (sum, line) => sum + line.lineAmount);

  /// Địa chỉ của khách đã chọn (null khi khách không có địa chỉ).
  String? _customerAddress(int? customerId) {
    if (customerId == null) return null;
    for (final customer in _customers) {
      if (customer.id != customerId) continue;
      final address = customer.address?.trim();
      return address == null || address.isEmpty ? null : address;
    }
    return null;
  }

  Future<void> _pickProduct() async {
    final chosenIds = _lines.map((line) => line.product.id).toSet();
    final available =
        _products.where((item) => !chosenIds.contains(item.id)).toList();

    if (available.isEmpty) {
      _showMessage('Đã thêm hết sản phẩm khả dụng vào đơn.');
      return;
    }

    final picked = await showModalBottomSheet<SalesProductOption>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ProductPickerSheet(products: available),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _lines.add(
        _LineDraft(
          product: picked,
          quantity: TextEditingController(),
          // Giá bán của sản phẩm là gợi ý, người bán vẫn sửa được.
          price: TextEditingController(
            text: picked.salePrice > 0
                ? formatQuantityInput(picked.salePrice, digits: 0)
                : '',
          ),
          discount: TextEditingController(),
          note: TextEditingController(),
        ),
      );
      _formError = null;
    });
  }

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index).dispose();
      _formError = null;
    });
  }

  Future<void> _pickDeliveryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedDeliveryDate ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      helpText: 'Ngày giao dự kiến',
    );
    if (picked == null || !mounted) return;
    setState(() => _expectedDeliveryDate = picked);
  }

  /// Dựng payload từ form; trả null và set [_formError] khi dữ liệu chưa hợp lệ.
  CreateSalesOrderInput? _buildInput() {
    if (_customerId == null) {
      setState(() => _formError = 'Vui lòng chọn khách hàng.');
      return null;
    }
    if (_warehouseId == null) {
      setState(() => _formError = 'Vui lòng chọn kho xuất hàng.');
      return null;
    }
    if (_lines.isEmpty) {
      setState(() => _formError = 'Đơn bán phải có ít nhất 1 dòng sản phẩm.');
      return null;
    }

    final items = <CreateSalesOrderLine>[];
    for (final line in _lines) {
      final quantity = parseDecimal(line.quantity.text);
      if (quantity == null || quantity <= 0) {
        setState(() => _formError =
            'Số lượng của "${line.product.name}" phải lớn hơn 0.');
        return null;
      }
      final price = parseDecimal(line.price.text);
      if (price == null || price < 0) {
        setState(() =>
            _formError = 'Đơn giá của "${line.product.name}" không hợp lệ.');
        return null;
      }
      final discount = parseDecimal(line.discount.text) ?? 0;
      if (discount < 0) {
        setState(() =>
            _formError = 'Giảm giá của "${line.product.name}" không được âm.');
        return null;
      }
      if (discount > quantity * price) {
        setState(() => _formError =
            'Giảm giá của "${line.product.name}" vượt quá thành tiền của dòng.');
        return null;
      }
      items.add(
        CreateSalesOrderLine(
          productVariantId: line.product.id,
          quantityOrdered: quantity,
          unitSalePrice: price,
          discountAmount: discount,
          note: line.note.text,
        ),
      );
    }

    final deposit = parseDecimal(_depositController.text);
    if (_depositController.text.trim().isNotEmpty &&
        (deposit == null || deposit < 0)) {
      setState(() => _formError = 'Tiền cọc không hợp lệ.');
      return null;
    }
    final total = items.fold<double>(0, (sum, item) => sum + item.lineAmount);
    if (deposit != null && deposit > total) {
      setState(() => _formError = 'Tiền cọc không được lớn hơn tổng tiền đơn.');
      return null;
    }

    return CreateSalesOrderInput(
      customerId: _customerId!,
      warehouseId: _warehouseId!,
      channel: _channel,
      expectedDeliveryDate: _expectedDeliveryDate,
      requiresMilling: _requiresMilling,
      depositAmount: deposit,
      shippingAddress: _shippingAddressController.text,
      note: _noteController.text,
      items: items,
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _formError = null);

    final input = _buildInput();
    if (input == null) return;

    setState(() => _submitting = true);
    try {
      final created = await _repository.create(input);
      if (!mounted) return;
      _showMessage('Đã tạo đơn bán ${created.soCode}.');
      // Trả kết quả cho màn danh sách để mở thẳng chi tiết đơn vừa tạo.
      Navigator.of(context).pop(created);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _formError = error is SalesOrderException
            ? error.message
            : 'Không tạo được đơn bán: $error';
        _submitting = false;
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      appBar: AppBar(
        title: const Text('Tạo đơn bán'),
        actions: [
          IconButton(
            tooltip: 'Tải lại danh mục',
            onPressed: _loading || _submitting ? null : _loadLookups,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _loading || _loadError != null ? null : _bottomBar(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return HErrorState(
        message: 'Không tải được danh mục khách hàng/sản phẩm: $_loadError',
        onRetry: _loadLookups,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        const AppInfoBanner(
          tone: AppTone.info,
          icon: Icons.desktop_windows_outlined,
          message: 'Đơn tạo trên điện thoại ở trạng thái "Mới tạo". '
              'Việc xác nhận đơn thực hiện trên web, sau đó quay lại đây để '
              'kiểm tra & giữ hàng.',
        ),
        const SizedBox(height: 12),
        _infoCard(),
        const SizedBox(height: 12),
        _itemsCard(),
        const SizedBox(height: 12),
        _extraCard(),
        if (_formError != null) ...[
          const SizedBox(height: 12),
          Text(
            _formError!,
            style: const TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _infoCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'Thông tin đơn',
            icon: Icons.receipt_long_outlined,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _customerId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Khách hàng *',
              prefixIcon: Icon(Icons.person_outline),
            ),
            items: [
              for (final customer in _customers)
                DropdownMenuItem(
                  value: customer.id,
                  child: Text(
                    customer.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _submitting
                ? null
                : (value) => setState(() {
                      _customerId = value;
                      // Gợi ý địa chỉ giao theo địa chỉ khách khi còn để trống.
                      final address = _customerAddress(value);
                      if (address != null &&
                          _shippingAddressController.text.trim().isEmpty) {
                        _shippingAddressController.text = address;
                      }
                    }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _warehouseId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Kho xuất hàng *',
              prefixIcon: Icon(Icons.warehouse_outlined),
            ),
            items: [
              for (final warehouse in _warehouses)
                DropdownMenuItem(
                  value: warehouse.id,
                  child: Text(
                    warehouse.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged:
                _submitting ? null : (value) => setState(() => _warehouseId = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _channel,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Kênh bán *',
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'DIRECT', child: Text('Bán trực tiếp')),
              DropdownMenuItem(value: 'WHOLESALE', child: Text('Bán sỉ')),
            ],
            onChanged: _submitting
                ? null
                : (value) => setState(() => _channel = value ?? 'DIRECT'),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _submitting ? null : _pickDeliveryDate,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Ngày giao dự kiến',
                prefixIcon: const Icon(Icons.event_outlined),
                suffixIcon: _expectedDeliveryDate == null
                    ? const Icon(Icons.expand_more)
                    : IconButton(
                        tooltip: 'Xóa ngày',
                        icon: const Icon(Icons.close),
                        onPressed: _submitting
                            ? null
                            : () =>
                                setState(() => _expectedDeliveryDate = null),
                      ),
              ),
              child: Text(
                _expectedDeliveryDate == null
                    ? 'Chưa chọn'
                    : formatDate(_expectedDeliveryDate),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _expectedDeliveryDate == null
                      ? AppColors.textTertiary
                      : AppColors.textPrimaryFor(context),
                ),
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _requiresMilling,
            onChanged: _submitting
                ? null
                : (value) => setState(() => _requiresMilling = value),
            title: const Text(
              'Cần xay xát',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Đơn phải hoàn thành lệnh xay trước khi giữ hàng.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemsCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'Dòng hàng (${_lines.length})',
            icon: Icons.inventory_2_outlined,
          ),
          if (_lines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Chưa có dòng hàng nào. Bấm "Thêm sản phẩm" để bắt đầu.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            for (var index = 0; index < _lines.length; index++)
              _lineEditor(index, _lines[index]),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _submitting ? null : _pickProduct,
              icon: const Icon(Icons.add),
              label: const Text('Thêm sản phẩm'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineEditor(int index, _LineDraft line) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.product.label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Xóa dòng',
                onPressed: _submitting ? null : () => _removeLine(index),
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: line.quantity,
                  enabled: !_submitting,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Số lượng *',
                    suffixText: line.product.unitName,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: line.price,
                  enabled: !_submitting,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Đơn giá *',
                    suffixText: 'đ',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: line.discount,
            enabled: !_submitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Giảm giá',
              suffixText: 'đ',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: line.note,
            enabled: !_submitting,
            decoration: const InputDecoration(labelText: 'Ghi chú dòng'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Thành tiền: ${formatMoney(line.lineAmount)}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _extraCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'Thanh toán & giao hàng',
            icon: Icons.local_shipping_outlined,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _depositController,
            enabled: !_submitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Tiền cọc',
              prefixIcon: Icon(Icons.savings_outlined),
              suffixText: 'đ',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _shippingAddressController,
            enabled: !_submitting,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Địa chỉ giao hàng',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            enabled: !_submitting,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Ghi chú đơn',
              prefixIcon: Icon(Icons.sticky_note_2_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    final deposit = parseDecimal(_depositController.text) ?? 0;
    final remaining = _itemsTotal - deposit;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng tiền: ${formatMoney(_itemsTotal)}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    if (deposit > 0)
                      Text(
                        'Còn lại sau cọc: ${formatMoney(remaining < 0 ? 0 : remaining)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              FilledButton.icon(
                // Theme đặt minimumSize = Size.fromHeight(50) (rộng vô hạn) để
                // nút chiếm trọn chiều ngang; trong Row thì chiều ngang không
                // bị chặn nên ràng buộc vô hạn làm vỡ layout. Nút ở thanh dưới
                // này nằm cạnh phần tổng tiền nên chỉ cần vừa nội dung.
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_submitting ? 'Đang lưu...' : 'Lưu đơn bán'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Danh sách sản phẩm để chọn dòng hàng, có ô tìm kiếm theo tên/SKU.
class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet({required this.products});

  final List<SalesProductOption> products;

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _controller = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _keyword.trim().toLowerCase();
    final rows = keyword.isEmpty
        ? widget.products
        : widget.products
            .where((item) =>
                item.name.toLowerCase().contains(keyword) ||
                (item.sku ?? '').toLowerCase().contains(keyword))
            .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: false,
            decoration: const InputDecoration(
              hintText: 'Tìm theo tên hoặc SKU...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _keyword = value),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: rows.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('Không tìm thấy sản phẩm phù hợp.'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final item = rows[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          [
                            if ((item.sku ?? '').trim().isNotEmpty) item.sku!,
                            if (item.salePrice > 0)
                              'Giá bán ${formatMoney(item.salePrice)}',
                          ].join(' · '),
                        ),
                        onTap: () => Navigator.of(context).pop(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../products/data/product_variant_api.dart';
import '../../data/inventory_weighing_repository.dart';
import '../../models/inventory_weighing_result.dart';
import '../../models/weight_reading.dart';
import 'scale_screen.dart';

typedef IotReadingPicker = Future<WeightReading?> Function(
    BuildContext context);

class InventoryWeighingScreen extends StatefulWidget {
  const InventoryWeighingScreen({
    this.repository,
    this.iotReadingPicker,
    super.key,
  });

  final InventoryWeighingRepository? repository;
  final IotReadingPicker? iotReadingPicker;

  @override
  State<InventoryWeighingScreen> createState() =>
      _InventoryWeighingScreenState();
}

class _InventoryWeighingScreenState extends State<InventoryWeighingScreen> {
  late final InventoryWeighingRepository _repository;
  late Future<List<ProductVariantStock>> _productsFuture;
  final TextEditingController _manualWeightController = TextEditingController();

  ProductVariantStock? _selectedProduct;
  WeighingMethod _method = WeighingMethod.manual;
  WeightReading? _iotReading;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiInventoryWeighingRepository();
    _productsFuture = _repository.loadProductsInStock();
  }

  @override
  void dispose() {
    _manualWeightController.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _selectedProduct = null;
      _productsFuture = _repository.loadProductsInStock();
    });
  }

  void _selectProduct(ProductVariantStock? product) {
    if (product == null) return;
    setState(() {
      _selectedProduct = product;
      _quantity = 1;
      _iotReading = null;
      _manualWeightController.clear();
    });
  }

  Future<void> _readIotScale() async {
    final picker = widget.iotReadingPicker ??
        (context) => Navigator.of(context).push<WeightReading>(
              MaterialPageRoute(builder: (_) => const ScaleScreen()),
            );
    final reading = await picker(context);
    if (mounted && reading != null) {
      setState(() => _iotReading = reading);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _confirm() async {
    final product = _selectedProduct;
    if (product == null) {
      _showMessage('Vui lòng chọn sản phẩm cần cân.');
      return;
    }
    if (_quantity < 1 || _quantity > product.quantityAvailable) {
      _showMessage(
        'Số lượng phải từ 1 đến ${product.quantityAvailable} sản phẩm.',
      );
      return;
    }

    final weight = switch (_method) {
      WeighingMethod.manual => double.tryParse(
          _manualWeightController.text.trim().replaceAll(',', '.'),
        ),
      WeighingMethod.iot => _iotReading?.weight,
    };
    if (weight == null || weight <= 0) {
      _showMessage(
        _method == WeighingMethod.manual
            ? 'Vui lòng nhập tổng khối lượng lớn hơn 0.'
            : 'Vui lòng lấy số cân ổn định từ cân IoT.',
      );
      return;
    }

    final result = InventoryWeighingResult(
      product: product,
      quantity: _quantity,
      totalWeightKg: weight,
      method: _method,
      weighedAt: DateTime.now(),
    );
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: AppColors.primary),
        title: const Text('Đã ghi nhận kết quả cân'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResultLine(label: 'Sản phẩm', value: product.name),
            _ResultLine(label: 'Số lượng', value: '$_quantity'),
            _ResultLine(
              label: 'Tổng khối lượng',
              value: '${weight.toStringAsFixed(3)} kg',
            ),
            _ResultLine(
              label: 'Trung bình',
              value: '${result.averageWeightKg.toStringAsFixed(3)} kg/sp',
            ),
            _ResultLine(label: 'Phương thức', value: _method.label),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hoàn tất'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cân sản phẩm'),
            Text(
              'Chọn hàng trong kho và phương thức cân',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<ProductVariantStock>>(
          future: _productsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _LoadError(error: snapshot.error, onRetry: _retry);
            }
            final products = snapshot.data ?? const [];
            if (products.isEmpty) {
              return const _EmptyStock();
            }
            _selectedProduct ??= products.first;
            return _buildForm(products);
          },
        ),
      ),
    );
  }

  Widget _buildForm(List<ProductVariantStock> products) {
    final product = _selectedProduct!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        const _SectionTitle('1. Chọn sản phẩm trong kho'),
        const SizedBox(height: 8),
        DropdownButtonFormField<ProductVariantStock>(
          key: const ValueKey('weighing_product'),
          initialValue: product,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Sản phẩm',
            prefixIcon: Icon(Icons.inventory_2_outlined),
          ),
          items: [
            for (final item in products)
              DropdownMenuItem(
                value: item,
                child: Text(
                  '${item.name} · Còn ${item.quantityAvailable}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _selectProduct,
        ),
        const SizedBox(height: 10),
        _StockCard(product: product),
        const SizedBox(height: 22),
        const _SectionTitle('2. Chọn số lượng'),
        const SizedBox(height: 8),
        _QuantitySelector(
          quantity: _quantity,
          maximum: product.quantityAvailable,
          onChanged: (quantity) => setState(() => _quantity = quantity),
        ),
        const SizedBox(height: 22),
        const _SectionTitle('3. Chọn phương thức cân'),
        const SizedBox(height: 8),
        SegmentedButton<WeighingMethod>(
          key: const ValueKey('weighing_method'),
          segments: const [
            ButtonSegment(
              value: WeighingMethod.manual,
              icon: Icon(Icons.edit_outlined),
              label: Text('Nhập tay'),
            ),
            ButtonSegment(
              value: WeighingMethod.iot,
              icon: Icon(Icons.bluetooth_connected),
              label: Text('Cân IoT'),
            ),
          ],
          selected: {_method},
          onSelectionChanged: (selection) {
            setState(() => _method = selection.first);
          },
        ),
        const SizedBox(height: 14),
        if (_method == WeighingMethod.manual)
          TextField(
            key: const ValueKey('manual_weight'),
            controller: _manualWeightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Tổng khối lượng thực tế (kg)',
              prefixIcon: Icon(Icons.scale_outlined),
              suffixText: 'kg',
            ),
          )
        else
          _IotScaleCard(
            reading: _iotReading,
            onRead: _readIotScale,
          ),
        const SizedBox(height: 22),
        FilledButton.icon(
          key: const ValueKey('confirm_weighing'),
          onPressed: _confirm,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Xác nhận kết quả cân'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
      );
}

class _StockCard extends StatelessWidget {
  const _StockCard({required this.product});
  final ProductVariantStock product;

  @override
  Widget build(BuildContext context) {
    final warehouses = product.warehouses
        .where((warehouse) => warehouse.quantityAvailable > 0)
        .map((warehouse) => warehouse.warehouseName)
        .toSet()
        .join(', ');
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.warehouse_outlined)),
        title: Text(product.sku),
        subtitle: Text(
          warehouses.isEmpty ? 'Kho chưa xác định' : warehouses,
        ),
        trailing: Text(
          '${product.quantityAvailable} ${product.unitName ?? 'sp'}',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({
    required this.quantity,
    required this.maximum,
    required this.onChanged,
  });

  final int quantity;
  final int maximum;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconButton.filledTonal(
              key: const ValueKey('decrease_weighing_quantity'),
              onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '$quantity',
                    key: const ValueKey('weighing_quantity'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text('Tối đa $maximum sản phẩm'),
                ],
              ),
            ),
            IconButton.filled(
              key: const ValueKey('increase_weighing_quantity'),
              onPressed:
                  quantity < maximum ? () => onChanged(quantity + 1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}

class _IotScaleCard extends StatelessWidget {
  const _IotScaleCard({required this.reading, required this.onRead});
  final WeightReading? reading;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFE9F8EF),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.scale_rounded, size: 36, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              reading == null
                  ? 'Chưa có số cân IoT'
                  : '${reading!.weight.toStringAsFixed(3)} ${reading!.unit}',
              key: const ValueKey('iot_weight'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const ValueKey('read_iot_scale'),
              onPressed: onRead,
              icon: const Icon(Icons.bluetooth_searching),
              label: Text(
                reading == null ? 'Kết nối và lấy số cân' : 'Cân lại',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 112, child: Text(label)),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Không tải được sản phẩm trong kho: ${error ?? ''}'),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
}

class _EmptyStock extends StatelessWidget {
  const _EmptyStock();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Kho chưa có sản phẩm khả dụng để cân.',
            textAlign: TextAlign.center,
          ),
        ),
      );
}

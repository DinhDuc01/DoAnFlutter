import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_data_view.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/api_milling_repository.dart';
import '../../data/milling_repository.dart';
import '../../models/milling_order.dart';
import '../widgets/milling_widgets.dart';
import 'rice_weighing_screen.dart';

/// Loads the active milling order and validates that weighing can start.
class MillingPreparationScreen extends StatefulWidget {
  const MillingPreparationScreen({this.repository, super.key});

  final MillingRepository? repository;

  @override
  State<MillingPreparationScreen> createState() =>
      _MillingPreparationScreenState();
}

class _MillingPreparationScreenState extends State<MillingPreparationScreen> {
  late final MillingRepository _repository;
  late final Future<List<MillingProductOption>> _productsFuture;
  final RealtimeDataController _controller = RealtimeDataController();
  MillingScaleMode _scaleMode = MillingScaleMode.iot;
  bool _includeBroken = false;
  int? _riceProductId;
  int? _branProductId;
  int? _brokenProductId;

  static const Set<String> _entities = {
    'MillingOrder',
    'Inventory',
    'InventoryTransaction',
  };

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiMillingRepository();
    _productsFuture = _repository.getOutputProducts();
  }

  Future<void> _createMillingOrder() async {
    final repository = _repository;
    if (repository is! ApiMillingRepository) return;
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateMillingOrderDialog(repository: repository),
    );
    if (!mounted || created != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã tạo và bắt đầu lệnh xay.')),
    );
    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: millingBackground,
      appBar: MillingAppBar(
        title: 'Hoàn tất xay & đóng bao',
        actions: _repository is ApiMillingRepository
            ? [
                IconButton(
                  tooltip: 'Tạo lệnh xay',
                  onPressed: _createMillingOrder,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ]
            : null,
      ),
      body: RealtimeDataView<MillingOrder>(
        loader: _repository.getActiveOrder,
        controller: _controller,
        entities: _entities,
        enablePullToRefresh: false,
        loadingBuilder: (_) => const FormSkeleton(),
        errorBuilder: (context, error, retry) => HErrorState(
          message: 'Không thể tải lệnh xay: $error',
          onRetry: retry,
        ),
        builder: (context, order) {
          return FutureBuilder<List<MillingProductOption>>(
            future: _productsFuture,
            builder: (context, productSnapshot) {
              final products = productSnapshot.data ?? const [];
              final riceProducts =
                  products.where((item) => item.outputType == 'RICE').toList();
              final branProducts =
                  products.where((item) => item.outputType == 'BRAN').toList();
              final brokenProducts = products
                  .where((item) => item.outputType == 'BROKEN')
                  .toList();
              _riceProductId ??= order.riceProductVariantId > 0
                  ? order.riceProductVariantId
                  : riceProducts.firstOrNull?.id;
              _branProductId ??= order.branProductVariantId > 0
                  ? order.branProductVariantId
                  : branProducts.firstOrNull?.id;
              _brokenProductId ??= order.brokenProductVariantId > 0
                  ? order.brokenProductVariantId
                  : brokenProducts.firstOrNull?.id;
              final configured = order.copyWith(
                scaleMode: _scaleMode,
                riceProductVariantId: _riceProductId,
                branProductVariantId: _branProductId,
                brokenProductVariantId: _brokenProductId,
              );
              final canStart = configured.riceProductVariantId > 0 &&
                  configured.branProductVariantId > 0;
              return Column(
                children: [
                  Expanded(
                    child: _buildBody(
                      configured,
                      riceProducts,
                      branProducts,
                      brokenProducts,
                    ),
                  ),
                  MillingPrimaryButton(
                    label: 'Bắt đầu cân gạo',
                    onPressed: canStart
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => RiceWeighingScreen(
                                  order: configured,
                                  repository: _repository,
                                  includeBroken: _includeBroken,
                                ),
                              ),
                            );
                          }
                        : null,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBody(
    MillingOrder order,
    List<MillingProductOption> riceProducts,
    List<MillingProductOption> branProducts,
    List<MillingProductOption> brokenProducts,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Sau khi xay xong, cân từng bao gạo trước; sau đó cân cám để chốt kết quả mẻ xay.',
            style: TextStyle(
              color: Color(0xFF166534),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<MillingScaleMode>(
          segments: const [
            ButtonSegment(
              value: MillingScaleMode.iot,
              icon: Icon(Icons.bluetooth),
              label: Text('Cân IoT'),
            ),
            ButtonSegment(
              value: MillingScaleMode.manual,
              icon: Icon(Icons.edit_outlined),
              label: Text('Cân thường'),
            ),
          ],
          selected: {_scaleMode},
          onSelectionChanged: (value) {
            setState(() => _scaleMode = value.first);
          },
        ),
        const SizedBox(height: 10),
        _ProductDropdown(
          label: 'Sản phẩm gạo',
          value: _riceProductId,
          products: riceProducts,
          onChanged: (value) => setState(() => _riceProductId = value),
        ),
        const SizedBox(height: 8),
        _ProductDropdown(
          label: 'Sản phẩm cám',
          value: _branProductId,
          products: branProducts,
          onChanged: (value) => setState(() => _branProductId = value),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          value: _includeBroken,
          title: const Text('Cân tấm'),
          subtitle: const Text('Tùy chọn nếu mẻ xay có tấm'),
          onChanged: brokenProducts.isEmpty
              ? null
              : (value) => setState(() => _includeBroken = value),
        ),
        if (_includeBroken)
          _ProductDropdown(
            label: 'Sản phẩm tấm',
            value: _brokenProductId,
            products: brokenProducts,
            onChanged: (value) => setState(() => _brokenProductId = value),
          ),
        const SizedBox(height: 10),
        _InfoRow(text: 'Lệnh: ${order.millingCode} · ${order.inputLotCode}'),
        const SizedBox(height: 8),
        _InfoRow(
          text:
              'Lúa đầu vào: ${order.inputWeightKg.toStringAsFixed(0)}kg · ${order.warehouseZone} / ${order.locationCode}',
        ),
        const SizedBox(height: 8),
        _InfoRow(
          text: _includeBroken
              ? 'Cần cân riêng: gạo, cám và tấm'
              : 'Cần cân riêng: gạo và cám',
        ),
        const SizedBox(height: 8),
        _InfoRow(
          text: order.scaleMode == MillingScaleMode.iot
              ? 'Thiết bị cân: ${order.scaleCode} · cân IoT'
              : 'Thiết bị cân: cân thường · nhập số thủ công',
        ),
      ],
    );
  }
}

class _CreateMillingOrderDialog extends StatefulWidget {
  const _CreateMillingOrderDialog({required this.repository});

  final ApiMillingRepository repository;

  @override
  State<_CreateMillingOrderDialog> createState() =>
      _CreateMillingOrderDialogState();
}

class _CreateMillingOrderDialogState extends State<_CreateMillingOrderDialog> {
  late final Future<List<MillingPaddyLotOption>> _lotsFuture;
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _yieldController =
      TextEditingController(text: '65');
  int? _lotId;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lotsFuture = widget.repository.getPaddyLots();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _yieldController.dispose();
    super.dispose();
  }

  Future<void> _submit(List<MillingPaddyLotOption> lots) async {
    final lot = lots.where((item) => item.id == _lotId).firstOrNull;
    final weight = double.tryParse(_weightController.text.trim());
    final yieldPercent = double.tryParse(_yieldController.text.trim());
    if (lot == null || weight == null || yieldPercent == null) {
      setState(() => _error = 'Vui lòng chọn lô lúa và nhập đủ số liệu.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await widget.repository.createAndStartOrder(
        lot: lot,
        inputWeightKg: weight,
        expectedYield: yieldPercent / 100,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tạo lệnh xay mới'),
      content: SizedBox(
        width: 420,
        child: FutureBuilder<List<MillingPaddyLotOption>>(
          future: _lotsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Text('Không tải được lô lúa: ${snapshot.error}');
            }
            final lots = snapshot.data ?? const [];
            if (lots.isEmpty) {
              return const Text('Kho không còn lô lúa khả dụng để xay.');
            }
            _lotId ??= lots.first.id;
            final selected = lots.where((item) => item.id == _lotId).first;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _lotId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Lô lúa'),
                  items: [
                    for (final lot in lots)
                      DropdownMenuItem(
                        value: lot.id,
                        child: Text(
                          '${lot.code} - ${lot.remainingWeightKg.toStringAsFixed(1)} kg',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _lotId = value),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${selected.warehouseName} · ${selected.locationCode ?? 'Chưa xếp vị trí'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _weightController,
                  enabled: !_isSubmitting,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Khối lượng lúa đưa vào',
                    suffixText: 'kg',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _yieldController,
                  enabled: !_isSubmitting,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Tỷ lệ gạo dự kiến',
                    suffixText: '%',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : () => _submit(lots),
                    child:
                        Text(_isSubmitting ? 'Đang tạo...' : 'Tạo & bắt đầu'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}

class _ProductDropdown extends StatelessWidget {
  const _ProductDropdown({
    required this.label,
    required this.value,
    required this.products,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final List<MillingProductOption> products;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: products.any((item) => item.id == value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final product in products)
          DropdownMenuItem(
            value: product.id,
            child: Text('${product.sku} - ${product.name}'),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8DEE8)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

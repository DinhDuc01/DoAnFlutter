import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/auth_session_store.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../home/presentation/widgets/main_bottom_navigation.dart';
import '../../../products/data/product_variant_api.dart';
import '../../data/api_thu_mua_repository.dart';
import '../../data/thu_mua_repository.dart';
import '../../models/thu_mua_receipt.dart';
import '../widgets/thu_mua_header.dart';
import '../widgets/thu_mua_note_field.dart';
import '../widgets/thu_mua_product_card.dart';
import '../widgets/thu_mua_quantity_stepper.dart';
import '../widgets/thu_mua_receipt_fields.dart';

class ThuMuaScreen extends StatefulWidget {
  const ThuMuaScreen({this.repository, super.key});

  final ThuMuaRepository? repository;

  @override
  State<ThuMuaScreen> createState() => _ThuMuaScreenState();
}

class _ThuMuaScreenState extends State<ThuMuaScreen> {
  late final ThuMuaRepository _repository;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _unitCostController = TextEditingController();

  late final Future<ThuMuaReceipt> _receiptFuture;
  late final Future<List<ProductVariantStock>> _productsFuture;
  late final Future<List<ThuMuaSupplier>> _suppliersFuture;
  List<ProductVariantStock> _products = const [];
  List<ThuMuaSupplier> _suppliers = const [];
  ThuMuaReceipt? _receipt;
  int _quantity = 0;
  bool _quantityInitialized = false;
  bool _isSubmitting = false;
  bool _isChangingProduct = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiThuMuaRepository();
    _receiptFuture = _repository.getDraftReceipt();
    _productsFuture = _loadProducts();
    _suppliersFuture = _loadSuppliers();
  }

  Future<List<ThuMuaSupplier>> _loadSuppliers() async {
    final suppliers = await _repository.getSuppliers();
    _suppliers = suppliers;
    return suppliers;
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
    super.dispose();
  }

  void _setInitialQuantity(ThuMuaReceipt receipt) {
    if (_quantityInitialized) return;
    _receipt = receipt;
    _quantity = receipt.quantity;
    if (_unitCostController.text.isEmpty && receipt.unitCostPrice > 0) {
      _unitCostController.text = receipt.unitCostPrice.toStringAsFixed(0);
    }
    _quantityInitialized = true;
  }

  void _decreaseQuantity() {
    if (_quantity <= 0 || _isSubmitting) return;
    setState(() => _quantity--);
  }

  void _increaseQuantity() {
    if (_isSubmitting) return;
    setState(() => _quantity++);
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
                        '${product.sku} · Tồn hiện tại ${product.quantityOnHand} bao',
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
    final unitCostPrice = double.tryParse(_unitCostController.text.trim()) ?? 0;
    if (receipt.supplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn nhà cung cấp')),
      );
      return;
    }
    if (unitCostPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đơn giá nhập phải lớn hơn 0')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final submission = await _repository.confirmInbound(
        receipt: receipt,
        quantity: _quantity,
        unitCostPrice: unitCostPrice,
        note: _noteController.text,
      );

      if (!mounted) return;

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
      );

      Navigator.of(context).pushReplacementNamed(
        AppRoutes.thuMuaSuccess,
        arguments: result,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không cập nhật được tồn kho: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
    if (receipt.supplier == null && _suppliers.isNotEmpty) {
      _receipt = receipt.copyWith(supplier: _suppliers.first);
      receipt = _receipt!;
    }

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
                  labelText: 'Nhà cung cấp',
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
              labelText: 'Đơn giá mỗi bao',
              suffixText: 'đ/bao',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
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
            onDecrease: _decreaseQuantity,
            onIncrease: _increaseQuantity,
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
                : const Text('Tạo phiếu chờ xác nhận'),
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

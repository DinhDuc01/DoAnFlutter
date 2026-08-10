import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/auth_session_store.dart';
import '../../data/api_giao_hang_repository.dart';
import '../../data/giao_hang_repository.dart';
import '../../models/giao_hang_receipt.dart';
import '../widgets/giao_hang_header.dart';
import '../widgets/giao_hang_note_field.dart';
import '../widgets/giao_hang_product_card.dart';
import '../widgets/giao_hang_quantity_stepper.dart';
import '../widgets/giao_hang_receipt_fields.dart';

class GiaoHangScreen extends StatefulWidget {
  const GiaoHangScreen({this.initialReceipt, this.repository, super.key});

  final GiaoHangReceipt? initialReceipt;
  final GiaoHangRepository? repository;

  @override
  State<GiaoHangScreen> createState() => _GiaoHangScreenState();
}

class _GiaoHangScreenState extends State<GiaoHangScreen> {
  late final GiaoHangRepository _repository;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _unitPriceController = TextEditingController();
  final TextEditingController _shippingAddressController =
      TextEditingController();
  late final Future<GiaoHangReceipt> _receiptFuture;
  late final Future<List<GiaoHangCustomer>> _customersFuture;
  late final Future<List<Object>> _initialDataFuture;
  GiaoHangReceipt? _receipt;
  int _quantity = 1;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiGiaoHangRepository();
    _receiptFuture = widget.initialReceipt == null
        ? _repository.getDraftReceipt()
        : Future.value(widget.initialReceipt!);
    _customersFuture = _repository.getCustomers();
    _initialDataFuture =
        Future.wait<Object>([_receiptFuture, _customersFuture]);
  }

  @override
  void dispose() {
    _noteController.dispose();
    _unitPriceController.dispose();
    _shippingAddressController.dispose();
    super.dispose();
  }

  void _initialize(GiaoHangReceipt value, List<GiaoHangCustomer> customers) {
    if (_receipt != null) return;
    _receipt =
        customers.isEmpty ? value : value.copyWith(customer: customers.first);
    _quantity = value.quantity;
    if (value.unitSalePrice > 0) {
      _unitPriceController.text = value.unitSalePrice.toStringAsFixed(0);
    }
    _shippingAddressController.text =
        value.customer?.address ?? value.shippingAddress ?? '';
  }

  Future<void> _confirm() async {
    final receipt = _receipt;
    if (receipt == null || _isSubmitting) return;
    if (receipt.customer == null) {
      _message('Vui lòng chọn khách hàng nhận hàng.');
      return;
    }
    if (_quantity <= 0 || _quantity > receipt.currentStock) {
      _message('Số bao bán phải từ 1 đến ${receipt.currentStock}.');
      return;
    }
    final unitSalePrice =
        double.tryParse(_unitPriceController.text.trim()) ?? 0;
    if (unitSalePrice <= 0) {
      _message('Đơn giá bán phải lớn hơn 0.');
      return;
    }
    if (receipt.salesMode == SalesMode.delivery &&
        receipt.expectedDeliveryDate == null) {
      _message('Vui lòng chọn ngày giao hàng.');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final submission = await _repository.confirmOutbound(
        receipt: receipt,
        quantity: _quantity,
        unitSalePrice: unitSalePrice,
        expectedDeliveryDate: receipt.expectedDeliveryDate,
        shippingAddress: _shippingAddressController.text,
        note: _noteController.text,
      );
      if (!mounted) return;
      final user = AuthSessionStore.current?.user;
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.giaoHangSuccess,
        arguments: GiaoHangSuccessResult(
          receiptCode: submission.code,
          quantity: _quantity,
          productName: receipt.productName,
          sku: receipt.sku,
          customerName: receipt.customer!.name,
          customerPhone: receipt.customer!.phone,
          customerAddress: receipt.customer!.address,
          warehouseName: receipt.warehouseName,
          locationCode: receipt.locationCode,
          remainingStock: receipt.currentStock,
          performedBy: user?.fullName.isNotEmpty == true
              ? user!.fullName
              : 'Nhân viên kho',
          completedAt: DateTime.now(),
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          orderId: submission.id,
          status: submission.status,
          salesMode: receipt.salesMode,
          unitSalePrice: unitSalePrice,
          expectedDeliveryDate: receipt.expectedDeliveryDate,
        ),
      );
    } catch (error) {
      if (mounted) _message('Không thể tạo đơn bán: $error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        child: FutureBuilder<List<Object>>(
          future: _initialDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                      'Không tải được màn bán hàng: ${snapshot.error ?? ''}'),
                ),
              );
            }
            final initial = snapshot.data![0] as GiaoHangReceipt;
            final customers = snapshot.data![1] as List<GiaoHangCustomer>;
            _initialize(initial, customers);
            final receipt = _receipt!;
            return Column(
              children: [
                GiaoHangHeader(status: receipt.status),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SegmentedButton<SalesMode>(
                        segments: const [
                          ButtonSegment(
                            value: SalesMode.delivery,
                            icon: Icon(Icons.local_shipping_outlined),
                            label: Text('Giao hàng'),
                          ),
                          ButtonSegment(
                            value: SalesMode.direct,
                            icon: Icon(Icons.storefront_outlined),
                            label: Text('Bán trực tiếp'),
                          ),
                        ],
                        selected: {receipt.salesMode},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _receipt = receipt.copyWith(
                              salesMode: selection.first,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      GiaoHangProductCard(receipt: receipt),
                      const SizedBox(height: 12),
                      GiaoHangReceiptFields(receipt: receipt),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: receipt.customer?.id,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: receipt.salesMode == SalesMode.delivery
                              ? 'Khách hàng nhận hàng'
                              : 'Khách mua trực tiếp',
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        items: [
                          for (final customer in customers)
                            DropdownMenuItem(
                              value: customer.id,
                              child: Text(
                                '${customer.code} - ${customer.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (id) {
                          final customer = customers
                              .where((item) => item.id == id)
                              .firstOrNull;
                          if (customer != null) {
                            setState(() {
                              _receipt = receipt.copyWith(customer: customer);
                              if (_shippingAddressController.text.isEmpty) {
                                _shippingAddressController.text =
                                    customer.address ?? '';
                              }
                            });
                          }
                        },
                      ),
                      if (receipt.customer != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          [receipt.customer!.phone, receipt.customer!.address]
                              .where((value) => value?.isNotEmpty == true)
                              .join(' • '),
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _unitPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Đơn giá mỗi bao',
                          suffixText: 'đ/bao',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                      ),
                      if (receipt.salesMode == SalesMode.delivery) ...[
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          tileColor: AppColors.surfaceFor(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: AppColors.borderFor(context),
                            ),
                          ),
                          leading: const Icon(Icons.event_outlined),
                          title: const Text('Ngày giao hàng'),
                          subtitle: Text(
                            _formatDate(receipt.expectedDeliveryDate),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final selected = await showDatePicker(
                              context: context,
                              initialDate: receipt.expectedDeliveryDate ??
                                  DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (selected != null && mounted) {
                              setState(() {
                                _receipt = receipt.copyWith(
                                  expectedDeliveryDate: selected,
                                );
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _shippingAddressController,
                          decoration: const InputDecoration(
                            labelText: 'Địa chỉ giao hàng',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      GiaoHangQuantityStepper(
                        quantity: _quantity,
                        onDecrease: () {
                          if (_quantity > 1) setState(() => _quantity--);
                        },
                        onIncrease: () {
                          if (_quantity < receipt.currentStock) {
                            setState(() => _quantity++);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      GiaoHangNoteField(
                        controller: _noteController,
                        hintText: receipt.noteHint,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _isSubmitting ? null : _confirm,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.local_shipping_outlined),
                        label: Text(_isSubmitting
                            ? 'Đang xử lý...'
                            : 'Tạo đơn chờ xác nhận'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) return 'Chưa chọn';
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}

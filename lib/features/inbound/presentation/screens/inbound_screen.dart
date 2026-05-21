import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/inbound_repository.dart';
import '../../models/inbound_receipt.dart';
import '../widgets/inbound_bottom_bar.dart';
import '../widgets/inbound_header.dart';
import '../widgets/inbound_note_field.dart';
import '../widgets/inbound_product_card.dart';
import '../widgets/inbound_quantity_stepper.dart';
import '../widgets/inbound_receipt_fields.dart';

class InboundScreen extends StatefulWidget {
  const InboundScreen({super.key});

  @override
  State<InboundScreen> createState() => _InboundScreenState();
}

class _InboundScreenState extends State<InboundScreen> {
  final InboundRepository _repository = MockInboundRepository();
  final TextEditingController _noteController = TextEditingController();

  late final Future<InboundReceipt> _receiptFuture;
  InboundReceipt? _receipt;
  int _quantity = 0;
  bool _quantityInitialized = false;

  @override
  void initState() {
    super.initState();
    // API_SWAP: This is where the screen requests inbound data.
    _receiptFuture = _repository.getDraftReceipt();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _setInitialQuantity(InboundReceipt receipt) {
    _receipt = receipt;
    if (_quantityInitialized) return;
    _quantity = receipt.quantity;
    _quantityInitialized = true;
  }

  void _decreaseQuantity() {
    if (_quantity <= 0) return;
    setState(() => _quantity--);
  }

  void _increaseQuantity() {
    setState(() => _quantity++);
  }

  void _confirmInbound() {
    final receipt = _receipt;
    if (receipt == null) return;

    // API_SWAP: Send receiptCode, quantity and note to POST /inbound/confirm.
    final result = InboundSuccessResult(
      receiptCode: receipt.receiptCode,
      quantity: _quantity,
      productName: receipt.productName,
      sku: receipt.sku,
      warehouseName: 'Kho A - TP. HCM',
      performedBy: 'Nguyễn Văn A',
      completedAt: DateTime.now(),
    );

    Navigator.of(context).pushReplacementNamed(
      AppRoutes.inboundSuccess,
      arguments: result,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundStart,
      body: SafeArea(
        child: FutureBuilder<InboundReceipt>(
          future: _receiptFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(
                child: Text('Không tải được phiếu nhập kho'),
              );
            }

            final receipt = snapshot.data!;
            _setInitialQuantity(receipt);

            return Column(
              children: [
                InboundHeader(status: receipt.status),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InboundProductCard(receipt: receipt),
                        const SizedBox(height: 12),
                        InboundReceiptFields(receipt: receipt),
                        const SizedBox(height: 12),
                        InboundQuantityStepper(
                          quantity: _quantity,
                          onDecrease: _decreaseQuantity,
                          onIncrease: _increaseQuantity,
                        ),
                        const SizedBox(height: 12),
                        InboundNoteField(
                          controller: _noteController,
                          hintText: receipt.noteHint,
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: _confirmInbound,
                          child: const Text('Xác nhận nhập kho'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const InboundBottomBar(),
    );
  }
}

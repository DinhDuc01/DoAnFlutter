import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/outbound_repository.dart';
import '../../models/outbound_receipt.dart';
import '../widgets/outbound_bottom_bar.dart';
import '../widgets/outbound_header.dart';
import '../widgets/outbound_note_field.dart';
import '../widgets/outbound_product_card.dart';
import '../widgets/outbound_quantity_stepper.dart';
import '../widgets/outbound_receipt_fields.dart';

class OutboundScreen extends StatefulWidget {
  const OutboundScreen({super.key});

  @override
  State<OutboundScreen> createState() => _OutboundScreenState();
}

class _OutboundScreenState extends State<OutboundScreen> {
  final OutboundRepository _repository = MockOutboundRepository();
  final TextEditingController _noteController = TextEditingController();

  late final Future<OutboundReceipt> _receiptFuture;
  OutboundReceipt? _receipt;
  int _quantity = 0;
  bool _quantityInitialized = false;

  @override
  void initState() {
    super.initState();
    // API_SWAP: This is where the screen requests outbound data.
    _receiptFuture = _repository.getDraftReceipt();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _setInitialQuantity(OutboundReceipt receipt) {
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

  void _confirmOutbound() {
    final receipt = _receipt;
    if (receipt == null) return;

    // API_SWAP: Send receiptCode, quantity and note to POST /outbound/confirm.
    final result = OutboundSuccessResult(
      receiptCode: receipt.receiptCode,
      quantity: _quantity,
      productName: receipt.productName,
      sku: receipt.sku,
      customerName: receipt.customerName,
      performedBy: 'Nguyễn Văn A',
      completedAt: DateTime.now(),
    );

    Navigator.of(context).pushReplacementNamed(
      AppRoutes.outboundSuccess,
      arguments: result,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundStart,
      body: SafeArea(
        child: FutureBuilder<OutboundReceipt>(
          future: _receiptFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(
                child: Text('Không tải được phiếu xuất kho'),
              );
            }

            final receipt = snapshot.data!;
            _setInitialQuantity(receipt);

            return Column(
              children: [
                OutboundHeader(status: receipt.status),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutboundProductCard(receipt: receipt),
                        const SizedBox(height: 12),
                        OutboundReceiptFields(receipt: receipt),
                        const SizedBox(height: 12),
                        OutboundQuantityStepper(
                          quantity: _quantity,
                          onDecrease: _decreaseQuantity,
                          onIncrease: _increaseQuantity,
                        ),
                        const SizedBox(height: 12),
                        OutboundNoteField(
                          controller: _noteController,
                          hintText: receipt.noteHint,
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: _confirmOutbound,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF3478F6),
                          ),
                          child: const Text('Xác nhận xuất kho'),
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
      bottomNavigationBar: const OutboundBottomBar(),
    );
  }
}

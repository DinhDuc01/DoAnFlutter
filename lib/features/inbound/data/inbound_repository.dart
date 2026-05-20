import '../models/inbound_receipt.dart';

abstract class InboundRepository {
  Future<InboundReceipt> getDraftReceipt();
}

class MockInboundRepository implements InboundRepository {
  @override
  Future<InboundReceipt> getDraftReceipt() async {
    // API_SWAP: Replace this mock response with GET /inbound/draft or similar.
    await Future<void>.delayed(const Duration(milliseconds: 350));

    return const InboundReceipt(
      status: 'Nhập kho',
      productName: 'Bóng đèn LED 9W',
      sku: 'SKU-0001',
      currentStock: 8,
      receiptCode: 'PN-2025-005',
      weightKg: 0.15,
      quantity: 50,
      noteHint: 'Nhập ghi chú nếu có...',
    );
  }
}

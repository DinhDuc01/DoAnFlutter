import '../models/outbound_receipt.dart';

abstract class OutboundRepository {
  Future<OutboundReceipt> getDraftReceipt();
}

class MockOutboundRepository implements OutboundRepository {
  @override
  Future<OutboundReceipt> getDraftReceipt() async {
    // API_SWAP: Replace this mock response with GET /outbound/draft or similar.
    await Future<void>.delayed(const Duration(milliseconds: 350));

    return const OutboundReceipt(
      status: 'Xuất kho',
      productName: 'Cáp sạc Type-C 1m',
      sku: 'SKU-0002',
      currentStock: 245,
      receiptCode: 'PX-2025-005',
      customerName: 'Siêu thị BigC',
      quantity: 20,
      noteHint: 'Nhập ghi chú nếu có...',
    );
  }
}

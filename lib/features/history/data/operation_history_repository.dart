import '../models/operation_history.dart';

/// Lớp giao diện (Interface) định nghĩa các phương thức lấy lịch sử hoạt động kho hàng.
abstract class OperationHistoryRepository {
  /// Lấy danh sách lịch sử các hoạt động nhập/xuất/kiểm kho.
  Future<List<OperationHistory>> getHistories();
}

/// Lớp giả lập (Mock) của [OperationHistoryRepository] phục vụ thiết kế giao diện và chạy thử nghiệm.
class MockOperationHistoryRepository implements OperationHistoryRepository {
  /// Lấy danh sách lịch sử hoạt động giả lập sau một khoảng trễ ngắn.
  @override
  Future<List<OperationHistory>> getHistories() async {
    // API_SWAP: Thay thế phản hồi giả lập này bằng kết nối API GET /operation-histories thực tế.
    await Future<void>.delayed(const Duration(milliseconds: 350));

    return [
      OperationHistory(
        type: OperationHistoryType.inbound,
        productName: 'Bóng đèn LED 9W',
        sku: 'SKU-0001',
        referenceCode: 'PN-2025-005',
        quantityChange: 50,
        createdAt: DateTime(2026, 7, 15, 14, 32),
      ),
      OperationHistory(
        type: OperationHistoryType.outbound,
        productName: 'Sữa tươi Vinamilk 1L',
        sku: 'SKU-0004',
        referenceCode: 'PX-2025-004',
        quantityChange: -30,
        createdAt: DateTime(2026, 7, 15, 11, 15),
      ),
      OperationHistory(
        type: OperationHistoryType.inventory,
        productName: 'Áo thun nam size L',
        sku: 'SKU-0003',
        referenceCode: 'KK-2025-002',
        quantityChange: -5,
        createdAt: DateTime(2026, 7, 15, 9, 0),
      ),
      OperationHistory(
        type: OperationHistoryType.inbound,
        productName: 'Cáp sạc Type-C 1m',
        sku: 'SKU-0002',
        referenceCode: 'PN-2025-004',
        quantityChange: 150,
        createdAt: DateTime(2026, 7, 14, 16, 45),
      ),
      OperationHistory(
        type: OperationHistoryType.outbound,
        productName: 'Kem dưỡng da mặt',
        sku: 'SKU-0009',
        referenceCode: 'PX-2025-003',
        quantityChange: -30,
        createdAt: DateTime(2026, 7, 14, 14, 20),
      ),
    ];
  }
}

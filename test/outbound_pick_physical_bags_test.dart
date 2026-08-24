import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/outbound_orders/data/outbound_order_repository.dart';
import 'package:stocklite/features/outbound_orders/models/outbound_order.dart';

void main() {
  group('FIX-OUTBOUND-PICK-PHYSICAL-BAGS-01 Test Suite', () {
    test('OutboundOrderDetail correctly parses bagAllocations and filters activeBagAllocations', () {
      final json = {
        'id': 101,
        'salesOrderId': 55,
        'soCode': 'SO-2026-001',
        'customerId': 12,
        'customerName': 'Đại lý ABC',
        'outboundStatusId': OutboundStatusIds.picking,
        'outboundStatusName': 'Đang lấy hàng',
        'outboundStatusCode': 'PICKING',
        'warehouseId': 1,
        'warehouseName': 'Kho Tổng',
        'totalDispatchedValue': 50000000.0,
        'totalDispatchedSaleValue': 55000000.0,
        'items': <Map<String, dynamic>>[],
        'bagAllocations': [
          {
            'bagAllocationId': 1001,
            'outboundOrderItemId': 1,
            'bagId': 501,
            'bagNo': 1,
            'allocatedWeightKg': 25.5,
            'bagWeightSnapshotKg': 25.5,
            'pickedWeightKg': 0.0,
            'lotId': 10,
            'lotCode': 'LOT-ST25-01',
            'locationId': 2,
            'locationCode': 'A-01-01',
            'stackOrder': 1,
            'isFull': true,
            'status': 'ACTIVE',
          },
          {
            'bagAllocationId': 1002,
            'outboundOrderItemId': 1,
            'bagId': 502,
            'bagNo': 2,
            'allocatedWeightKg': 25.0,
            'bagWeightSnapshotKg': 25.0,
            'pickedWeightKg': 25.0,
            'lotId': 10,
            'lotCode': 'LOT-ST25-01',
            'locationId': 2,
            'locationCode': 'A-01-01',
            'stackOrder': 2,
            'isFull': true,
            'status': 'ACTIVE',
          },
          {
            'bagAllocationId': 1003,
            'outboundOrderItemId': 1,
            'bagId': 503,
            'bagNo': 3,
            'allocatedWeightKg': 24.5,
            'bagWeightSnapshotKg': 24.5,
            'pickedWeightKg': 0.0,
            'lotId': 10,
            'lotCode': 'LOT-ST25-01',
            'locationId': 2,
            'locationCode': 'A-01-01',
            'stackOrder': 3,
            'isFull': true,
            'status': 'CANCELLED',
          },
        ],
      };

      final order = OutboundOrderDetail.fromJson(json);

      expect(order.bagAllocations.length, 3);
      expect(order.activeBagAllocations.length, 2);

      final active1 = order.activeBagAllocations[0];
      expect(active1.bagAllocationId, 1001);
      expect(active1.bagNo, 1);
      expect(active1.bagLabel, 'Bao #1');
      expect(active1.lotLabel, 'LOT-ST25-01');
      expect(active1.locationLabel, 'A-01-01');
      expect(active1.allocatedWeightKg, 25.5);
      expect(active1.isActive, isTrue);

      final active2 = order.activeBagAllocations[1];
      expect(active2.bagAllocationId, 1002);
      expect(active2.allocatedWeightKg, 25.0);
      expect(active2.pickedWeightKg, 25.0);

      final cancelled = order.bagAllocations[2];
      expect(cancelled.isActive, isFalse);
    });

    test('PickAllocationPayload serializes bagAllocationId and quantityPicked', () {
      const payload = PickAllocationPayload(
        bagAllocationId: 1001,
        quantityPicked: 25.5,
      );

      final json = payload.toJson();

      expect(json.containsKey('bagAllocationId'), isTrue);
      expect(json['bagAllocationId'], 1001);
      expect(json['quantityPicked'], 25.5);
      expect(json.containsKey('allocationId'), isFalse);
    });
  });
}

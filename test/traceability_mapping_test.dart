import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/paddy_lots/models/paddy_lot.dart';

/// Payload rút gọn nhưng đúng hình dạng `PaddyLotTraceabilityDto` của backend.
const _payload = <String, dynamic>{
  'requestedLotId': 12,
  'requestedLotCode': 'LOT-2026-012',
  'isTruncated': true,
  'relatedLots': [
    {
      'id': 12,
      'lotCode': 'LOT-2026-012',
      'lotType': 'PADDY',
      'relationRole': 'SELF',
      'productVariantId': 3,
      'sku': 'LUA-OM18',
      'productVariantName': 'Lúa OM18',
      'riceVarietyName': 'OM18',
      'statusId': 2,
      'statusName': 'Sẵn sàng',
      'statusCode': 'READY',
      'isSellable': true,
      'isQuarantined': false,
      'warehouseId': 1,
      'warehouseName': 'Kho A',
      'locationId': 9,
      'locationCode': 'A-01-02',
      'inboundDate': '2026-07-01T08:00:00',
      'initialWeightKg': 10000,
      'remainingWeightKg': 2500.75,
      'qualityStatus': 'Ẩm 15.2%',
    },
    {
      'id': 30,
      'lotCode': 'LOT-RICE-030',
      'lotType': 'RICE',
      'relationRole': 'CHILD',
      'productVariantId': 8,
      'sku': 'GAO-OM18',
      'isSellable': true,
      'isQuarantined': false,
      'warehouseId': 1,
      'initialWeightKg': 6200,
      'remainingWeightKg': 1200,
      'inboundDate': '2026-07-10T09:00:00',
    },
  ],
  'purchases': [
    {
      'receiptId': 55,
      'receiptCode': 'PPR-055',
      'paddyLotId': 12,
      'paddyLotCode': 'LOT-2026-012',
      'farmerId': 4,
      'farmerCode': 'ND-004',
      'farmerName': 'Ông Bảy',
      'riceVarietyName': 'OM18',
      'warehouseId': 1,
      'warehouseName': 'Kho A',
      'receiptDate': '2026-07-01T07:30:00',
      'actualWeightKg': 10000,
      'bagCount': 200,
    },
  ],
  'qualityInspections': [
    {
      'inspectionId': 77,
      'paddyLotId': 12,
      'paddyLotCode': 'LOT-2026-012',
      'inspectedAt': '2026-07-02T10:00:00',
      'moisturePercent': 15.2,
      'impurityPercent': 1.8,
      'moldLevel': 'Không',
      'pestLevel': 'Nhẹ',
      'packagingStatus': 'Bao còn tốt',
      'handling': 'Sấy lại',
      'passedInspection': true,
      'resultName': 'Đạt',
      'inspectorName': 'Chị Lan',
      'note': 'Cần sấy trước khi xay',
    },
  ],
  'millingOrders': [
    {
      'millingOrderId': 21,
      'millingCode': 'MO-021',
      'statusId': 5,
      'statusName': 'Hoàn tất',
      'statusCode': 'COMPLETED',
      'warehouseId': 1,
      'warehouseName': 'Kho A',
      'yieldRateUsed': 0.65,
      'computedPaddyKg': 7500,
      'totalRiceOutputKg': 4800,
      'byproductKg': 2400,
      'lossKg': 300,
      'startedAt': '2026-07-09T08:00:00',
      'completedAt': '2026-07-10T08:00:00',
      'inputs': [
        {
          'millingOrderInputId': 1,
          'paddyLotId': 12,
          'paddyLotCode': 'LOT-2026-012',
          'lotType': 'PADDY',
          'productVariantId': 3,
          'sku': 'LUA-OM18',
          'locationId': 9,
          'locationCode': 'A-01-02',
          'reservedWeightKg': 7500,
          'consumedWeightKg': 7499.5,
        },
      ],
      'outputs': [
        {
          'millingOrderOutputId': 1,
          'outputLotId': 30,
          'outputLotCode': 'LOT-RICE-030',
          'productVariantId': 8,
          'sku': 'GAO-OM18',
          'productVariantName': 'Gạo OM18',
          'outputType': 'RICE',
          'outputWeightKg': 4800,
          'bagCount': 96,
          'isByproduct': false,
          'locationCode': 'B-02-01',
        },
        {
          'millingOrderOutputId': 2,
          'productVariantId': 11,
          'outputType': 'BRAN',
          'outputWeightKg': 2400,
          'isByproduct': true,
        },
      ],
    },
  ],
  'outboundSales': [
    {
      'outboundOrderId': 90,
      'outboundStatusId': 6,
      'outboundStatusName': 'Đã giao',
      'outboundStatusCode': 'COMPLETED',
      'completedDate': '2026-07-20T15:00:00',
      'warehouseId': 1,
      'warehouseName': 'Kho A',
      'salesOrderId': 44,
      'salesOrderCode': 'SO-044',
      'salesOrderStatusName': 'Hoàn tất',
      'customerId': 6,
      'customerCode': 'KH-006',
      'customerName': 'Đại lý Minh Phát',
      'salesOrderDate': '2026-07-18T09:00:00',
      'allocations': [
        {
          'allocationId': 500,
          'outboundOrderItemId': 300,
          'paddyLotId': 30,
          'paddyLotCode': 'LOT-RICE-030',
          'productVariantId': 8,
          'sku': 'GAO-OM18',
          'productVariantName': 'Gạo OM18',
          'locationId': 15,
          'locationCode': 'B-02-01',
          'quantityAllocatedKg': 3600,
          'quantityPickedKg': 3600,
        },
      ],
    },
  ],
  'timeline': [
    {
      'eventAt': '2026-07-01T07:30:00',
      'eventType': 'PURCHASE',
      'referenceType': 'PaddyPurchaseReceipt',
      'referenceId': 55,
      'referenceCode': 'PPR-055',
      'paddyLotIds': [12],
      'title': 'Thu mua lúa',
      'description': 'Mua 10.000 kg từ ông Bảy',
      'quantityKg': 10000,
      'sequence': 1,
    },
  ],
  'summary': {
    'relatedLotCount': 2,
    'purchaseReceiptCount': 1,
    'inspectionCount': 1,
    'millingOrderCount': 1,
    'outboundOrderCount': 1,
    'purchasedWeightKg': 10000,
    'millingInputWeightKg': 7500,
    'millingRiceOutputWeightKg': 4800,
    'millingByproductWeightKg': 2400,
    'millingLossWeightKg': 300,
    'allocatedOutboundWeightKg': 3600,
    'dispatchedWeightKg': 3600,
    'currentRemainingWeightKg': 2500.75,
  },
};

void main() {
  group('PaddyLotTraceability.fromJson', () {
    final data = PaddyLotTraceability.fromJson(_payload);

    test('map các trường gốc của lô được tra cứu', () {
      expect(data.requestedLotId, 12);
      expect(data.requestedLotCode, 'LOT-2026-012');
      expect(data.isTruncated, isTrue);
      expect(data.events, hasLength(1));
    });

    // Đây là lỗi cũ: model CHỈ đọc `timeline`, bỏ hết các nhánh còn lại.
    test('map đủ mọi nhánh chứ không riêng timeline', () {
      expect(data.relatedLots, hasLength(2));
      expect(data.purchases, hasLength(1));
      expect(data.inspections, hasLength(1));
      expect(data.millingOrders, hasLength(1));
      expect(data.outboundSales, hasLength(1));
      expect(data.hasDetail, isTrue);
    });

    test('tìm đúng lô đang tra cứu trong danh sách lô liên quan', () {
      final self = data.selfLot;
      expect(self, isNotNull);
      expect(self!.lotCode, 'LOT-2026-012');
      expect(self.remainingWeightKg, 2500.75);
      expect(self.locationCode, 'A-01-02');
      expect(self.riceVarietyName, 'OM18');
    });

    test('map chi tiết phiếu thu mua', () {
      final purchase = data.purchases.single;
      expect(purchase.receiptCode, 'PPR-055');
      expect(purchase.farmerName, 'Ông Bảy');
      expect(purchase.actualWeightKg, 10000);
      expect(purchase.bagCount, 200);
      expect(purchase.receiptDate, isNotNull);
    });

    test('map chi tiết kiểm định gồm cả chỉ tiêu chất lượng', () {
      final inspection = data.inspections.single;
      expect(inspection.passedInspection, isTrue);
      expect(inspection.moisturePercent, 15.2);
      expect(inspection.impurityPercent, 1.8);
      expect(inspection.handling, 'Sấy lại');
      expect(inspection.inspectorName, 'Chị Lan');
    });

    test('map lệnh xay kèm input và output lồng bên trong', () {
      final milling = data.millingOrders.single;
      expect(milling.millingCode, 'MO-021');
      expect(milling.yieldRateUsed, 0.65);
      expect(milling.inputs, hasLength(1));
      expect(milling.inputs.single.consumedWeightKg, 7499.5);
      expect(milling.outputs, hasLength(2));
      expect(milling.outputs.first.outputLotCode, 'LOT-RICE-030');
      expect(milling.outputs.last.isByproduct, isTrue);
      expect(milling.lossKg, 300);
    });

    test('map phiếu xuất bán kèm khách hàng và phân bổ lô', () {
      final outbound = data.outboundSales.single;
      expect(outbound.salesOrderCode, 'SO-044');
      expect(outbound.customerName, 'Đại lý Minh Phát');
      expect(outbound.allocations, hasLength(1));
      expect(outbound.allocations.single.paddyLotCode, 'LOT-RICE-030');
      expect(outbound.totalPickedKg, 3600);
    });

    test('map bảng cân đối khối lượng và tính tỉ lệ thu hồi thực tế', () {
      final summary = data.summary;
      expect(summary.purchasedWeightKg, 10000);
      expect(summary.millingInputWeightKg, 7500);
      expect(summary.millingRiceOutputWeightKg, 4800);
      expect(summary.millingLossWeightKg, 300);
      expect(summary.dispatchedWeightKg, 3600);
      expect(summary.currentRemainingWeightKg, 2500.75);
      expect(summary.actualYieldRate, closeTo(0.64, 0.001));
    });

    test('không vỡ khi backend chỉ trả timeline như bản cũ', () {
      final minimal = PaddyLotTraceability.fromJson(const {
        'requestedLotId': 1,
        'requestedLotCode': 'LOT-1',
        'timeline': <dynamic>[],
      });

      expect(minimal.relatedLots, isEmpty);
      expect(minimal.selfLot, isNull);
      expect(minimal.hasDetail, isFalse);
      expect(minimal.summary.purchasedWeightKg, 0);
      expect(minimal.summary.actualYieldRate, 0);
    });
  });
}

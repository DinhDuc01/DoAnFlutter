import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/account/models/account_profile.dart';
import 'package:stocklite/features/kho/models/stock_take.dart';
import 'package:stocklite/features/notifications/models/app_notification.dart';
import 'package:stocklite/features/products/data/product_variant_api.dart';
import 'package:stocklite/features/thu_mua/models/purchase_schedule.dart';

void main() {
  group('AccountProfile', () {
    test('copyWith updates settings and preserves profile data', () {
      const profile = AccountProfile(
        name: 'Tester',
        email: 'tester@example.com',
        role: 'QA',
        avatarInitial: 'T',
        inboundCount: 1,
        outboundCount: 2,
        inventoryCount: 3,
        assignedWarehouse: 'Kho A',
        notificationsEnabled: true,
        darkModeEnabled: false,
        language: 'Tiếng Việt',
      );

      final copied = profile.copyWith(
        notificationsEnabled: false,
        darkModeEnabled: true,
      );

      expect(copied.notificationsEnabled, isFalse);
      expect(copied.darkModeEnabled, isTrue);
      expect(copied.name, profile.name);
      expect(copied.inventoryCount, profile.inventoryCount);
    });
  });

  group('StockTakeLine', () {
    test('counts bags, not kilograms', () {
      final line = _line(systemBagCount: 3, systemQuantity: 150, bags: [
        _bag(1, 50, counted: true, countedWeightKg: 49.4),
        _bag(2, 50, counted: true),
        _bag(3, 50),
      ]);

      expect(line.hasBags, isTrue);
      expect(line.countedBags, 2);
      // Thiếu 1 bao — đây mới là con số kho quan tâm, không phải "hụt 50 kg".
      expect(line.bagDifference, -1);
    });

    test('bag without a weighing keeps its book weight', () {
      final line = _line(systemBagCount: 2, systemQuantity: 100, bags: [
        _bag(1, 50, counted: true, countedWeightKg: 48.5),
        _bag(2, 50, counted: true),
      ]);

      // 48.5 (cân thật) + 50 (không cân, giữ sổ sách) — KHÔNG quy bao chưa cân
      // về 0 và cũng không chia đều phần chênh lệch cho các bao.
      expect(line.countedKg, closeTo(98.5, 0.001));
      expect(line.effectiveActualKg, closeTo(98.5, 0.001));
    });

    test('line without bags falls back to the typed kilogram figure', () {
      final line = _line(systemBagCount: 0, systemQuantity: 80, bags: const [])
        ..actualQuantity = 78.25;

      expect(line.hasBags, isFalse);
      expect(line.effectiveActualKg, 78.25);
      expect(line.touched, isTrue);
    });

    test('untouched line reports nothing counted', () {
      final line = _line(systemBagCount: 2, systemQuantity: 100, bags: [
        _bag(1, 50),
        _bag(2, 50),
      ]);

      expect(line.touched, isFalse);
      expect(line.countedKg, 0);
      expect(line.bagDifference, -2);
    });

    test('toSaveJson sends per-bag results, never a client-side total', () {
      final line = _line(systemBagCount: 2, systemQuantity: 100, bags: [
        _bag(1, 50, counted: true, countedWeightKg: 49, scannedByQr: true),
        _bag(2, 50, counted: true),
      ])
        ..varianceReason = '  Bao số 1 rách  '
        ..note = '  Kiểm chiều  ';
      line.bags.first
        ..quality = BagQualityResult.issue
        ..packagingStatus = 'Rách'
        ..disposition = BagDisposition.quarantine
        ..targetLocationId = 7;

      final json = line.toSaveJson();

      // Dòng theo bao KHÔNG gửi tổng kg: backend tự tính lại từ các bao,
      // gửi lên chỉ tạo cơ hội cho client và server lệch nhau.
      expect(json.containsKey('actualQuantity'), isFalse);
      expect(json['varianceReason'], 'Bao số 1 rách');
      expect(json['note'], 'Kiểm chiều');

      final bags = json['bags'] as List<dynamic>;
      expect(bags, hasLength(2));
      final first = bags.first as Map<String, dynamic>;
      expect(first['qualityResult'], 'ISSUE_DETECTED');
      expect(first['packagingStatus'], 'Rách');
      expect(first['disposition'], 'QUARANTINE');
      expect(first['targetLocationId'], 7);
    });

    test('bags leaving the column are counted separately from the shortfall', () {
      final line = _line(systemBagCount: 3, systemQuantity: 150, bags: [
        _bag(1, 50, counted: true, disposition: BagDisposition.quarantine),
        _bag(2, 50, counted: true, disposition: BagDisposition.dispose),
        _bag(3, 50, counted: true),
      ]);

      // Cả 3 bao đều TÌM THẤY nên không lệch số bao; việc chuyển cách ly hay bỏ
      // bao hỏng là quyết định xử lý, không phải hụt kho.
      expect(line.bagDifference, 0);
      expect(line.quarantineBags, 1);
      expect(line.disposedBags, 1);
      expect(line.countedKg, closeTo(150, 0.001));
    });
  });

  group('BagQualityResult & BagDisposition', () {
    test('maps backend codes both ways', () {
      expect(BagQualityResultX.fromCode('ISSUE_DETECTED'), BagQualityResult.issue);
      expect(BagQualityResultX.fromCode('pass'), BagQualityResult.pass);
      expect(BagQualityResultX.fromCode(null), BagQualityResult.none);
      expect(BagQualityResult.none.code, isNull);
      expect(BagQualityResult.issue.isIssue, isTrue);

      expect(BagDispositionX.fromCode('QUARANTINE'), BagDisposition.quarantine);
      expect(BagDispositionX.fromCode('release'), BagDisposition.release);
      expect(BagDispositionX.fromCode(null), BagDisposition.keep);
      // Chuyển cách ly và rút về khu thường đều phải chọn vị trí đích.
      expect(BagDisposition.quarantine.needsTarget, isTrue);
      expect(BagDisposition.release.needsTarget, isTrue);
      expect(BagDisposition.dispose.needsTarget, isFalse);
      expect(BagDisposition.keep.needsTarget, isFalse);
    });
  });

  group('StockTakeDetail', () {
    test('parses the backend snapshot including bags', () {
      final detail = StockTakeDetail.fromJson(<String, dynamic>{
        'id': 12,
        'stCode': 'ST-12',
        'warehouseId': 3,
        'warehouseName': 'Kho Cần Thơ',
        'stockTakeStatusCode': 'DRAFT',
        'stockTakeStatusName': 'Nháp',
        'stockTakeItems': [
          {
            'id': 90,
            'lotCode': 'LOT-A',
            'zoneName': 'Khu A',
            'locationCode': 'A-01',
            'systemQuantity': 100,
            'systemBagCount': 2,
            'bags': [
              {
                'id': 2,
                'paddyLotBagId': 22,
                'bagNo': 2,
                'systemWeightKg': 50,
                'pickSequence': 2,
                'restowSequence': 1,
              },
              {
                'id': 1,
                'paddyLotBagId': 11,
                'bagNo': 1,
                'systemWeightKg': 50,
                'pickSequence': 1,
                'restowSequence': 2,
                'counted': true,
                'qualityResult': 'ISSUE_DETECTED',
              },
            ],
          },
        ],
      });

      expect(detail.code, 'ST-12');
      expect(detail.isDraft, isTrue);
      final line = detail.lines.single;
      expect(line.locationLabel, 'Khu A/A-01');
      expect(line.title, 'LOT-A');
      // Bao sắp theo THỨ TỰ LẤY RA (trên cột xuống), không theo số bao —
      // thủ kho phải dỡ đúng thứ tự đó mới lấy được bao ở dưới.
      expect(line.bags.map((b) => b.pickSequence), [1, 2]);
      expect(detail.totalBags, 2);
      expect(detail.countedBags, 1);
      expect(detail.missingBags, 1);
      expect(detail.hasQualityIssue, isTrue);
    });

    test('missingBags ignores surplus bags found on the floor', () {
      final detail = StockTakeDetail.fromJson(<String, dynamic>{
        'id': 13,
        'stCode': 'ST-13',
        'stockTakeItems': [
          {
            'id': 1,
            'systemBagCount': 1,
            'bags': [
              {'id': 1, 'bagNo': 1, 'systemWeightKg': 50, 'counted': true},
              {
                'id': 2,
                'bagNo': 2,
                'systemWeightKg': 50,
                'counted': true,
                'isUnexpected': true,
              },
            ],
          },
        ],
      });

      expect(detail.lines.single.bagDifference, 1);
      expect(detail.missingBags, 0);
    });
  });

  group('AppNotification', () {
    for (final entry in <AppNotificationType, (IconData, Color)>{
      AppNotificationType.alert: (
        Icons.warning_amber_rounded,
        const Color(0xFFFF3B30),
      ),
      AppNotificationType.warning: (
        Icons.notifications_none,
        const Color(0xFFFFA000),
      ),
      AppNotificationType.info: (
        Icons.inventory_2_outlined,
        const Color(0xFF3B82F6),
      ),
      AppNotificationType.success: (
        Icons.check_circle_outline,
        const Color(0xFF16B957),
      ),
    }.entries) {
      test('maps ${entry.key.name} to its icon, color and alert state', () {
        final notification = _notification(entry.key);

        expect(notification.icon, entry.value.$1);
        expect(notification.color, entry.value.$2);
        expect(
          notification.isAlert,
          entry.key == AppNotificationType.alert ||
              entry.key == AppNotificationType.warning,
        );
      });
    }
  });

  group('PurchaseSchedule', () {
    test('parses API fields and numeric strings', () {
      final schedule = PurchaseSchedule.fromJson({
        'ID': '7',
        'farmerId': 3,
        'scheduleCode': 'TM-007',
        'farmerName': 'Nông hộ A',
        'statusName': 'Đã lên lịch',
        'riceVarietyName': 'IR50404',
        'scheduleDate': '2026-07-22T08:30:00Z',
        'estimatedQtyKg': '1250.5',
        'location': 'Long An',
        'expectedPrice': '7200',
        'note': 'Gọi trước',
      });

      expect(schedule.id, 7);
      expect(schedule.estimatedWeightKg, 1250.5);
      expect(schedule.expectedPrice, 7200);
      expect(schedule.scheduledAt.toUtc(), DateTime.utc(2026, 7, 22, 8, 30));
    });

    test('uses safe fallback values for missing API fields', () {
      final before = DateTime.now();
      final schedule = PurchaseSchedule.fromJson(const {});
      final after = DateTime.now();

      expect(schedule.id, 0);
      expect(schedule.farmerName, 'Nông hộ');
      expect(schedule.status, 'Chưa xác định');
      expect(schedule.estimatedWeightKg, 0);
      expect(
        schedule.scheduledAt.isBefore(before),
        isFalse,
      );
      expect(schedule.scheduledAt.isAfter(after), isFalse);
    });

    test('detects cancelled Vietnamese status without case sensitivity', () {
      final schedule = PurchaseSchedule.fromJson({
        'statusName': 'ĐÃ HỦY LỊCH',
      });

      expect(schedule.isCancelled, isTrue);
    });

    test('copyWith enriches farmer contact and preserves schedule data', () {
      final original = PurchaseSchedule.fromJson({
        'id': 1,
        'farmerId': 2,
        'scheduleCode': 'TM-01',
        'farmerName': 'Cũ',
      });

      final copied = original.copyWith(
        farmerName: 'Mới',
        farmerPhone: '0900000000',
        farmerAddress: 'Long An',
      );

      expect(copied.farmerName, 'Mới');
      expect(copied.farmerPhone, '0900000000');
      expect(copied.farmerAddress, 'Long An');
      expect(copied.id, original.id);
      expect(copied.code, original.code);
    });
  });

  group('Product stock models', () {
    test('ProductStock derives available stock when API omits it', () {
      final stock = ProductStock.fromJson({
        'quantityOnHand': 20,
        'quantityReserved': 6,
        'warehouseId': 1,
      });

      expect(stock.quantityAvailable, 14);
      expect(stock.warehouses.single.quantityAvailable, 14);
    });

    test('ProductStock aggregates warehouses and latest stocktake date', () {
      final stock = ProductStock.fromInventoryList([
        {
          'warehouseId': 1,
          'warehouseName': 'Kho A',
          'quantityOnHand': 10,
          'quantityReserved': 2,
          'lastStockTakeDate': '2026-07-20T00:00:00Z',
        },
        {
          'warehouseId': 2,
          'warehouseName': 'Kho B',
          'quantityOnHand': 7,
          'quantityReserved': 1,
          'lastStockTakeDate': '2026-07-22T00:00:00Z',
        },
        'invalid-row',
      ]);

      expect(stock.quantityOnHand, 17);
      expect(stock.quantityReserved, 3);
      expect(stock.quantityAvailable, 14);
      expect(stock.warehouses, hasLength(2));
      expect(stock.lastStockTakeDate?.toUtc(), DateTime.utc(2026, 7, 22));
    });

    test('ProductVariantStock maps details and stock values', () {
      const stock = ProductStock(
        quantityOnHand: 9,
        quantityReserved: 2,
        quantityAvailable: 7,
      );

      final product = ProductVariantStock.fromJson(
        {
          'id': 5,
          'sku': 'GAO-01',
          'name': 'Gạo thơm',
          'weight': '25.5',
          'costPrice': 10000,
          'salePrice': '12000',
        },
        stock: stock,
      );

      expect(product.id, 5);
      expect(product.name, 'Gạo thơm');
      expect(product.weightKg, 25.5);
      expect(product.costPrice, 10000);
      expect(product.salePrice, 12000);
      expect(product.quantityAvailable, 7);
    });
  });
}

StockTakeLine _line({
  required int systemBagCount,
  required double systemQuantity,
  required List<StockTakeBag> bags,
}) {
  return StockTakeLine(
    id: 1,
    systemQuantity: systemQuantity,
    systemBagCount: systemBagCount,
    bags: bags,
    lotCode: 'LOT-A',
  );
}

StockTakeBag _bag(
  int bagNo,
  double systemWeightKg, {
  bool counted = false,
  double? countedWeightKg,
  bool scannedByQr = false,
  BagDisposition disposition = BagDisposition.keep,
}) {
  return StockTakeBag(
    id: bagNo,
    paddyLotBagId: bagNo * 10,
    bagNo: bagNo,
    systemWeightKg: systemWeightKg,
    // Bao số nhỏ nằm dưới đáy cột nên được lấy sau cùng.
    pickSequence: bagNo,
    restowSequence: bagNo,
    counted: counted,
    countedWeightKg: countedWeightKg,
    scannedByQr: scannedByQr,
    disposition: disposition,
  );
}

AppNotification _notification(AppNotificationType type) {
  return AppNotification(
    id: '1',
    type: type,
    title: 'Thông báo',
    message: 'Nội dung',
    timeAgo: 'Vừa xong',
    isRead: false,
  );
}

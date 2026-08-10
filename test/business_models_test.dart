import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/account/models/account_profile.dart';
import 'package:stocklite/features/giao_hang/models/giao_hang_receipt.dart';
import 'package:stocklite/features/kho/models/kho_check.dart';
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

  group('GiaoHangReceipt', () {
    test('uses fallback customer name before a customer is selected', () {
      expect(_deliveryReceipt().customerName, 'Chưa chọn khách hàng');
    });

    test('copyWith adds customer and preserves stock data', () {
      const customer = GiaoHangCustomer(
        id: 9,
        code: 'KH-09',
        name: 'Nhà máy A',
      );

      final copied = _deliveryReceipt().copyWith(customer: customer);

      expect(copied.customer, same(customer));
      expect(copied.customerName, 'Nhà máy A');
      expect(copied.currentStock, 50);
      expect(copied.productVariantId, 11);
    });
  });

  group('KhoCheck', () {
    test('calculates product count and total system quantity', () {
      final check = KhoCheck(
        warehouseId: 1,
        checkCode: 'ST-01',
        warehouseName: 'Kho A',
        noteHint: '',
        checkedAt: DateTime(2026),
        items: const [
          KhoCheckItem(
            productVariantId: 1,
            productName: 'Gạo',
            sku: 'GAO',
            systemQuantity: 10,
          ),
          KhoCheckItem(
            productVariantId: 2,
            productName: 'Cám',
            sku: 'CAM',
            systemQuantity: 7,
          ),
        ],
      );

      expect(check.totalProducts, 2);
      expect(check.totalSystemQuantity, 17);
    });

    test('difference is null until actual quantity is entered', () {
      const item = KhoCheckItem(
        productVariantId: 1,
        productName: 'Gạo',
        sku: 'GAO',
        systemQuantity: 10,
      );

      expect(item.difference, isNull);
      expect(item.copyWith(actualQuantity: 14).difference, 4);
      expect(item.copyWith(actualQuantity: 8).difference, -2);
    });

    test('copyWith can clear an existing actual quantity', () {
      const item = KhoCheckItem(
        productVariantId: 1,
        productName: 'Gạo',
        sku: 'GAO',
        systemQuantity: 10,
        actualQuantity: 9,
      );

      final cleared = item.copyWith(clearActualQuantity: true);

      expect(cleared.actualQuantity, isNull);
      expect(cleared.productName, item.productName);
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

GiaoHangReceipt _deliveryReceipt() {
  return const GiaoHangReceipt(
    productVariantId: 11,
    warehouseId: 1,
    warehouseName: 'Kho A',
    status: 'Sẵn sàng giao',
    productName: 'Gạo',
    sku: 'GAO',
    currentStock: 50,
    receiptCode: 'GH-01',
    quantity: 1,
    noteHint: '',
    unitSalePrice: 12000,
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

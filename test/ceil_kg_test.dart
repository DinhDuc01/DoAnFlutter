import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/utils/format.dart';

void main() {
  group('ceilKg — làm tròn LÊN 0,1 kg', () {
    test('số lẻ luôn đi lên, không bao giờ xuống', () {
      expect(ceilKg(12.31), 12.4);
      expect(ceilKg(12.301), 12.4);
      expect(ceilKg(12.39), 12.4);
      expect(ceilKg(0.01), 0.1);
    });

    test('số đã tròn 0,1 giữ nguyên (không bị đẩy lên oan)', () {
      expect(ceilKg(12.3), 12.3);
      expect(ceilKg(12.0), 12.0);
      expect(ceilKg(0), 0.0);
      // Sai số dấu phẩy động: 12.3 * 10 = 122.99999999999999.
      expect(ceilKg(0.1 + 0.2), 0.3);
      expect(ceilKg(49.9), 49.9);
    });

    test('null và số không hợp lệ trả 0', () {
      expect(ceilKg(null), 0.0);
      expect(ceilKg(double.nan), 0.0);
      expect(ceilKg(double.infinity), 0.0);
    });

    test('tổng nhiều bao vẫn là bội của 0,1', () {
      final bags = [12.4, 13.1, 11.9, 12.0];
      final total = ceilKg(bags.fold<double>(0, (sum, bag) => sum + bag));
      expect(total, 49.4);
    });
  });
}

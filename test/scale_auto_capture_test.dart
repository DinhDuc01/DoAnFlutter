import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/scale/data/scale_auto_capture.dart';
import 'package:stocklite/features/scale/models/weight_reading.dart';

WeightReading _reading(double weight, {bool stable = true}) => WeightReading(
      weight: weight,
      unit: 'kg',
      isStable: stable,
      receivedAt: DateTime(2026, 8, 13),
    );

void main() {
  final t0 = DateTime(2026, 8, 13, 9);
  DateTime after(int ms) => t0.add(Duration(milliseconds: ms));

  group('ScaleAutoCapture', () {
    test('không nhận khi cân còn rung', () {
      final capture = ScaleAutoCapture();

      expect(capture.offer(_reading(48.6, stable: false), t0), isNull);
      expect(capture.offer(_reading(48.6, stable: false), after(5000)), isNull);
    });

    test('chỉ nhận sau khi ổn định đủ cửa sổ thời gian', () {
      final capture = ScaleAutoCapture();

      expect(capture.offer(_reading(48.6), t0), isNull);
      expect(capture.offer(_reading(48.6), after(1400)), isNull);
      expect(capture.offer(_reading(48.6), after(1500)), 48.6);
    });

    test('không nhận lại khi bao vẫn nằm trên cân', () {
      final capture = ScaleAutoCapture();
      capture.offer(_reading(48.6), t0);
      expect(capture.offer(_reading(48.6), after(1600)), 48.6);

      // Vẫn ổn định, vẫn cùng số → tuyệt đối không được nhận thêm lần nữa.
      expect(capture.offer(_reading(48.6), after(3200)), isNull);
      expect(capture.offer(_reading(48.6), after(9000)), isNull);
    });

    test('mở khoá cho bao kế tiếp sau khi nhấc hàng ra', () {
      final capture = ScaleAutoCapture();
      capture.offer(_reading(48.6), t0);
      expect(capture.offer(_reading(48.6), after(1600)), 48.6);

      // Nhấc bao ra → cân về 0.
      expect(capture.offer(_reading(0), after(2000)), isNull);
      // Đặt bao mới lên.
      expect(capture.offer(_reading(50.1), after(2400)), isNull);
      expect(capture.offer(_reading(50.1), after(4000)), 50.1);
    });

    test('bao thứ hai trùng khối lượng bao thứ nhất vẫn được nhận', () {
      final capture = ScaleAutoCapture();
      capture.offer(_reading(50), t0);
      expect(capture.offer(_reading(50), after(1600)), 50);

      expect(capture.offer(_reading(0), after(1800)), isNull);
      capture.offer(_reading(50), after(2000));
      expect(capture.offer(_reading(50), after(3600)), 50);
    });

    test('bỏ qua số quá nhẹ (cân trống)', () {
      final capture = ScaleAutoCapture();

      expect(capture.offer(_reading(0.01), t0), isNull);
      expect(capture.offer(_reading(0.01), after(5000)), isNull);
    });

    test('suppressCurrent chặn nhận lại sau khi người dùng hoàn tác', () {
      final capture = ScaleAutoCapture();
      capture.offer(_reading(48.6), t0);
      expect(capture.offer(_reading(48.6), after(1600)), 48.6);

      capture.suppressCurrent();
      expect(capture.offer(_reading(48.6), after(4000)), isNull);

      // Nhấc ra rồi đặt lại thì mới nhận tiếp.
      capture.offer(_reading(0), after(4200));
      capture.offer(_reading(48.6), after(4400));
      expect(capture.offer(_reading(48.6), after(6000)), 48.6);
    });

    test('progressAt phản ánh tiến trình chờ ổn định', () {
      final capture = ScaleAutoCapture();

      expect(capture.progressAt(t0), 0);
      capture.offer(_reading(20), t0);
      expect(capture.progressAt(after(750)), closeTo(0.5, 0.001));
      expect(capture.progressAt(after(3000)), 1);
    });

    test('reset đưa về trạng thái sẵn sàng nhận', () {
      final capture = ScaleAutoCapture();
      capture.offer(_reading(20), t0);
      expect(capture.offer(_reading(20), after(1600)), 20);

      capture.reset();
      capture.offer(_reading(20), after(2000));
      expect(capture.offer(_reading(20), after(3600)), 20);
    });
  });
}

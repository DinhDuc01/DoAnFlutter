import 'dart:async';
import 'package:meta/meta.dart';

import 'ble_scale_service.dart';

/// Giữ MỘT kết nối cân BLE dùng chung cho cả app.
///
/// Trước đây mỗi màn tự tạo [BleScaleService] rồi hủy khi thoát, nên lần nào
/// cần cân cũng phải quét + kết nối lại từ đầu. Với các bước cân liên tiếp
/// (đóng gói nhiều phiếu, cân nhiều bao) thao tác đó lặp lại rất tốn thời gian.
///
/// [ScaleSession] giữ service sống suốt phiên làm việc: kết nối một lần, các
/// lần sau mở form cân là số đã chảy về ngay. Người dùng chủ động ngắt kết nối
/// khi cân xong.
class ScaleSession {
  ScaleSession._();
  
  static final ScaleSession instance = ScaleSession._();

  BleScaleService? _service;
  Future<void>? _initializing;

  @visibleForTesting
  void debugSetService(BleScaleService? service, {Future<void>? initializing}) {
    _service = service;
    _initializing = initializing;
  }

  /// Service dùng chung (chưa chắc đã initialize). Null khi chưa ai dùng cân.
  BleScaleService? get serviceOrNull => _service;

  bool get isConnected => _service?.isConnected ?? false;

  /// Lấy service đã `initialize()`. Gọi nhiều lần vẫn chỉ initialize một lần.
  Future<BleScaleService> ensureInitialized() async {
    final service = _service ??= BleScaleService();
    _initializing ??= service.initialize();
    await _initializing;
    return service;
  }

  /// Quét cân. Nếu chỉ tìm thấy đúng một thiết bị thì tự kết nối luôn để bớt
  /// một thao tác; nhiều thiết bị thì trả về danh sách cho UI chọn.
  ///
  /// Trả về danh sách thiết bị tìm được (rỗng nghĩa là không thấy cân nào).
  Future<List<ScaleScanDevice>> scanAndAutoConnect({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final service = await ensureInitialized();
    if (service.isConnected) return const [];

    await service.startScan();

    // Chờ tới khi có thiết bị đầu tiên hoặc hết thời gian quét.
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (service.scanDevices.isNotEmpty) break;
      if (!service.isScanning) break; // scan dừng sớm (lỗi/timeout của lib)
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    // Chờ thêm một nhịp ngắn để gom nốt các thiết bị quảng bá chậm hơn, tránh
    // tự kết nối nhầm khi thực tế có nhiều cân trong kho.
    if (service.scanDevices.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }

    final devices = service.scanDevices;
    await service.stopScan();

    if (devices.length == 1) {
      await service.connect(devices.first);
      return const [];
    }
    return devices;
  }

  Future<void> connect(ScaleScanDevice device) async {
    final service = await ensureInitialized();
    await service.connect(device);
  }

  Future<void> disconnect() async {
    await _service?.disconnect();
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/weight_reading.dart';

enum ScaleConnectionStatus {
  idle,
  scanning,
  connecting,
  connected,
  disconnecting,
  error,
}

class ScaleScanDevice {
  const ScaleScanDevice({
    required this.device,
    required this.name,
    required this.rssi,
  });

  final BluetoothDevice device;
  final String name;
  final int rssi;
}

/// Owns the BLE connection and the StockLite ESP32 scale protocol.
class BleScaleService extends ChangeNotifier {
  static const advertisedNamePrefix = 'StockLite';
  static const serviceUuid = '9a8f0001-6f3a-4b6e-9d2a-1c7e3f5a0b10';
  static const weightCharacteristicUuid =
      '9a8f0002-6f3a-4b6e-9d2a-1c7e3f5a0b10';
  static const commandCharacteristicUuid =
      '9a8f0003-6f3a-4b6e-9d2a-1c7e3f5a0b10';

  final Map<String, ScaleScanDevice> _deviceMap = {};
  final List<StreamSubscription<dynamic>> _appSubscriptions = [];
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _weightSubscription;
  BluetoothCharacteristic? _weightCharacteristic;
  BluetoothCharacteristic? _commandCharacteristic;
  BluetoothDevice? _connectedDevice;
  WeightReading? _reading;
  String? _errorMessage;
  String? _lastCommand;
  ScaleConnectionStatus _status = ScaleConnectionStatus.idle;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  bool _disposed = false;

  ScaleConnectionStatus get status => _status;
  BluetoothAdapterState get adapterState => _adapterState;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  WeightReading? get reading => _reading;
  String? get errorMessage => _errorMessage;
  String? get lastCommand => _lastCommand;
  bool get isConnected => _status == ScaleConnectionStatus.connected;
  bool get isScanning => _status == ScaleConnectionStatus.scanning;
  List<ScaleScanDevice> get scanDevices {
    final devices = _deviceMap.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return List.unmodifiable(devices);
  }

  Future<void> initialize() async {
    FlutterBluePlus.setLogLevel(LogLevel.warning, color: false);
    _adapterState = FlutterBluePlus.adapterStateNow;
    _appSubscriptions.add(
      FlutterBluePlus.adapterState.listen((state) {
        _adapterState = state;
        if (state != BluetoothAdapterState.on && isScanning) {
          _status = ScaleConnectionStatus.idle;
        }
        _notify();
      }),
    );
    _appSubscriptions.add(
      FlutterBluePlus.onScanResults.listen(
        _onScanResults,
        onError: (Object error, StackTrace stackTrace) {
          _setError(_friendlyError(error));
        },
      ),
    );
    _appSubscriptions.add(
      FlutterBluePlus.isScanning.listen((scanning) {
        if (!scanning && _status == ScaleConnectionStatus.scanning) {
          _status = ScaleConnectionStatus.idle;
          _notify();
        }
      }),
    );

    if (!await FlutterBluePlus.isSupported) {
      _setError('Thiết bị này không hỗ trợ Bluetooth Low Energy.');
      return;
    }
    _notify();
  }

  Future<void> requestPermissions() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final statuses = await <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    if (statuses.values.any((status) => status.isPermanentlyDenied)) {
      throw StateError(
        'Quyền Bluetooth đã bị từ chối vĩnh viễn. Hãy cấp lại trong Cài đặt ứng dụng.',
      );
    }
    if (statuses[Permission.bluetoothScan]?.isDenied == true ||
        statuses[Permission.bluetoothConnect]?.isDenied == true) {
      throw StateError('Ứng dụng cần quyền Thiết bị ở gần để kết nối cân.');
    }
  }

  Future<void> startScan() async {
    if (_status == ScaleConnectionStatus.connecting || isConnected) return;
    try {
      _errorMessage = null;
      await requestPermissions();
      if (_adapterState != BluetoothAdapterState.on) {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          await FlutterBluePlus.turnOn();
        }
        await FlutterBluePlus.adapterState
            .where((state) => state == BluetoothAdapterState.on)
            .first
            .timeout(const Duration(seconds: 8));
      }
      _deviceMap.clear();
      _status = ScaleConnectionStatus.scanning;
      _notify();
      await FlutterBluePlus.startScan(
        withServices: <Guid>[Guid(serviceUuid)],
        timeout: const Duration(seconds: 10),
      );
    } catch (error) {
      _setError(_friendlyError(error));
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    if (_status == ScaleConnectionStatus.scanning) {
      _status = ScaleConnectionStatus.idle;
      _notify();
    }
  }

  void _onScanResults(List<ScanResult> results) {
    for (final result in results) {
      final advertisedName = result.advertisementData.advName.trim();
      final platformName = result.device.platformName.trim();
      final name = advertisedName.isNotEmpty
          ? advertisedName
          : (platformName.isNotEmpty ? platformName : 'StockLite Scale');
      final correctName = name.startsWith(advertisedNamePrefix);
      final correctService = result.advertisementData.serviceUuids
          .any((uuid) => uuid == Guid(serviceUuid));
      if (!correctName && !correctService) continue;
      _deviceMap[result.device.remoteId.str] = ScaleScanDevice(
        device: result.device,
        name: name,
        rssi: result.rssi,
      );
    }
    _notify();
  }

  Future<void> connect(ScaleScanDevice scanDevice) async {
    if (_status == ScaleConnectionStatus.connecting) return;
    try {
      _errorMessage = null;
      _status = ScaleConnectionStatus.connecting;
      _notify();
      await FlutterBluePlus.stopScan();
      await _cancelDeviceSubscriptions();
      final device = scanDevice.device;
      _connectedDevice = device;
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected &&
            _status != ScaleConnectionStatus.disconnecting) {
          _weightCharacteristic = null;
          _commandCharacteristic = null;
          _status = ScaleConnectionStatus.idle;
          _errorMessage = 'Cân đã ngắt kết nối.';
          _notify();
        }
      });
      if (!device.isConnected) {
        await device.connect(
          license: License.nonprofit,
          timeout: const Duration(seconds: 15),
          autoConnect: false,
        );
      }
      final services = await device.discoverServices();
      final service = services.firstWhere(
        (item) => item.uuid == Guid(serviceUuid),
        orElse: () => throw StateError('Không tìm thấy dịch vụ cân StockLite.'),
      );
      _weightCharacteristic = service.characteristics.firstWhere(
        (item) => item.uuid == Guid(weightCharacteristicUuid),
        orElse: () => throw StateError('Không tìm thấy kênh đọc trọng lượng.'),
      );
      _commandCharacteristic = service.characteristics.firstWhere(
        (item) => item.uuid == Guid(commandCharacteristicUuid),
        orElse: () => throw StateError('Không tìm thấy kênh điều khiển cân.'),
      );
      _weightSubscription = _weightCharacteristic!.onValueReceived.listen(
        _onWeightValue,
        onError: (Object error, StackTrace stackTrace) {
          _setError('Không nhận được dữ liệu cân: ${_friendlyError(error)}');
        },
      );
      device.cancelWhenDisconnected(_weightSubscription!);
      await _weightCharacteristic!.setNotifyValue(true);
      final initialValue = await _weightCharacteristic!.read();
      if (initialValue.isNotEmpty) _onWeightValue(initialValue);
      _status = ScaleConnectionStatus.connected;
      _notify();
    } catch (error) {
      final device = _connectedDevice;
      if (device != null && device.isConnected) await device.disconnect();
      _connectedDevice = null;
      await _cancelDeviceSubscriptions();
      _setError(_friendlyError(error));
    }
  }

  void _onWeightValue(List<int> bytes) {
    try {
      _reading = WeightReading.fromBytes(bytes);
      _errorMessage = null;
      _notify();
    } catch (error) {
      _errorMessage = 'Dữ liệu cân không hợp lệ: ${_friendlyError(error)}';
      _notify();
    }
  }

  Future<void> sendCommand(String command) async {
    final characteristic = _commandCharacteristic;
    if (!isConnected || characteristic == null) {
      throw StateError('Chưa kết nối với cân.');
    }
    final normalized = command.trim().toUpperCase();
    if (!const {'TARE', 'RESET', 'CALIBRATE'}.contains(normalized)) {
      throw ArgumentError.value(command, 'command', 'Lệnh không được hỗ trợ.');
    }
    await characteristic.write(utf8.encode(normalized), withoutResponse: false);
    _lastCommand = normalized;
    _notify();
  }

  Future<void> disconnect() async {
    final device = _connectedDevice;
    if (device == null) return;
    _status = ScaleConnectionStatus.disconnecting;
    _notify();
    try {
      if (_weightCharacteristic?.isNotifying ?? false) {
        await _weightCharacteristic!.setNotifyValue(false);
      }
      await device.disconnect();
    } finally {
      await _cancelDeviceSubscriptions();
      _weightCharacteristic = null;
      _commandCharacteristic = null;
      _connectedDevice = null;
      _status = ScaleConnectionStatus.idle;
      _notify();
    }
  }

  Future<void> openSettings() => openAppSettings();

  Future<void> _cancelDeviceSubscriptions() async {
    await _weightSubscription?.cancel();
    _weightSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
  }

  String _friendlyError(Object error) {
    if (error is TimeoutException) {
      return 'Hết thời gian chờ Bluetooth. Hãy đưa điện thoại gần cân và thử lại.';
    }
    return error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Invalid argument(s): ', '')
        .replaceFirst('Exception: ', '');
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = ScaleConnectionStatus.error;
    _notify();
  }

  void clearError() {
    _errorMessage = null;
    if (_status == ScaleConnectionStatus.error) {
      _status = ScaleConnectionStatus.idle;
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _appSubscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_cancelDeviceSubscriptions());
    final device = _connectedDevice;
    if (device != null && device.isConnected) unawaited(device.disconnect());
    super.dispose();
  }
}

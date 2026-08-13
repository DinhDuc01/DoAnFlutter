import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../data/ble_scale_service.dart';
import '../../data/scale_session.dart';
import '../../models/weight_reading.dart';

/// Connects to a StockLite BLE scale and returns one stable reading.
///
/// Dùng [ScaleSession] — kết nối được giữ sống suốt phiên làm việc, nên lần thứ
/// hai trở đi mở màn này số cân đã chảy về sẵn, không phải quét + nối lại.
class ScaleScreen extends StatefulWidget {
  const ScaleScreen({super.key});

  @override
  State<ScaleScreen> createState() => _ScaleScreenState();
}

class _ScaleScreenState extends State<ScaleScreen> {
  BleScaleService? _service;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final service = await ScaleSession.instance.ensureInitialized();
      if (!mounted) return;
      _service = service;
      // Chưa nối thì tự quét luôn — bớt một lần bấm "Tìm cân".
      if (!service.isConnected) {
        unawaited(ScaleSession.instance.scanAndAutoConnect());
      }
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  // KHÔNG dispose service: kết nối thuộc về ScaleSession, dùng chung cả app.
  // Người dùng chủ động ngắt bằng nút "Ngắt kết nối cân".

  @override
  Widget build(BuildContext context) {
    final service = _service;
    if (_initializing || service == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cân StockLite')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cân StockLite'),
              Text(
                'Kết nối ESP32 qua Bluetooth',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                  child: _ConnectionBadge(connected: service.isConnected)),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              if (service.errorMessage != null) ...[
                _ErrorBanner(
                  message: service.errorMessage!,
                  onClose: service.clearError,
                  onSettings:
                      service.errorMessage!.toLowerCase().contains('quyền')
                          ? service.openSettings
                          : null,
                ),
                const SizedBox(height: 12),
              ],
              if (service.isConnected)
                _buildConnectedContent(service)
              else
                _buildDiscoveryContent(service),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoveryContent(BleScaleService service) {
    final bluetoothOn = service.adapterState == BluetoothAdapterState.on;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 36,
                  child: Icon(Icons.bluetooth_searching_rounded, size: 38),
                ),
                const SizedBox(height: 16),
                Text(
                  bluetoothOn ? 'Tìm cân ở gần' : 'Bluetooth đang tắt',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bật cân ESP32 StockLite, đặt điện thoại ở gần rồi bắt đầu tìm thiết bị.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: service.isScanning
                      ? service.stopScan
                      : service.startScan,
                  icon: service.isScanning
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.radar_rounded),
                  label: Text(
                    service.isScanning ? 'Dừng tìm kiếm' : 'Tìm cân',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Thiết bị tìm thấy (${service.scanDevices.length})',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (service.scanDevices.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Chưa tìm thấy cân StockLite. Kiểm tra ESP32 đang phát BLE rồi quét lại.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...service.scanDevices.map(
            (device) => Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.scale_rounded)),
                title: Text(
                  device.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('RSSI ${device.rssi} dBm'),
                trailing: FilledButton(
                  onPressed: service.status == ScaleConnectionStatus.connecting
                      ? null
                      : () => service.connect(device),
                  child: const Text('Kết nối'),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildConnectedContent(BleScaleService service) {
    final reading = service.reading;
    final stable = reading?.isStable == true && (reading?.isFresh() ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: BoxDecoration(
            color: const Color(0xFF0E6B4A),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'TRỌNG LƯỢNG THỰC TẾ',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    stable ? 'ỔN ĐỊNH' : 'ĐANG ĐỌC',
                    style: TextStyle(
                      color: stable ? const Color(0xFFBDF4D6) : Colors.white70,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              FittedBox(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: reading?.weight.toStringAsFixed(3) ?? '---',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 62,
                          fontWeight: FontWeight.w900,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      TextSpan(
                        text: ' ${reading?.unit ?? 'kg'}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                stable
                    ? 'Số cân đã ổn định, có thể nhận khối lượng.'
                    : 'Giữ bao đứng yên cho đến khi cân báo ổn định.',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: stable && reading!.weight > 0
              ? () => Navigator.of(context).pop<WeightReading>(
                    // Kèm tên thiết bị để màn gọi ghi lại được nguồn số cân.
                    reading.copyWith(
                      deviceName: service.connectedDevice?.platformName,
                    ),
                  )
              : null,
          icon: const Icon(Icons.add_task_rounded),
          label: const Text('Nhận số cân và thêm bao'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _sendCommand('TARE'),
                icon: const Icon(Icons.exposure_zero_rounded),
                label: const Text('Cân bì'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _sendCommand('RESET'),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Khởi động lại'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: service.disconnect,
          icon: const Icon(Icons.link_off_rounded),
          label: const Text('Ngắt kết nối cân'),
        ),
      ],
    );
  }

  Future<void> _sendCommand(String command) async {
    try {
      await _service?.sendCommand(command);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã gửi lệnh $command tới cân.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không gửi được lệnh: $error')),
        );
      }
    }
  }
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: connected ? const Color(0xFFE3F7EC) : const Color(0xFFF1F3F2),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        connected ? 'Đã nối' : 'Chưa nối',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onClose,
    this.onSettings,
  });

  final String message;
  final VoidCallback onClose;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFE8E6),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFB42318)),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            if (onSettings != null)
              TextButton(onPressed: onSettings, child: const Text('Cài đặt')),
            IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
          ],
        ),
      ),
    );
  }
}

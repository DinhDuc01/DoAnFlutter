import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/utils/format.dart';
import '../../data/ble_scale_service.dart';
import '../../data/scale_session.dart';

/// Chip trạng thái cân đặt trên header màn hình nghiệp vụ.
///
/// Cho thủ kho thấy ngay cân đã nối chưa và số đang đọc là bao nhiêu, mà không
/// phải mở form nào. Bấm vào chip để nối (hoặc ngắt) — nối MỘT lần rồi cân
/// liên tiếp nhiều phiếu, đó là lý do kết nối được giữ ở [ScaleSession].
class ScaleStatusChip extends StatefulWidget {
  const ScaleStatusChip({this.session, this.onLight = true, super.key});

  final ScaleSession? session;

  /// true khi đặt trên nền xanh đậm (header gradient).
  final bool onLight;

  @override
  State<ScaleStatusChip> createState() => _ScaleStatusChipState();
}

class _ScaleStatusChipState extends State<ScaleStatusChip> {
  ScaleSession get _session => widget.session ?? ScaleSession.instance;

  BleScaleService? _service;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Chỉ bám vào service nếu đã có ai đó dùng cân trong phiên này; không tự
    // khởi tạo BLE chỉ để vẽ một cái chip.
    final existing = _session.serviceOrNull;
    if (existing != null) {
      _service = existing;
      existing.addListener(_onChanged);
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service?.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _tap() async {
    final service = _service;
    if (service != null && service.isConnected) {
      await _confirmDisconnect();
      return;
    }
    setState(() => _busy = true);
    try {
      final attached = await _session.ensureInitialized();
      if (!mounted) return;
      if (!identical(attached, _service)) {
        _service?.removeListener(_onChanged);
        _service = attached;
        attached.addListener(_onChanged);
      }
      final devices = await _session.scanAndAutoConnect();
      if (!mounted) return;
      if (devices.length > 1) {
        await _pickDevice(devices);
      } else if (devices.isEmpty && !attached.isConnected) {
        _snack('Không tìm thấy cân StockLite ở gần.');
      }
    } catch (error) {
      if (mounted) _snack('Không kết nối được cân: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDisconnect() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ngắt kết nối cân?'),
        content: const Text(
          'Lần cân sau sẽ phải quét và kết nối lại từ đầu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Giữ kết nối'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ngắt'),
          ),
        ],
      ),
    );
    if (yes == true) await _session.disconnect();
  }

  Future<void> _pickDevice(List<ScaleScanDevice> devices) async {
    final chosen = await showModalBottomSheet<ScaleScanDevice>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Chọn cân để kết nối',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
            for (final device in devices)
              ListTile(
                leading: const Icon(Icons.scale_rounded),
                title: Text(device.name),
                subtitle: Text('Tín hiệu ${device.rssi} dBm'),
                onTap: () => Navigator.of(context).pop(device),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null) await _session.connect(chosen);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final service = _service;
    final connected = service?.isConnected ?? false;
    final reading = connected ? service?.reading : null;
    final foreground = widget.onLight ? Colors.white : Colors.black87;

    final label = _busy
        ? 'Đang tìm…'
        : !connected
            ? 'Chưa nối cân'
            : reading == null
                ? 'Đã nối cân'
                : '${formatNumber(reading.weight, digits: 2)} kg';

    return Tooltip(
      message: connected ? 'Chạm để ngắt kết nối cân' : 'Chạm để kết nối cân',
      child: Material(
        color: foreground.withValues(alpha: connected ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          onTap: _busy ? null : () => unawaited(_tap()),
          borderRadius: BorderRadius.circular(99),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_busy)
                  SizedBox.square(
                    dimension: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                else
                  Icon(
                    connected
                        ? Icons.scale_rounded
                        : Icons.bluetooth_disabled_rounded,
                    size: 15,
                    color: foreground,
                  ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

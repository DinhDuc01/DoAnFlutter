import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../data/ble_scale_service.dart';
import '../../data/scale_auto_capture.dart';
import '../../data/scale_preferences.dart';
import '../../data/scale_session.dart';
import '../../models/weight_reading.dart';

/// Thanh cân "dính" — nguồn nhập khối lượng chạy nền, đặt ngay trên ô nhập kg.
///
/// Thay cho cách cũ (đẩy sang một màn hình cân riêng rồi quay lại): người dùng
/// không rời khỏi form đang làm, số cân chảy thẳng vào ô đang chọn.
///
/// Ba trạng thái:
/// * Chưa nối → một dòng mảnh "Kết nối cân điện tử"; không cản việc nhập tay.
/// * Đang nối → dòng chờ có spinner.
/// * Đã nối  → số live cỡ lớn, badge ỔN ĐỊNH/ĐANG ĐỌC, nút Cân bì + Lấy số,
///   và (nếu bật) tự nhận số khi cân đứng yên đủ lâu.
class ScaleBar extends StatefulWidget {
  const ScaleBar({
    required this.onCapture,
    this.targetLabel,
    this.enabled = true,
    this.session,
    this.preferences,
    super.key,
  });

  /// Gọi khi có số cân được nhận (bấm "Lấy số" hoặc auto-capture).
  final void Function(WeightReading reading, bool automatic) onCapture;

  /// Tên ô đang nhận số — hiện trên thanh để người dùng biết số sẽ chảy vào đâu.
  final String? targetLabel;

  /// Tắt khi chưa chọn ô nhận (nút "Lấy số" mờ đi, auto-capture ngưng).
  final bool enabled;

  /// Cho phép test tiêm session giả.
  final ScaleSession? session;
  final ScalePreferences? preferences;

  @override
  State<ScaleBar> createState() => ScaleBarState();
}

/// Public để màn cha giữ [GlobalKey] và gọi [suppressCurrentReading] sau khi
/// người dùng bấm Hoàn tác.
class ScaleBarState extends State<ScaleBar> {
  ScaleSession get _session => widget.session ?? ScaleSession.instance;
  ScalePreferences get _prefs => widget.preferences ?? ScalePreferences.instance;

  final _autoCapture = ScaleAutoCapture();
  BleScaleService? _service;
  Timer? _ticker;
  bool _connecting = false;
  double _armProgress = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_prefs.load());
    _prefs.addListener(_onPrefsChanged);
    unawaited(_attach());
  }

  Future<void> _attach() async {
    // Thiếu Bluetooth / chạy trong môi trường không có plugin (widget test,
    // máy không hỗ trợ BLE) thì thanh cân chỉ đứng im ở dòng "Kết nối cân
    // điện tử" — không được làm hỏng form đang mở, vì nhập tay vẫn phải dùng
    // được bình thường.
    final BleScaleService service;
    try {
      service = await _session.ensureInitialized();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() => _service = service);
    service.addListener(_onScaleChanged);
    _syncTicker();
  }

  void _onPrefsChanged() {
    if (mounted) setState(() {});
  }

  /// Nhịp ngắn chỉ để vẽ vòng đếm ổn định + kích hoạt auto-capture đúng lúc,
  /// kể cả khi cân gửi mẫu thưa. CHỈ chạy khi đã nối cân — không có cân thì
  /// một timer lặp vô tận chỉ tốn pin (và treo `pumpAndSettle` trong test).
  void _syncTicker() {
    final connected = _service?.isConnected ?? false;
    if (connected && _ticker == null) {
      _ticker = Timer.periodic(const Duration(milliseconds: 120), (_) {
        if (!mounted) return;
        _evaluateAutoCapture();
      });
    } else if (!connected && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  void _onScaleChanged() {
    if (!mounted) return;
    _syncTicker();
    setState(() {});
  }

  void _evaluateAutoCapture() {
    final service = _service;
    if (service == null || !service.isConnected) return;

    final now = DateTime.now();
    if (!widget.enabled || !_prefs.autoCapture) {
      _autoCapture.reset();
      if (_armProgress != 0) setState(() => _armProgress = 0);
      return;
    }

    final reading = service.reading;
    final captured = _autoCapture.offer(reading, now);
    final progress = _autoCapture.progressAt(now);
    if (progress != _armProgress) setState(() => _armProgress = progress);

    if (captured != null && reading != null) {
      _emit(reading, automatic: true);
    }
  }

  void _emit(WeightReading reading, {required bool automatic}) {
    unawaited(HapticFeedback.mediumImpact());
    // Làm tròn LÊN 0,1 kg ngay tại nguồn: mọi màn dùng cân (mua lúa, đóng gói
    // xuất kho…) nhận cùng một con số, không màn nào phải tự nhớ quy tắc.
    widget.onCapture(
      reading.copyWith(
        weight: ceilKg(reading.weight),
        deviceName: _service?.connectedDevice?.platformName,
      ),
      automatic,
    );
  }

  /// Người dùng bấm Hoàn tác → không nhận lại ngay số đang đứng trên cân.
  void suppressCurrentReading() => _autoCapture.suppressCurrent();

  @override
  void dispose() {
    _ticker?.cancel();
    _prefs.removeListener(_onPrefsChanged);
    _service?.removeListener(_onScaleChanged);
    // Không dispose service — kết nối thuộc về ScaleSession, dùng chung cả app.
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() => _connecting = true);
    try {
      final devices = await _session.scanAndAutoConnect();
      if (!mounted) return;
      if (devices.length > 1) {
        await _pickDevice(devices);
      } else if (devices.isEmpty && !(_service?.isConnected ?? false)) {
        _snack('Không tìm thấy cân StockLite ở gần. Kiểm tra cân đã bật.');
      }
    } catch (error) {
      if (mounted) _snack('Không kết nối được cân: $error');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
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

  Future<void> _tare() async {
    try {
      await _service?.sendCommand('TARE');
      _autoCapture.reset();
      _snack('Đã cân bì.');
    } catch (error) {
      _snack('Không gửi được lệnh cân bì: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = _service;
    if (service == null || _connecting) {
      return _CompactRow(
        icon: Icons.bluetooth_searching_rounded,
        label: _connecting ? 'Đang tìm cân điện tử…' : 'Kết nối cân điện tử',
        busy: _connecting,
        onTap: _connecting ? null : _connect,
      );
    }
    if (!service.isConnected) {
      return _CompactRow(
        icon: Icons.bluetooth_searching_rounded,
        label: 'Kết nối cân điện tử',
        hint: 'Hoặc cứ nhập tay như bình thường',
        onTap: _connect,
      );
    }
    return _connectedBar(service);
  }

  Widget _connectedBar(BleScaleService service) {
    final reading = service.reading;
    final stable = reading?.isStable ?? false;
    final weight = reading?.weight ?? 0;
    final canTake = widget.enabled && stable && weight > 0;
    final autoOn = _prefs.autoCapture;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.targetLabel == null
                      ? 'CÂN ĐIỆN TỬ'
                      : 'CÂN VÀO: ${widget.targetLabel!.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              _StatusPill(stable: stable),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_armProgress > 0 && _armProgress < 1) ...[
                SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    value: _armProgress,
                    strokeWidth: 2.5,
                    color: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        // Hiện đúng con số sẽ được ghi vào phiếu (đã làm tròn
                        // lên 0,1 kg), tránh cảnh trên thanh một số, vào ô một
                        // số khác.
                        text: reading == null
                            ? '---'
                            : formatNumber(ceilKg(reading.weight), digits: 1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      TextSpan(
                        text: ' ${reading?.unit ?? 'kg'}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _BarButton(
                icon: Icons.exposure_zero_rounded,
                label: 'Cân bì',
                onTap: _tare,
              ),
              const SizedBox(width: 8),
              _BarButton(
                icon: Icons.download_rounded,
                label: 'Lấy số',
                filled: true,
                onTap: canTake ? () => _emit(reading!, automatic: false) : null,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  !widget.enabled
                      ? 'Chọn ô cần cân ở dưới rồi đặt hàng lên cân.'
                      : autoOn
                          ? 'Đặt hàng lên cân, số ổn định sẽ tự điền (làm tròn lên 0,1 kg).'
                          : 'Số ổn định thì bấm "Lấy số" (làm tròn lên 0,1 kg).',
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
              ),
              Text(
                'Tự nhận',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(
                height: 28,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch(
                    value: autoOn,
                    activeColor: Colors.white,
                    activeTrackColor: AppColors.primarySoft,
                    onChanged: (value) {
                      _autoCapture.reset();
                      unawaited(_prefs.setAutoCapture(value));
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({
    required this.icon,
    required this.label,
    this.hint,
    this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final String? hint;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandTintFor(context),
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(icon, size: 20, color: AppColors.primaryDark),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    if (hint != null)
                      Text(
                        hint!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (!busy)
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.primaryDark),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.stable});

  final bool stable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: stable ? AppColors.primarySoft : Colors.white24,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        stable ? 'ỔN ĐỊNH' : 'ĐANG ĐỌC',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final background = filled
        ? (disabled ? Colors.white24 : Colors.white)
        : Colors.white.withValues(alpha: 0.12);
    final foreground = filled
        ? (disabled ? Colors.white54 : AppColors.forest)
        : (disabled ? Colors.white38 : Colors.white);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/api/api_client.dart';
import '../../../products/presentation/screens/product_detail_screen.dart';
import '../../data/qr_repository.dart';
import '../../models/resolved_qr.dart';
import '../../models/scan_result_info.dart';
import '../widgets/scan_action_panel.dart';
import '../widgets/scan_bottom_bar.dart';
import '../widgets/scan_camera_preview.dart';
import '../widgets/scan_header.dart';

enum ScanState { scanning, resolving, success, invalid, offline }

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({
    this.repository,
    this.operation = 'LOOKUP',
    this.referenceId,
    this.warehouseId,
    super.key,
  });

  final QrRepository? repository;
  final String operation;
  final int? referenceId;
  final int? warehouseId;

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  late final QrRepository _repository;
  ScanState _state = ScanState.scanning;
  ScanResultInfo? _lastScan;
  ResolvedQr? _resolved;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiQrRepository();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_state != ScanState.scanning) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;
    final scan = ScanResultInfo.fromBarcode(barcode);
    if (scan.rawValue.isEmpty || scan.rawValue == _lastScan?.rawValue) return;

    setState(() {
      _lastScan = scan;
      _state = ScanState.resolving;
      _errorMessage = null;
    });
    await _controller.stop();
    try {
      final result = await _repository.resolve(
        scan.rawValue,
        operation: widget.operation,
        referenceId: widget.referenceId,
        warehouseId: widget.warehouseId,
      );
      if (!mounted) return;
      setState(() {
        _resolved = result;
        _state = ScanState.success;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _state = error.isTransient ? ScanState.offline : ScanState.invalid;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể tra cứu mã QR. Vui lòng thử lại.';
        _state = ScanState.invalid;
      });
    }
  }

  Future<void> _resumeScanning() async {
    setState(() {
      _state = ScanState.scanning;
      _lastScan = null;
      _resolved = null;
      _errorMessage = null;
    });
    await _controller.start();
  }

  Widget _buildBody() {
    switch (_state) {
      case ScanState.scanning:
        return Column(
          children: [
            Expanded(
              child: ScanCameraPreview(
                controller: _controller,
                onDetect: _handleDetect,
                result: _lastScan,
              ),
            ),
            ScanActionPanel(
              result: _lastScan,
              onScanAgain: _resumeScanning,
              onSwitchCamera: _controller.switchCamera,
            ),
          ],
        );
      case ScanState.resolving:
        return const _MessageState(
          icon: Icons.qr_code_scanner,
          color: Color(0xFF10B981),
          title: 'Đang kiểm tra mã QR',
          message: 'Đang đối chiếu mã với dữ liệu StockLite...',
          loading: true,
        );
      case ScanState.success:
        return _SuccessState(result: _resolved!, onScanAgain: _resumeScanning);
      case ScanState.invalid:
        return _MessageState(
          icon: Icons.error_outline,
          color: const Color(0xFFEF4444),
          title: 'Mã QR không hợp lệ',
          message: _errorMessage ?? 'Không tìm thấy mã trong hệ thống.',
          actionLabel: 'Quét lại',
          onAction: _resumeScanning,
        );
      case ScanState.offline:
        return _MessageState(
          icon: Icons.wifi_off,
          color: const Color(0xFFF59E0B),
          title: 'Không thể kết nối API',
          message: _errorMessage ?? 'Vui lòng kiểm tra kết nối mạng.',
          actionLabel: 'Thử lại',
          onAction: _resumeScanning,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            ScanHeader(onToggleTorch: _controller.toggleTorch),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: const ScanBottomBar(),
    );
  }
}

class _SuccessState extends StatelessWidget {
  const _SuccessState({required this.result, required this.onScanAgain});

  final ResolvedQr result;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final details = <(String, String)>[
      ('Mã', result.displayCode),
      if (result.sku != null) ('SKU', result.sku!),
      if (result.productName != null) ('Sản phẩm', result.productName!),
      if (result.statusName != null) ('Trạng thái', result.statusName!),
      if (result.remainingWeightKg != null)
        ('Khối lượng còn lại', '${result.remainingWeightKg} kg'),
      if (result.slotCode != null) ('Vị trí', result.slotCode!),
      if (result.warehouseName != null) ('Kho', result.warehouseName!),
      if (result.isQuarantined == true) ('Cách ly', 'Có'),
    ];
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline,
              color: Color(0xFF10B981), size: 72),
          const SizedBox(height: 12),
          const Text('Quét thành công!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(result.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFCBD5E1))),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                for (var index = 0; index < details.length; index++) ...[
                  _DetailRow(
                      label: details[index].$1, value: details[index].$2),
                  if (index != details.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          const Spacer(),
          if (result.productVariantId != null)
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProductDetailScreen(
                    productVariantId: result.productVariantId,
                  ),
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Xem thông tin sản phẩm'),
            ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onScanAgain,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Quét mã khác'),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            CircularProgressIndicator(color: color)
          else
            Icon(icon, color: color, size: 72),
          const SizedBox(height: 18),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFCBD5E1), height: 1.4)),
          if (actionLabel != null) ...[
            const SizedBox(height: 28),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        ),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

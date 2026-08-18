import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/api/api_client.dart';
import '../../../products/presentation/screens/product_detail_screen.dart';
import '../../../paddy_lots/presentation/screens/paddy_lot_detail_screen.dart';
import '../../data/qr_repository.dart';
import '../../models/resolved_qr.dart';
import '../../models/scan_result_info.dart';
import '../widgets/scan_action_panel.dart';
import '../widgets/scan_camera_preview.dart';
import '../widgets/scan_header.dart';

enum ScanState { scanning, resolving, success, invalid, offline }

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({
    this.repository,
    this.operation = 'LOOKUP',
    this.referenceId,
    this.warehouseId,
    this.autoOpenLot = false,
    this.imagePicker,
    super.key,
  });

  final QrRepository? repository;
  final String operation;
  final int? referenceId;
  final int? warehouseId;

  /// true khi mở từ màn "Lô & truy vết": quét ra lô là đi thẳng vào chi tiết
  /// lô, không bắt người dùng bấm thêm một nút nữa.
  final bool autoOpenLot;

  /// Cho phép test tiêm picker giả.
  final ImagePicker? imagePicker;

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  late final QrRepository _repository;
  late final ImagePicker _imagePicker;
  ScanState _state = ScanState.scanning;
  ScanResultInfo? _lastScan;
  ResolvedQr? _resolved;
  String? _errorMessage;
  bool _pickingImage = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiQrRepository();
    _imagePicker = widget.imagePicker ?? ImagePicker();
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
    await _resolveScan(scan);
  }

  /// Quét mã QR từ một ảnh có sẵn trong máy.
  ///
  /// Thực tế trong kho: bao đã xếp chồng, người ta chụp lại tem lô rồi tra cứu
  /// sau; hoặc mã được gửi qua Zalo. Khi đó không thể chĩa camera vào tem nữa.
  ///
  /// Vì sao trước đây "quét thì được mà chọn ảnh thì báo không đọc được":
  /// * `pickImage(imageQuality: 100)` bắt image_picker GIẢI MÃ RỒI NÉN LẠI ảnh.
  ///   Bản sao đó mất nét ở cạnh ô vuông QR, và với ảnh chụp bằng camera điện
  ///   thoại (nhiều chục megapixel) thao tác này còn dễ hụt bộ nhớ.
  /// * ML Kit đọc thẳng file gốc: ảnh 108MP nạp vào là một bitmap khổng lồ,
  ///   thường trả về "không thấy mã" thay vì báo lỗi.
  /// Nay lấy ảnh GỐC, thử đọc một lượt; không thấy mã thì thu nhỏ về chiều dài
  /// tối đa 2048 px (kích thước ML Kit làm việc tốt) rồi thử lại.
  Future<void> _pickImageAndScan() async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);

    Directory? tempDir;
    try {
      // Tắt camera trước khi phân tích ảnh: CameraX vẫn chạy trong lúc ML Kit
      // giải một bitmap ảnh chụp cỡ lớn là công thức để hụt bộ nhớ — và khi
      // hụt, plugin trả về "không thấy mã" chứ không báo lỗi.
      await _controller.stop();

      // KHÔNG đặt imageQuality/maxWidth — mọi tham số đó đều khiến
      // image_picker nén lại ảnh trước khi trả về.
      final file = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) return;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _failImage('Ảnh rỗng hoặc không đọc được. Hãy chọn ảnh khác.');
        return;
      }

      final first = await _analyze(file.path);
      var barcode = first.$1;
      var failure = first.$2;

      if (barcode == null) {
        // Lượt 2: thu nhỏ + chuẩn hoá về PNG (không mất nét do nén JPEG).
        final resized = await _downscale(bytes, 2048);
        if (resized != null) {
          tempDir = await Directory.systemTemp.createTemp('qr_scan');
          final temp = File('${tempDir.path}/qr.png');
          await temp.writeAsBytes(resized, flush: true);
          final second = await _analyze(temp.path);
          barcode = second.$1;
          failure = second.$2 ?? failure;
        }
      }
      if (!mounted) return;

      if (barcode == null || (barcode.rawValue ?? '').isEmpty) {
        // Phân biệt "ảnh không có mã" với "máy đọc ảnh lỗi" — trước đây gộp
        // làm một nên không lần ra được nguyên nhân.
        _failImage(
          failure == null
              ? 'Không tìm thấy mã QR trong ảnh. Hãy chọn ảnh rõ nét, thấy '
                  'trọn khung mã và ít bị nghiêng.'
              : 'Không đọc được mã từ ảnh: $failure',
        );
        return;
      }

      // Ảnh cũ có thể trùng mã vừa quét — bỏ chốt chống trùng để vẫn tra lại.
      _lastScan = null;
      await _resolveScan(ScanResultInfo.fromBarcode(barcode));
    } catch (error) {
      if (!mounted) return;
      // Giữ nguyên lời của lỗi gốc: "không đọc được ảnh" chung chung khiến
      // không phân biệt được ảnh xấu với lỗi thiết bị/quyền.
      _failImage('Không đọc được ảnh đã chọn: $error');
    } finally {
      // Dọn file tạm; hỏng cũng không sao vì nằm trong thư mục tạm của app.
      if (tempDir != null) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _pickingImage = false);
        // Người dùng bấm Huỷ trong thư viện (hoặc ảnh đọc xong mà vẫn ở chế độ
        // quét) → bật lại camera, không để khung xem trống.
        if (_state == ScanState.scanning) {
          await _controller.start();
        }
      }
    }
  }

  void _failImage(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _state = ScanState.invalid;
    });
  }

  /// Một lượt đọc mã từ file ảnh.
  ///
  /// Trả `(mã, null)` khi đọc được, `(null, null)` khi ảnh không có mã, và
  /// `(null, lỗi)` khi nền tảng báo lỗi. Không ném ra ngoài để lượt thử với
  /// ảnh đã thu nhỏ vẫn chạy tiếp.
  Future<(Barcode?, Object?)> _analyze(String path) async {
    try {
      final capture = await _controller.analyzeImage(path);
      for (final barcode in capture?.barcodes ?? const <Barcode>[]) {
        if ((barcode.rawValue ?? '').isNotEmpty) return (barcode, null);
      }
      return (null, null);
    } on UnsupportedError catch (error) {
      // iOS Simulator không đọc được ảnh — phải nói rõ, đừng đổ tại ảnh xấu.
      return (null, error.message ?? 'thiết bị không hỗ trợ đọc mã từ ảnh');
    } catch (error) {
      return (null, error);
    }
  }

  /// Thu nhỏ ảnh về cạnh dài tối đa [maxSide] px và trả PNG.
  /// Trả null nếu ảnh vốn đã nhỏ (khỏi thử lại y hệt lượt đầu).
  Future<Uint8List?> _downscale(Uint8List bytes, int maxSide) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final longest = descriptor.width > descriptor.height
          ? descriptor.width
          : descriptor.height;
      if (longest <= maxSide) return null;

      final scale = maxSide / longest;
      codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * scale).round(),
        targetHeight: (descriptor.height * scale).round(),
      );
      final frame = await codec.getNextFrame();
      image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    } finally {
      // Ảnh gốc rất nặng — không giải phóng là app phình bộ nhớ sau vài lần
      // chọn ảnh, đúng lúc ML Kit cũng đang cần bộ nhớ.
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  /// Gọi API resolve và chuyển trạng thái màn hình. Dùng chung cho cả hai
  /// nguồn mã: camera và ảnh trong máy.
  Future<void> _resolveScan(ScanResultInfo scan) async {
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
      if (widget.autoOpenLot && result.isPaddyLot && result.entityId > 0) {
        await _openLot(result.entityId);
      }
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

  /// Mở chi tiết lô rồi quay lại trạng thái quét để tra mã kế tiếp.
  Future<void> _openLot(int lotId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PaddyLotDetailScreen(lotId: lotId),
      ),
    );
    if (mounted) await _resumeScanning();
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
              onPickImage: _pickImageAndScan,
              pickingImage: _pickingImage,
            ),
          ],
        );
      case ScanState.resolving:
        return const _MessageState(
          icon: Icons.qr_code_scanner,
          color: Color(0xFF16A34A),
          title: 'Đang kiểm tra mã QR',
          message: 'Đang đối chiếu mã với dữ liệu StockLite...',
          loading: true,
        );
      case ScanState.success:
        return _SuccessState(
          result: _resolved!,
          onScanAgain: _resumeScanning,
          onOpenLot: _openLot,
        );
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
    );
  }
}

class _SuccessState extends StatelessWidget {
  const _SuccessState({
    required this.result,
    required this.onScanAgain,
    required this.onOpenLot,
  });

  final ResolvedQr result;
  final VoidCallback onScanAgain;
  final Future<void> Function(int lotId) onOpenLot;

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
              color: Color(0xFF16A34A), size: 72),
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
          if (result.isPaddyLot && result.entityId > 0) ...[
            FilledButton.icon(
              key: const ValueKey('open_paddy_lot_detail'),
              onPressed: () => onOpenLot(result.entityId),
              icon: const Icon(Icons.account_tree_outlined),
              label: const Text('Xem chi tiết lô'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 10),
          ],
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
                backgroundColor: const Color(0xFF16A34A),
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

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/realtime/realtime_reload_mixin.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../scale/models/weight_reading.dart';
import '../../../scale/presentation/widgets/scale_bar.dart';
import '../../data/stock_take_repository.dart';
import '../../models/stock_take.dart';

/// Màn kiểm đếm một phiếu kiểm kê — đơn vị là BAO.
///
/// Ba việc phải làm cùng lúc cho kho gạo:
/// * **Đếm bao**: quét QR từng bao (hoặc tích tay khi tem rách) → biết chính
///   xác bao nào thiếu, không chỉ biết "thiếu bao nhiêu kg".
/// * **Cân**: đặt bao lên cân BLE là số chảy thẳng vào bao đang chọn. Bao không
///   cân thì giữ nguyên kg sổ sách — không quy về 0, không chia đều chênh lệch.
/// * **Chất lượng**: ghi tình trạng từng bao/dòng; không đạt sẽ sinh cảnh báo
///   và đề nghị kiểm định lại khi phiếu được duyệt.
class StockTakeDetailScreen extends StatefulWidget {
  const StockTakeDetailScreen({
    required this.stockTakeId,
    this.repository,
    super.key,
  });

  final int stockTakeId;
  final StockTakeRepository? repository;

  @override
  State<StockTakeDetailScreen> createState() => _StockTakeDetailScreenState();
}

class _StockTakeDetailScreenState extends State<StockTakeDetailScreen>
    with RealtimeReloadMixin {
  @override
  Set<String> get realtimeEntities => const {
        'StockTake',
        'StockTakeItem',
        'StockTakeStatus',
      };

  /// Màn này giữ số đếm CHƯA LƯU của người dùng, nên không tự ghi đè:
  /// - Phiếu đã khoá (không còn sửa được) → tải lại im lặng.
  /// - Phiếu đang kiểm đếm → chỉ báo có thay đổi, để người dùng chủ động tải lại
  ///   sau khi lưu, tránh mất công đếm dở.
  @override
  void onRealtimeChanged() {
    if (_detail == null || !_canEdit) {
      _load(showLoading: false);
      return;
    }
    if (!_remoteChanged) setState(() => _remoteChanged = true);
  }

  /// Có thay đổi từ nơi khác nhưng chưa áp vào màn (xem [onRealtimeChanged]).
  bool _remoteChanged = false;

  late final StockTakeRepository _repository;
  final GlobalKey<ScaleBarState> _scaleBarKey = GlobalKey<ScaleBarState>();

  StockTakeDetail? _detail;
  Object? _error;
  bool _loading = true;
  bool _busy = false;

  /// Dòng và bao đang nhận số cân kế tiếp.
  int _lineIndex = 0;
  int? _targetBagId;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiStockTakeRepository();
    _load(showLoading: false);
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final detail = await _repository.getDetail(widget.stockTakeId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _error = null;
        _loading = false;
        _remoteChanged = false;
        if (_lineIndex >= detail.lines.length) _lineIndex = 0;
        _targetBagId = _firstUncountedBagId();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  StockTakeLine? get _line {
    final lines = _detail?.lines ?? const <StockTakeLine>[];
    if (lines.isEmpty) return null;
    return lines[_lineIndex.clamp(0, lines.length - 1)];
  }

  int? _firstUncountedBagId() {
    final line = _line;
    if (line == null) return null;
    for (final bag in line.bags) {
      if (!bag.counted) return bag.id;
    }
    return line.bags.isEmpty ? null : line.bags.last.id;
  }

  StockTakeBag? get _targetBag {
    final line = _line;
    if (line == null) return null;
    for (final bag in line.bags) {
      if (bag.id == _targetBagId) return bag;
    }
    return null;
  }

  bool get _canEdit => _detail?.isDraft ?? false;

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : null,
      ));
  }

  // ── Kiểm đếm ───────────────────────────────────────────────────────
  void _toggleBag(StockTakeBag bag, bool counted) {
    setState(() {
      bag.counted = counted;
      // Bỏ tích thì xoá luôn số cân: giữ lại sẽ cộng vào tổng của một bao vừa
      // được tuyên bố là không tìm thấy.
      if (!counted) bag.countedWeightKg = null;
      if (counted) _targetBagId = bag.id;
    });
  }

  void _onScaleCapture(WeightReading reading, bool automatic) {
    if (!_canEdit) return;
    final bag = _targetBag;
    if (bag == null) {
      _snack('Chọn bao cần cân trước đã.', error: true);
      return;
    }
    setState(() {
      bag.countedWeightKg = ceilKg(reading.weight);
      bag.counted = true;
    });

    if (!automatic) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 4),
        content: Text('Bao #${bag.bagNo}: ${formatNumber(bag.countedWeightKg, digits: 1)} kg'),
        action: SnackBarAction(
          label: 'Hoàn tác',
          onPressed: () {
            setState(() => bag.countedWeightKg = null);
            _scaleBarKey.currentState?.suppressCurrentReading();
          },
        ),
      ));
    // Cân xong bao này thì nhảy sang bao chưa đếm kế tiếp để cân liên tục.
    setState(() => _targetBagId = _firstUncountedBagId() ?? bag.id);
  }

  /// Quét QR tem bao. Backend tra xem bao có thuộc phiếu không.
  Future<void> _scanBag() async {
    if (!_canEdit) return;
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const _BagScannerScreen()),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await _repository.scanBag(widget.stockTakeId, code);
      if (!mounted) return;
      if (!result.matched) {
        _snack(result.message, error: true);
        return;
      }

      final target = _findBag(result.bagId);
      if (target == null) {
        _snack('Bao thuộc phiếu nhưng không có trong danh sách đang mở. Tải lại phiếu.', error: true);
        return;
      }
      setState(() {
        _lineIndex = target.$1;
        _targetBagId = target.$2.id;
        target.$2.counted = true;
        target.$2.scannedByQr = true;
      });
      _snack(result.alreadyCounted
          ? 'Bao #${target.$2.bagNo} đã đếm trước đó.'
          : 'Đã đếm bao #${target.$2.bagNo}. Đặt lên cân nếu cần cân lại.');
    } catch (error) {
      if (mounted) _snack('$error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  (int, StockTakeBag)? _findBag(int? bagId) {
    if (bagId == null) return null;
    final lines = _detail?.lines ?? const <StockTakeLine>[];
    for (var i = 0; i < lines.length; i++) {
      for (final bag in lines[i].bags) {
        if (bag.id == bagId) return (i, bag);
      }
    }
    return null;
  }

  // ── Lưu / gửi duyệt ────────────────────────────────────────────────
  Future<bool> _save({bool silent = false}) async {
    final detail = _detail;
    if (detail == null) return false;

    final missingQuality = detail.lines.where(
        (l) => l.quality.isFailed && (l.qualityNote ?? '').trim().isEmpty);
    if (missingQuality.isNotEmpty) {
      _snack('Dòng ${missingQuality.first.title}: chất lượng không đạt phải ghi rõ tình trạng.',
          error: true);
      return false;
    }

    setState(() => _busy = true);
    try {
      await _repository.saveCounts(detail.id, detail.lines, note: detail.note);
      if (!silent) _snack('Đã lưu kết quả kiểm đếm.');
      return true;
    } catch (error) {
      if (mounted) _snack('$error', error: true);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final detail = _detail;
    if (detail == null) return;

    final untouched = detail.lines.where((l) => !l.touched).toList();
    if (untouched.isNotEmpty) {
      _snack('Còn ${untouched.length} dòng chưa kiểm đếm bao nào.', error: true);
      return;
    }
    final needReason = detail.lines.where(
        (l) => l.bagDifference != 0 && (l.note ?? '').trim().isEmpty);
    if (needReason.isNotEmpty) {
      _snack('Dòng ${needReason.first.title} lệch bao — bắt buộc nhập lý do.', error: true);
      return;
    }
    final needRecount =
        detail.lines.where((l) => l.bagDifference != 0 && !l.recountConfirmed);
    if (needRecount.isNotEmpty) {
      _snack('Dòng ${needRecount.first.title} lệch bao — phải xác nhận đã đếm lại.',
          error: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gửi phiếu để duyệt?'),
        content: Text(
          'Đã đếm ${detail.countedBags}/${detail.totalBags} bao'
          '${detail.missingBags > 0 ? ', thiếu ${detail.missingBags} bao' : ''}.'
          '${detail.hasQualityIssue ? '\nCó dòng ghi nhận chất lượng không đạt.' : ''}'
          '\nSau khi gửi, số liệu sẽ bị khoá.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Gửi duyệt')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (!await _save(silent: true)) return;

    setState(() => _busy = true);
    try {
      await _repository.submit(detail.id, note: detail.note);
      if (!mounted) return;
      _snack('Đã gửi phiếu để duyệt.');
      await _load(showLoading: false);
    } catch (error) {
      if (mounted) _snack('$error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        child: Column(
          children: [
            AppGradientHeader(
              title: detail?.code ?? 'Phiếu kiểm kê',
              subtitle: detail == null
                  ? 'Đang tải…'
                  : '${detail.warehouseName} · đã đếm '
                      '${detail.countedBags}/${detail.totalBags} bao',
              leading: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                color: Colors.white,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            Expanded(child: _body()),
            if (detail != null && detail.isDraft) _bottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _detail == null) return const ListSkeleton();
    if (_error != null && _detail == null) {
      return HErrorState(message: 'Không tải được phiếu: $_error', onRetry: _load);
    }
    final detail = _detail!;
    if (detail.lines.isEmpty) {
      return const HEmptyState(
        title: 'Phiếu không có dòng nào',
        description: 'Phạm vi đã chọn không có tồn kho để kiểm.',
        icon: Icons.inventory_2_outlined,
      );
    }

    final line = _line!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        if (!detail.isDraft)
          AppInfoBanner(
            tone: AppTone.info,
            icon: Icons.lock_outline_rounded,
            message: 'Phiếu đã ${detail.statusName.toLowerCase()} — số liệu được khoá.',
          ),
        // Có người sửa phiếu ở nơi khác. Không tự ghi đè vì số đếm đang dở có
        // thể chưa lưu — để người dùng tự chọn thời điểm tải lại.
        if (_remoteChanged) ...[
          AppInfoBanner(
            tone: AppTone.warning,
            icon: Icons.sync_problem_outlined,
            message: 'Phiếu vừa được cập nhật ở nơi khác. '
                'Lưu kết quả đang đếm rồi bấm để tải lại.',
            onTap: _busy ? null : () => _load(showLoading: false),
          ),
          const SizedBox(height: 10),
        ],
        _lineSelector(detail),
        const SizedBox(height: 12),
        if (_canEdit) ...[
          ScaleBar(
            key: _scaleBarKey,
            enabled: _targetBag != null,
            targetLabel: _targetBag == null ? null : 'bao ${_targetBag!.bagNo}',
            onCapture: _onScaleCapture,
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _busy ? null : _scanBag,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Quét QR bao'),
          ),
          const SizedBox(height: 12),
        ],
        _lineSummary(line),
        const SizedBox(height: 12),
        if (line.hasBags)
          ..._bagCards(line)
        else
          _manualKgCard(line),
        const SizedBox(height: 12),
        _qualityCard(line),
        const SizedBox(height: 12),
        _reasonCard(line),
      ],
    );
  }

  Widget _lineSelector(StockTakeDetail detail) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: detail.lines.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final line = detail.lines[index];
          final selected = index == _lineIndex;
          final done = line.touched;
          return ChoiceChip(
            selected: selected,
            label: Text(
              '${line.title}${line.hasBags ? ' (${line.countedBags}/${line.systemBagCount})' : ''}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            avatar: done
                ? const Icon(Icons.check_circle, size: 16, color: AppColors.primary)
                : null,
            onSelected: (_) => setState(() {
              _lineIndex = index;
              _targetBagId = _firstUncountedBagId();
            }),
          );
        },
      ),
    );
  }

  Widget _lineSummary(StockTakeLine line) {
    final diffKg = line.effectiveActualKg - line.systemQuantity;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(line.productVariantName ?? line.title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          Text(
            'Lô ${line.lotCode ?? '—'} · ${line.locationLabel}',
            style:
                TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppStatTile(
                  label: 'Bao',
                  value: '${line.countedBags}/${line.systemBagCount}',
                  tone: line.bagDifference == 0 ? AppTone.brand : AppTone.danger,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppStatTile(
                  label: 'Sổ sách',
                  value: formatKg(line.systemQuantity, digits: 1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppStatTile(
                  label: 'Lệch',
                  value: '${diffKg >= 0 ? '+' : ''}${formatKg(diffKg, digits: 1)}',
                  tone: diffKg.abs() < 0.05 ? AppTone.neutral : AppTone.warning,
                ),
              ),
            ],
          ),
          if (line.bagDifference != 0) ...[
            const SizedBox(height: 8),
            AppInfoBanner(
              tone: AppTone.danger,
              icon: Icons.error_outline_rounded,
              message: line.bagDifference < 0
                  ? 'Thiếu ${-line.bagDifference} bao — bắt buộc nhập lý do và xác nhận đếm lại.'
                  : 'Thừa ${line.bagDifference} bao so với sổ sách.',
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _bagCards(StockTakeLine line) {
    return [
      Row(
        children: [
          const Expanded(
            child: Text('Danh sách bao',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
          if (_canEdit)
            TextButton(
              onPressed: () => setState(() {
                for (final bag in line.bags) {
                  bag.counted = true;
                }
              }),
              child: const Text('Tích tất cả'),
            ),
        ],
      ),
      for (final bag in line.bags)
        AppCard(
          margin: const EdgeInsets.only(bottom: 8),
          color: bag.id == _targetBagId ? AppColors.brandTintFor(context) : null,
          onTap: _canEdit ? () => setState(() => _targetBagId = bag.id) : null,
          child: Row(
            children: [
              Checkbox(
                value: bag.counted,
                onChanged: _canEdit ? (v) => _toggleBag(bag, v ?? false) : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Bao #${bag.bagNo}',
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                        if (bag.scannedByQr) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.qr_code_2_rounded,
                              size: 14, color: AppColors.primary),
                        ],
                        if (bag.isUnexpected) ...[
                          const SizedBox(width: 6),
                          const Text('ngoài danh sách',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.warning)),
                        ],
                      ],
                    ),
                    Text(
                      bag.countedWeightKg == null
                          ? 'Sổ sách ${formatKg(bag.systemWeightKg, digits: 1)} · chưa cân'
                          : 'Cân ${formatKg(bag.countedWeightKg, digits: 1)} '
                              '(sổ sách ${formatKg(bag.systemWeightKg, digits: 1)})',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondaryFor(context)),
                    ),
                  ],
                ),
              ),
              if (!bag.counted)
                const Text('Không thấy',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.danger)),
            ],
          ),
        ),
    ];
  }

  /// Dòng không quản lý theo bao (hàng không theo lô) — vẫn nhập kg như cũ.
  Widget _manualKgCard(StockTakeLine line) {
    return AppCard(
      child: TextFormField(
        initialValue: line.actualQuantity == null
            ? ''
            : formatQuantityInput(line.actualQuantity, digits: 1),
        enabled: _canEdit,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Khối lượng đếm được (kg)',
          suffixText: 'kg',
          helperText: 'Dòng này không quản lý theo bao',
        ),
        onChanged: (value) =>
            setState(() => line.actualQuantity = parseDecimal(value)),
      ),
    );
  }

  Widget _qualityCard(StockTakeLine line) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chất lượng', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final quality in StockTakeQuality.values)
                ChoiceChip(
                  selected: line.quality == quality,
                  label: Text(quality.label, style: const TextStyle(fontSize: 12)),
                  onSelected:
                      _canEdit ? (_) => setState(() => line.quality = quality) : null,
                ),
            ],
          ),
          if (line.quality.isFailed) ...[
            const SizedBox(height: 10),
            TextFormField(
              initialValue: line.qualityNote,
              enabled: _canEdit,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Mô tả tình trạng *',
                hintText: 'Ví dụ: 3 bao đáy cột bị ẩm, có mùi mốc',
              ),
              onChanged: (value) => line.qualityNote = value,
            ),
          ],
        ],
      ),
    );
  }

  Widget _reasonCard(StockTakeLine line) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            initialValue: line.note,
            enabled: _canEdit,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Lý do chênh lệch',
              hintText: 'Bắt buộc khi lệch bao hoặc lệch nhiều kg',
            ),
            onChanged: (value) => line.note = value,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: line.recountConfirmed,
            onChanged: _canEdit
                ? (value) => setState(() => line.recountConfirmed = value ?? false)
                : null,
            title: const Text('Đã đếm lại lần hai',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _bottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        border: Border(top: BorderSide(color: AppColors.borderFor(context))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : () => _save(),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46)),
              child: const Text('Lưu nháp'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(46),
              ),
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Gửi duyệt'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Máy quét QR tem bao — trả về chuỗi mã cho màn kiểm kê tra tiếp.
class _BagScannerScreen extends StatefulWidget {
  const _BagScannerScreen();

  @override
  State<_BagScannerScreen> createState() => _BagScannerScreenState();
}

class _BagScannerScreenState extends State<_BagScannerScreen> {
  final MobileScannerController _controller =
      MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim() ?? '';
      if (value.isEmpty) continue;
      _handled = true;
      Navigator.of(context).pop(value);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Quét tem bao'),
        actions: [
          IconButton(
            onPressed: _controller.toggleTorch,
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Đưa camera vào tem QR dán trên bao',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

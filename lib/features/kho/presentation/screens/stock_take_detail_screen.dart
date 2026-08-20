import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_reload_mixin.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../auth/data/auth_session_store.dart';
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
        'StockTakeItemBag',
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

  /// Bao đang nhận số cân kế tiếp.
  int? _targetBagId;

  /// Kết luận cho CẢ CỘT: lý do lệch và chỉnh lý nhập một lần rồi áp cho mọi lô
  /// trong cột — bắt thủ kho gõ lại theo từng lô là thừa vì họ chỉ kiểm một cột.
  String _varianceReason = '';
  int? _adjustedBagCount;
  double? _adjustedWeightKg;
  bool _recountConfirmed = false;

  /// Gợi ý vị trí đích theo từng bao (backend chấm điểm, người dùng chọn lại được).
  final Map<int, List<BagTargetSuggestion>> _bagTargets = {};
  final Set<int> _loadingTargets = {};

  /// Ô nhập kg của từng bao. Phải dùng controller chứ không dùng initialValue:
  /// cân BLE ghi số vào ô đang mở, mà initialValue chỉ có tác dụng ở lần dựng
  /// đầu tiên — đổi key để ép dựng lại thì con trỏ nhảy mỗi khi gõ.
  final Map<int, TextEditingController> _kgControllers = {};

  TextEditingController _kgController(StockTakeBag bag) {
    final existing = _kgControllers[bag.id];
    if (existing != null) return existing;
    final created = TextEditingController(
      text: bag.countedWeightKg == null
          ? ''
          : formatQuantityInput(bag.countedWeightKg, digits: 1),
    );
    _kgControllers[bag.id] = created;
    return created;
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiStockTakeRepository();
    _load(showLoading: false);
  }

  @override
  void dispose() {
    for (final controller in _kgControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final detail = await _repository.getDetail(widget.stockTakeId);
      if (!mounted) return;
      for (final controller in _kgControllers.values) {
        controller.dispose();
      }
      _kgControllers.clear();
      setState(() {
        _detail = detail;
        _error = null;
        _loading = false;
        _remoteChanged = false;
        _targetBagId = _firstUncountedBagId();
        _varianceReason = '';
        _adjustedBagCount = null;
        _adjustedWeightKg = null;
        for (final line in detail.lines) {
          if (_varianceReason.isEmpty && (line.varianceReason ?? '').trim().isNotEmpty) {
            _varianceReason = line.varianceReason!.trim();
          }
          _adjustedBagCount ??= line.adjustedBagCount;
          _adjustedWeightKg ??= line.adjustedWeightKg;
        }
        _recountConfirmed = detail.lines.any((x) => x.recountConfirmed);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  /// Toàn bộ bao của CỘT, xếp theo thứ tự phải dỡ từ trên xuống.
  ///
  /// Phiếu vẫn chia dòng theo lô ở backend (tồn kho quản lý theo lô), nhưng thủ
  /// kho đứng trước cột chỉ thấy một chồng bao — tách theo lô trên màn hình chỉ
  /// làm họ phải nhảy qua lại giữa các tab mà không giúp đếm nhanh hơn.
  List<StockTakeBag> get _allBags {
    final bags = [
      for (final line in _detail?.lines ?? const <StockTakeLine>[]) ...line.bags,
    ];
    bags.sort((a, b) {
      final byPick = a.pickSequence.compareTo(b.pickSequence);
      return byPick != 0 ? byPick : a.bagNo.compareTo(b.bagNo);
    });
    return bags;
  }

  /// Dòng dữ liệu cũ chưa quản lý theo bao — vẫn cho nhập tổng kg tay.
  List<StockTakeLine> get _legacyLines =>
      (_detail?.lines ?? const <StockTakeLine>[]).where((x) => !x.hasBags).toList();

  int? _firstUncountedBagId() {
    final bags = _allBags;
    for (final bag in bags) {
      if (!bag.counted) return bag.id;
    }
    return bags.isEmpty ? null : bags.last.id;
  }

  StockTakeBag? get _targetBag {
    for (final bag in _allBags) {
      if (bag.id == _targetBagId) return bag;
    }
    return null;
  }

  bool get _canEdit {
    final detail = _detail;
    final session = AuthSessionStore.current;
    return detail?.isDraft == true &&
        session?.user.hasPermission('STOCKTAKE', 'UPDATE') == true;
  }

  bool get _canApprove {
    final session = AuthSessionStore.current;
    return _detail?.statusCode.trim().toUpperCase() == 'SUBMITTED' &&
        session?.user.hasPermission('STOCKTAKE', 'APPROVE') == true;
  }

  bool get _canDelete =>
      _detail?.statusCode.trim().toUpperCase() == 'DRAFT' &&
      AuthSessionStore.current?.user.hasPermission('STOCKTAKE', 'DELETE') ==
          true;

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
      if (!counted) {
        bag.countedWeightKg = null;
        _kgControllers[bag.id]?.clear();
        // Bao không tìm thấy thì không còn gì để chuyển cách ly hay bỏ đi.
        bag.disposition = BagDisposition.keep;
        bag.targetLocationId = null;
      }
      if (counted) _targetBagId = bag.id;
    });
  }

  void _onScaleCapture(WeightReading reading, bool automatic) {
    if (!_canEdit) return;
    final capturedWeight = ceilKg(reading.weight);

    final bag = _targetBag;
    if (bag == null) {
      _snack('Chọn bao cần cân trước đã.', error: true);
      return;
    }

    setState(() {
      bag.countedWeightKg = capturedWeight;
      bag.counted = true;
      _kgController(bag).text = formatQuantityInput(capturedWeight, digits: 1);
    });

    if (!automatic) {
      _snack('Bao #${bag.bagNo}: ${formatNumber(bag.countedWeightKg, digits: 1)} kg');
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 4),
          content: Text(
              'Bao #${bag.bagNo}: ${formatNumber(bag.countedWeightKg, digits: 1)} kg'),
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () {
              setState(() {
                bag.countedWeightKg = null;
                _kgController(bag).clear();
              });
              _scaleBarKey.currentState?.suppressCurrentReading();
            },
          ),
        ));
    }
    // Cân xong bao này thì nhảy sang bao chưa đếm kế tiếp để cân liên tục.
    setState(() => _targetBagId = _firstUncountedBagId() ?? bag.id);
  }

  /// Nhập tay khối lượng cho một bao — dùng khi không có cân BLE bên cạnh,
  /// cân hỏng, hoặc chỉ cần sửa lại một con số đã cân.
  void _setBagWeightManually(StockTakeBag bag, String raw) {
    final value = parseDecimal(raw);
    setState(() {
      bag.countedWeightKg = value;
      if (value != null) bag.counted = true;
    });
  }

  // ── Lưu / gửi duyệt ────────────────────────────────────────────────
  Future<bool> _save({bool silent = false}) async {
    final detail = _detail;
    if (detail == null) return false;

    // Kết luận nhập một lần cho cả cột → áp xuống mọi lô trước khi gửi đi.
    // Lô không lệch thì lý do không được dùng tới, nên áp thừa cũng vô hại.
    for (final line in detail.lines) {
      line.varianceReason = _varianceReason.trim().isEmpty ? null : _varianceReason.trim();
      line.recountConfirmed = _recountConfirmed;
      line.adjustedBagCount = _canAdjustTotals ? _adjustedBagCount : null;
      line.adjustedWeightKg = _canAdjustTotals ? _adjustedWeightKg : null;
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
    if (detail == null || !_canEdit || _busy) return;

    if (!_touched) {
      _snack('Chưa kiểm bao nào trong cột.', error: true);
      return;
    }
    final legacyMissing = _legacyLines.where((l) => l.actualQuantity == null);
    if (legacyMissing.isNotEmpty) {
      _snack('Dòng ${legacyMissing.first.title} chưa nhập khối lượng thực tế.',
          error: true);
      return;
    }
    if (_hasVariance && _varianceReason.trim().isEmpty) {
      _snack('Cột có chênh lệch — bắt buộc nêu lý do.', error: true);
      return;
    }
    if (_columnTier == 'LARGE' && !_recountConfirmed) {
      _snack('Chênh lệch mức LARGE — phải xác nhận đã đếm lại.', error: true);
      return;
    }

    // Bao chuyển cách ly / rút về khu thường phải có vị trí đích;
    // bao bỏ vì hỏng phải ghi rõ lý do — nếu không backend sẽ chặn khi duyệt.
    for (final bag in _allBags) {
      if (bag.disposition.needsTarget && bag.targetLocationId == null) {
        _snack('Bao #${bag.bagNo} chưa chọn vị trí đích.', error: true);
        return;
      }
      if (bag.disposition == BagDisposition.dispose &&
          (bag.dispositionNote ?? '').trim().isEmpty) {
        _snack('Bao #${bag.bagNo} bỏ vì hỏng — phải ghi rõ lý do.', error: true);
        return;
      }
    }

    final totalActualKg = _countedKg;
    final totalSystemKg = _systemKg;
    final netDiffKg = totalActualKg - totalSystemKg;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gửi phiếu để duyệt?'),
        content: Text(
          'Đã kiểm $_countedBagCount/$_systemBagCount bao — '
          '${formatKg(totalActualKg, digits: 1)} / ${formatKg(totalSystemKg, digits: 1)} kg'
          '${netDiffKg.abs() >= 0.05 ? ' (chênh lệch ${netDiffKg >= 0 ? '+' : ''}${formatKg(netDiffKg, digits: 1)} kg)' : ''}.'
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
      final refreshed = await _repository.getDetail(detail.id);
      if (!mounted) return;
      if (refreshed.statusCode.trim().toUpperCase() != 'SUBMITTED') {
        _snack(
            'Backend chưa xác nhận phiếu đã chuyển sang trạng thái Đã gửi duyệt.',
            error: true);
        setState(() {
          _detail = refreshed;
          _loading = false;
        });
        return;
      }
      _snack('Đã gửi phiếu để duyệt.');
      setState(() {
        _detail = refreshed;
        _loading = false;
        _remoteChanged = false;
      });
    } catch (error) {
      if (mounted) _snack('$error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve() async {
    final detail = _detail;
    if (detail == null || !_canApprove || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duyệt phiếu kiểm kê?'),
        content:
            Text('Phiếu ${detail.code} sẽ được chốt kết quả và không thể sửa.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xác nhận duyệt')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repository.approve(detail.id);
      final refreshed = await _repository.getDetail(detail.id);
      if (!mounted) return;
      if (refreshed.statusCode.trim().toUpperCase() != 'APPROVED') {
        _snack('Backend chưa xác nhận phiếu đã được duyệt.', error: true);
      }
      setState(() => _detail = refreshed);
    } catch (error) {
      if (mounted) _snack('$error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final detail = _detail;
    if (detail == null || !_canApprove || _busy) return;
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Từ chối phiếu kiểm kê?'),
        content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Lý do bắt buộc')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Xác nhận từ chối')),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (reason == null || reason.trim().isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repository.reject(detail.id, reason: reason.trim());
      final refreshed = await _repository.getDetail(detail.id);
      if (!mounted) return;
      if (refreshed.statusCode.trim().toUpperCase() != 'REJECTED') {
        _snack('Backend chưa xác nhận phiếu đã bị từ chối.', error: true);
      }
      setState(() => _detail = refreshed);
    } catch (error) {
      if (mounted) _snack('$error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final detail = _detail;
    if (detail == null || !_canDelete || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa phiếu kiểm kê?'),
        content: Text('Phiếu ${detail.code} sẽ được xóa khỏi danh sách.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa phiếu')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repository.delete(detail.id);
      if (mounted) Navigator.of(context).pop(true);
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
                      '$_countedBagCount/$_systemBagCount bao',
              leading: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                color: Colors.white,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            Expanded(child: _body()),
            if (detail != null && (detail.isDraft || _canApprove))
              _bottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _detail == null) return const ListSkeleton();
    if (_error != null && _detail == null) {
      return HErrorState(
          message: 'Không tải được phiếu: $_error', onRetry: _load);
    }
    final detail = _detail!;
    if (detail.lines.isEmpty) {
      return const HEmptyState(
        title: 'Cột này không có gì để kiểm',
        description: 'Cột đã chọn không còn tồn kho.',
        icon: Icons.inventory_2_outlined,
      );
    }

    final bags = _allBags;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        if (!detail.isDraft)
          AppInfoBanner(
            tone: AppTone.info,
            icon: Icons.lock_outline_rounded,
            message:
                'Phiếu đã ${detail.statusName.toLowerCase()} — số liệu được khoá.',
          ),
        if (detail.isQuarantineScope) ...[
          const AppInfoBanner(
            tone: AppTone.warning,
            icon: Icons.health_and_safety_outlined,
            message: 'Kiểm kê KHU CÁCH LY — bao đạt chọn “Rút về khu thường” '
                'rồi chọn cột thường để cất lại.',
          ),
          const SizedBox(height: 10),
        ],
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
        _columnSummary(detail),
        const SizedBox(height: 12),
        if (_canEdit && bags.isNotEmpty) ...[
          ScaleBar(
            key: _scaleBarKey,
            enabled: _canEdit && _targetBag != null,
            targetLabel:
                _targetBag == null ? 'Bao chưa chọn' : 'bao #${_targetBag!.bagNo}',
            onCapture: _onScaleCapture,
          ),
          const SizedBox(height: 4),
          Text(
            'Không có cân bên cạnh thì gõ thẳng số kg vào ô của từng bao.',
            style: TextStyle(
                fontSize: 11.5, color: AppColors.textSecondaryFor(context)),
          ),
          const SizedBox(height: 12),
        ],
        ..._bagCards(bags),
        ..._legacyCards(),
        const SizedBox(height: 12),
        _decisionCard(detail),
      ],
    );
  }

  // ── Số liệu của CỘT ────────────────────────────────────────────────
  int get _systemBagCount =>
      (_detail?.lines ?? const <StockTakeLine>[]).fold(0, (s, l) => s + l.systemBagCount);

  int get _countedBagCount =>
      _adjustedBagCount ?? _allBags.where((b) => b.counted).length;

  double get _systemKg =>
      (_detail?.lines ?? const <StockTakeLine>[]).fold<double>(0, (s, l) => s + l.systemQuantity);

  double get _countedKg =>
      _adjustedWeightKg ??
      (_allBags.fold<double>(0, (s, b) => s + b.effectiveKg) +
          _legacyLines.fold<double>(0, (s, l) => s + (l.actualQuantity ?? 0)));

  int get _bagVariance => _countedBagCount - _systemBagCount;
  double get _kgVariance => _countedKg - _systemKg;

  bool get _touched =>
      _allBags.any((b) => b.counted || b.countedWeightKg != null) ||
      _legacyLines.any((l) => l.actualQuantity != null);

  bool get _hasVariance =>
      _touched && (_bagVariance != 0 || _kgVariance.abs() >= 0.05);

  /// Chỉnh lý tổng chỉ dùng được khi cột có đúng một lô — nhiều lô thì không
  /// có cách nào chia con số tổng cho từng lô mà không bịa số.
  bool get _canAdjustTotals =>
      (_detail?.lines ?? const <StockTakeLine>[]).where((x) => x.hasBags).length <= 1;

  /// Lệch SỐ BAO luôn xếp LARGE: mất nguyên một bao là sự cố an ninh kho,
  /// còn theo ngưỡng kg thì một bao 50 kg trong cột 5 tấn chỉ là 1% → trôi qua.
  String get _columnTier {
    if (!_touched) return 'NONE';
    if (_bagVariance != 0) return 'LARGE';
    return _varianceTier(_systemKg, _kgVariance);
  }

  String _varianceTier(double systemKg, double diffKg) {
    final absDiff = diffKg.abs();
    if (absDiff < 0.05) return 'NONE';
    final pct = systemKg > 0 ? (absDiff / systemKg) * 100 : 0;
    if (pct >= 2.0 || absDiff >= 20) return 'LARGE';
    if (pct >= 1.0 || absDiff >= 10) return 'MEDIUM';
    return 'SMALL';
  }

  Color _tierColor(String tier) => switch (tier) {
        'SMALL' => Colors.blue,
        'MEDIUM' => Colors.orange,
        'LARGE' => Colors.red,
        _ => Colors.grey,
      };

  Widget _columnSummary(StockTakeDetail detail) {
    final tier = _columnTier;
    final quarantine = _allBags.where((b) => b.disposition == BagDisposition.quarantine).length;
    final disposed = _allBags.where((b) => b.disposition == BagDisposition.dispose).length;
    final released = _allBags.where((b) => b.disposition == BagDisposition.release).length;
    final issues = _allBags.where((b) => b.quality.isIssue).length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(detail.scopeDisplay.isEmpty ? 'Cột kiểm kê' : detail.scopeDisplay,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                    Text(detail.warehouseName,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondaryFor(context))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _tierColor(tier).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(tier,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold, color: _tierColor(tier))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppStatTile(
                  label: 'Bao (đếm/sổ)',
                  value: '${_touched ? _countedBagCount : 0}/$_systemBagCount',
                  tone: !_touched
                      ? AppTone.neutral
                      : (_bagVariance == 0 ? AppTone.brand : AppTone.danger),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppStatTile(
                  label: 'Kg thực tế',
                  value: _touched ? formatKg(_countedKg, digits: 1) : '—',
                  tone: AppTone.neutral,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppStatTile(
                  label: 'Lệch kg',
                  value: _touched
                      ? '${_kgVariance >= 0 ? '+' : ''}${formatKg(_kgVariance, digits: 1)}'
                      : '—',
                  tone: !_touched
                      ? AppTone.neutral
                      : (_kgVariance.abs() < 0.05
                          ? AppTone.neutral
                          : (_kgVariance < 0 ? AppTone.danger : AppTone.warning)),
                ),
              ),
            ],
          ),
          if (_touched && _bagVariance != 0) ...[
            const SizedBox(height: 8),
            AppInfoBanner(
              tone: AppTone.danger,
              icon: Icons.inventory_2_outlined,
              message: _bagVariance < 0
                  ? 'Thiếu ${-_bagVariance} bao so với sổ sách — bắt buộc nêu lý do và xác nhận đếm lại.'
                  : 'Thừa ${_bagVariance} bao so với sổ sách — bắt buộc nêu lý do.',
            ),
          ],
          if (quarantine > 0 || disposed > 0 || released > 0 || issues > 0) ...[
            const SizedBox(height: 8),
            AppInfoBanner(
              tone: AppTone.warning,
              icon: Icons.move_down_rounded,
              message: [
                if (issues > 0) '$issues bao có vấn đề chất lượng',
                if (quarantine > 0) '$quarantine bao chuyển cách ly',
                if (disposed > 0) '$disposed bao hỏng bỏ ra',
                if (released > 0) '$released bao rút về khu thường',
              ].join(' · '),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _ensureBagTargets(StockTakeBag bag) async {
    if (_bagTargets.containsKey(bag.id) || _loadingTargets.contains(bag.id)) return;
    _loadingTargets.add(bag.id);
    try {
      final targets = await _repository.getBagTargets(widget.stockTakeId, bag.id);
      if (!mounted) return;
      setState(() {
        _bagTargets[bag.id] = targets;
        // Chọn sẵn vị trí đầu danh sách cho đỡ một thao tác; thủ kho đổi được.
        if (bag.targetLocationId == null && targets.isNotEmpty) {
          bag.targetLocationId = targets.first.locationId;
        }
      });
    } finally {
      _loadingTargets.remove(bag.id);
    }
  }

  List<BagDisposition> get _dispositionChoices =>
      _detail?.isQuarantineScope == true
          ? const [BagDisposition.keep, BagDisposition.release, BagDisposition.dispose]
          : const [BagDisposition.keep, BagDisposition.quarantine, BagDisposition.dispose];

  void _setDisposition(StockTakeBag bag, BagDisposition value) {
    setState(() {
      bag.disposition = value;
      // Chọn cách xử lý nghĩa là đã cầm bao trên tay.
      if (value != BagDisposition.keep) bag.counted = true;
      // Đổi cách xử lý thì vị trí đích cũ không còn hợp lệ (cách ly vs cột thường).
      bag.targetLocationId = null;
      _bagTargets.remove(bag.id);
    });
    if (value.needsTarget) unawaited(_ensureBagTargets(bag));
  }

  Widget _qualityRow(StockTakeBag bag) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final quality in const [BagQualityResult.pass, BagQualityResult.issue])
          ChoiceChip(
            visualDensity: VisualDensity.compact,
            label: Text(quality.label, style: const TextStyle(fontSize: 11.5)),
            selected: bag.quality == quality,
            onSelected: _canEdit
                ? (selected) => setState(() {
                      bag.quality = selected ? quality : BagQualityResult.none;
                      if (bag.quality != BagQualityResult.none) bag.counted = true;
                    })
                : null,
          ),
      ],
    );
  }

  Widget _qualityDetailRow(StockTakeBag bag) {
    // Xếp DỌC và để dropdown chiếm hết bề ngang: nhồi 3 ô vào một hàng trên màn
    // điện thoại thì "Có dấu hiệu" / "Cần xử lý" tràn ô và Flutter báo overflow.
    Widget picker(String label, List<String> options, String? value,
        void Function(String?) onChanged) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: DropdownButtonFormField<String>(
          initialValue: options.contains(value) ? value : null,
          isExpanded: true,
          isDense: true,
          decoration: InputDecoration(labelText: label, isDense: true),
          items: [
            for (final option in options)
              DropdownMenuItem(
                value: option,
                child: Text(option,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _canEdit ? onChanged : null,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        picker('Mức mốc', const ['Không', 'Nhẹ', 'Nặng'], bag.moldLevel,
            (v) => setState(() => bag.moldLevel = v)),
        picker('Mức mọt', const ['Không', 'Có dấu hiệu', 'Cần xử lý'], bag.pestLevel,
            (v) => setState(() => bag.pestLevel = v)),
        picker('Tình trạng bao bì', const ['Nguyên', 'Rách', 'Ẩm'], bag.packagingStatus,
            (v) => setState(() => bag.packagingStatus = v)),
      ],
    );
  }

  Widget _dispositionRow(StockTakeBag bag) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final choice in _dispositionChoices)
          ChoiceChip(
            visualDensity: VisualDensity.compact,
            label: Text(choice.label, style: const TextStyle(fontSize: 11.5)),
            selected: bag.disposition == choice,
            onSelected: _canEdit ? (_) => _setDisposition(bag, choice) : null,
          ),
      ],
    );
  }

  Widget _targetPicker(StockTakeBag bag) {
    final targets = _bagTargets[bag.id];
    if (targets == null) {
      unawaited(_ensureBagTargets(bag));
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text('Đang tải danh sách vị trí…', style: TextStyle(fontSize: 12)),
      );
    }
    if (targets.isEmpty) {
      return AppInfoBanner(
        tone: AppTone.danger,
        icon: Icons.warning_amber_rounded,
        message: bag.disposition == BagDisposition.quarantine
            ? 'Không còn ô cách ly nào đủ chỗ. Hãy giải phóng ô cách ly trước.'
            : 'Không còn cột thường nào đủ chỗ để cất lại.',
      );
    }
    return DropdownButtonFormField<int>(
      initialValue: targets.any((t) => t.locationId == bag.targetLocationId)
          ? bag.targetLocationId
          : null,
      // isExpanded bắt buộc: thiếu nó thì tên cột dài làm dropdown tràn ngang.
      isExpanded: true,
      isDense: true,
      decoration: const InputDecoration(
        labelText: 'Vị trí đích *',
        isDense: true,
      ),
      items: [
        for (final target in targets)
          DropdownMenuItem(
            value: target.locationId,
            child: Text(target.label,
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: _canEdit
          ? (value) => setState(() => bag.targetLocationId = value)
          : null,
    );
  }

  List<Widget> _bagCards(List<StockTakeBag> bags) {
    if (bags.isEmpty) return const [];
    return [
      Row(
        children: [
          Expanded(
            child: Text('Bao trong cột (${bags.length}) — lấy từ TRÊN xuống',
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          if (_canEdit)
            TextButton(
              onPressed: () => setState(() {
                for (final bag in bags) {
                  bag.counted = true;
                }
              }),
              child: const Text('Tích tất cả'),
            ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'Cất lại theo thứ tự “Cất”: bao lấy ra sau cùng được cất vào cột trước.',
          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondaryFor(context)),
        ),
      ),
      for (final bag in bags)
        AppCard(
          margin: const EdgeInsets.only(bottom: 8),
          color: bag.id == _targetBagId ? AppColors.brandTintFor(context) : null,
          onTap: _canEdit ? () => setState(() => _targetBagId = bag.id) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: bag.counted,
                    onChanged: _canEdit ? (v) => _toggleBag(bag, v ?? false) : null,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Wrap chứ không Row: màn hẹp mà ghép "Bao #123 · Lấy 12
                        // · Cất 13 · ngoài danh sách" trên một dòng là tràn ngang.
                        Wrap(
                          spacing: 6,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('Bao #${bag.bagNo}',
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text('Lấy ${bag.pickSequence} · Cất ${bag.restowSequence}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondaryFor(context))),
                            if (bag.isUnexpected)
                              const Text('ngoài danh sách',
                                  style: TextStyle(fontSize: 11, color: AppColors.warning)),
                          ],
                        ),
                        Text(
                          'Sổ sách ${formatKg(bag.systemWeightKg, digits: 1)}',
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
              if (bag.counted) ...[
                const SizedBox(height: 6),
                // Nhập tay song song với cân BLE: cân hỏng, cân bận, hoặc chỉ
                // muốn sửa lại một con số thì không phải đặt bao lên cân lần nữa.
                TextFormField(
                  controller: _kgController(bag),
                  enabled: _canEdit,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Khối lượng cân (kg)',
                    hintText: 'Để trống = giữ nguyên kg sổ sách',
                    suffixText: 'kg',
                  ),
                  onChanged: (value) => _setBagWeightManually(bag, value),
                ),
                const SizedBox(height: 6),
                _qualityRow(bag),
                if (bag.quality.isIssue) ...[
                  const SizedBox(height: 6),
                  _qualityDetailRow(bag),
                ],
                const SizedBox(height: 6),
                _dispositionRow(bag),
                if (bag.disposition.needsTarget) ...[
                  const SizedBox(height: 6),
                  _targetPicker(bag),
                ],
                if (bag.disposition != BagDisposition.keep) ...[
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: bag.dispositionNote,
                    enabled: _canEdit,
                    maxLines: 2,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: bag.disposition == BagDisposition.dispose
                          ? 'Lý do bỏ bao hỏng *'
                          : 'Ghi chú xử lý',
                    ),
                    onChanged: (value) => bag.dispositionNote = value,
                  ),
                ],
              ],
            ],
          ),
        ),
    ];
  }

  /// Dòng dữ liệu cũ chưa quản lý theo bao — vẫn nhập tổng kg tay như trước.
  List<Widget> _legacyCards() {
    final lines = _legacyLines;
    if (lines.isEmpty) return const [];
    return [
      const Padding(
        padding: EdgeInsets.only(top: 4, bottom: 8),
        child: Text('Dòng chưa quản lý theo bao',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      for (final line in lines)
        AppCard(
          margin: const EdgeInsets.only(bottom: 8),
          child: TextFormField(
            initialValue: line.actualQuantity == null
                ? null
                : formatQuantityInput(line.actualQuantity, digits: 1),
            enabled: _canEdit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '${line.title} — kg thực tế *',
              suffixText: 'kg',
              helperText: 'Sổ sách ${formatKg(line.systemQuantity, digits: 1)}',
            ),
            onChanged: (value) =>
                setState(() => line.actualQuantity = parseDecimal(value)),
          ),
        ),
    ];
  }

  /// Kết luận cho CẢ CỘT — nhập một lần, khi lưu sẽ áp cho mọi lô trong cột.
  Widget _decisionCard(StockTakeDetail detail) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kết luận cho cột',
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: _varianceReason,
            enabled: _canEdit,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: _hasVariance ? 'Lý do lệch *' : 'Lý do lệch',
              hintText: 'Bắt buộc khi lệch số bao hoặc lệch kg',
            ),
            onChanged: (value) => _varianceReason = value,
          ),
          if (_canAdjustTotals) ...[
            const SizedBox(height: 8),
            Text('Chỉnh lý sau kiểm kê (để trống nếu lấy đúng số đếm được)',
                style: TextStyle(
                    fontSize: 11.5, color: AppColors.textSecondaryFor(context))),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _adjustedBagCount?.toString(),
                    enabled: _canEdit,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Số bao chốt lại', isDense: true),
                    onChanged: (value) => setState(
                        () => _adjustedBagCount = int.tryParse(value.trim())),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: _adjustedWeightKg == null
                        ? null
                        : formatQuantityInput(_adjustedWeightKg, digits: 1),
                    enabled: _canEdit,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Kg chốt lại', suffixText: 'kg', isDense: true),
                    onChanged: (value) =>
                        setState(() => _adjustedWeightKg = parseDecimal(value)),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Cột đang chứa nhiều lô nên không chỉnh lý tổng được — sửa trực tiếp trên từng bao.',
              style: TextStyle(
                  fontSize: 11.5, color: AppColors.textSecondaryFor(context)),
            ),
          ],
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _recountConfirmed,
            onChanged: _canEdit
                ? (value) => setState(() => _recountConfirmed = value ?? false)
                : null,
            title: const Text('Đã đếm lại lần hai',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _bottomActions() {
    if (_canApprove) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
            color: AppColors.surfaceFor(context),
            border:
                Border(top: BorderSide(color: AppColors.borderFor(context)))),
        child: Row(children: [
          Expanded(
              child: OutlinedButton(
                  onPressed: _busy ? null : _reject,
                  child: const Text('Từ chối'))),
          const SizedBox(width: 10),
          Expanded(
              child: FilledButton(
                  onPressed: _busy ? null : _approve,
                  child: const Text('Duyệt'))),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        border: Border(top: BorderSide(color: AppColors.borderFor(context))),
      ),
      child: Row(
        children: [
          if (_canDelete) ...[
            Expanded(
                child: OutlinedButton(
                    onPressed: _busy ? null : _delete,
                    child: const Text('Xóa'))),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: OutlinedButton(
              onPressed: !_canEdit || _busy ? null : () => _save(),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46)),
              child: const Text('Lưu nháp'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: !_canEdit || _busy ? null : _submit,
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

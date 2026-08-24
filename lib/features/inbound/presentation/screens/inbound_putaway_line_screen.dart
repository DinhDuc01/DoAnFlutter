import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_reload_mixin.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../auth/data/auth_session_store.dart';
import '../../data/inbound_order_repository.dart';
import '../../models/bag_putaway_planner.dart';
import '../../models/inbound_order.dart';

/// Trạng thái hiển thị của bước xếp vị trí (khớp `ScreenStatus` của web).
enum PutawayStatus { waiting, suggested, split, capacity, conflict, error }

/// Bước "Xếp vị trí cho một lô" — gợi ý vị trí với logic giống hệt web:
/// backend chấm điểm và trả danh sách ưu tiên, kèm phương án xếp nguyên bao
/// theo LIFO cho phép chia/đổi cột trước khi xác nhận.
///
/// Mobile chỉ được GỬI DUYỆT và NHẬN HÀNG. Khi phiếu đang chờ duyệt, màn này
/// chỉ báo trạng thái — phê duyệt phiếu nhập chỉ thực hiện trên web.
class InboundPutawayLineScreen extends StatefulWidget {
  const InboundPutawayLineScreen({
    required this.line,
    this.locations = const <StorageLocation>[],
    this.repository,
    super.key,
  });

  final InboundPutawayLine line;
  final List<StorageLocation> locations;
  final InboundOrderRepository? repository;

  @override
  State<InboundPutawayLineScreen> createState() =>
      _InboundPutawayLineScreenState();
}

class _InboundPutawayLineScreenState extends State<InboundPutawayLineScreen>
    with RealtimeReloadMixin {
  late final InboundOrderRepository _repository;
  late InboundPutawayLine _line;
  late List<StorageLocation> _locations;

  final _overrideReasonController = TextEditingController();

  List<PutawaySuggestion> _suggestions = const <PutawaySuggestion>[];
  BagPutawayPlan? _plan;
  final Set<String> _expandedGroups = <String>{};
  int? _selectedLocationId;
  int? _manualLocationId;
  bool _manualOverride = false;
  double _placementWeightKg = 0;
  PutawayStatus _status = PutawayStatus.waiting;
  String _message = '';
  bool _busy = false;
  bool _changed = false;
  bool _finished = false;

  /// Đã tự chạy chuỗi nhận hàng + lấy gợi ý cho lượt hiện tại hay chưa.
  /// Đặt lại sau mỗi lần xác nhận xếp một phần để lượt sau tự chạy tiếp.
  bool _autoPrepared = false;

  @override
  Set<String> get realtimeEntities => const {
        'InboundOrder',
        'InboundOrderItem',
        'PaddyLot',
        'PaddyLotBag',
        'Location',
        'Inventory',
      };

  @override
  void onRealtimeChanged() {
    if (!_busy && !_finished && mounted) _reloadLine();
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiInboundOrderRepository();
    _line = widget.line;
    _locations = widget.locations;
    _placementWeightKg = _initialWeight();
    _finished = _line.item.remainingKg <= 0;
    if (_finished) {
      _status = PutawayStatus.waiting;
      _message = 'Đã hoàn tất nhập kho lô hàng.';
      _autoPrepared = true;
    } else {
      // Giống web: không bắt người dùng bấm "Bắt đầu nhận hàng" rồi "Tải vị trí".
      // Vào màn là tự nhận hàng và đẩy thẳng danh sách vị trí được gợi ý.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_finished) _maybeAutoPrepare();
      });
    }
  }

  @override
  void didUpdateWidget(InboundPutawayLineScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line.item.id != widget.line.item.id) {
      _line = widget.line;
      _locations = widget.locations;
      _placementWeightKg = _initialWeight();
      _finished = _line.item.remainingKg <= 0;
      _autoPrepared = false;
      _suggestions = const <PutawaySuggestion>[];
      _plan = null;
      _selectedLocationId = null;
      _manualLocationId = null;
      _manualOverride = false;
      _overrideReasonController.clear();
      if (_finished) {
        _status = PutawayStatus.waiting;
        _message = 'Đã hoàn tất nhập kho lô hàng.';
        _autoPrepared = true;
      } else {
        _status = PutawayStatus.waiting;
        _message = '';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_finished) _maybeAutoPrepare();
        });
      }
    }
  }

  @override
  void dispose() {
    _overrideReasonController.dispose();
    super.dispose();
  }

  double _initialWeight() {
    final remaining = _line.item.remainingKg;
    final entered = _line.item.quantityEntered ?? remaining;
    return math.min(entered <= 0 ? remaining : entered, remaining);
  }

  String get _orderStatus => _line.order.normalizedStatus;

  bool get _canUpdate {
    final session = AuthSessionStore.current;
    if (session == null) return false;
    if (session.isAdmin) return true;
    return session.hasPermission('INBOUND_ORDERS', 'UPDATE') ||
        session.hasPermission('INBOUND_ORDERS', 'APPROVE');
  }

  /// Nhãn nút chuyển bước. Chỉ còn GỬI DUYỆT:
  /// - "Phê duyệt phiếu" cố ý không có trên mobile (chỉ web).
  /// - "Bắt đầu nhận hàng" đã bỏ: phiếu đã duyệt thì màn tự nhận hàng và tải
  ///   gợi ý vị trí, đúng như web làm sau khi duyệt.
  String get _actionLabel =>
      _orderStatus == InboundOrderStatuses.draft ? 'Gửi duyệt phiếu' : '';

  bool get _canPrepare => const [
        InboundOrderStatuses.approved,
        InboundOrderStatuses.receiving,
        InboundOrderStatuses.partiallyReceived,
      ].contains(_orderStatus);

  bool get _isWaitingApproval => _orderStatus == InboundOrderStatuses.submitted;

  /// Chỉ phiếu đã được duyệt/đang nhận và người dùng có UPDATE/APPROVE mới được
  /// sửa phương án hoặc xác nhận xếp kho.
  bool get _canEditPlan => _canUpdate && _canPrepare;

  /// Phiếu chờ duyệt và tài khoản chỉ có READ vẫn được tải phương án để xem.
  /// Nhánh này không được gọi start/record/confirm.
  bool get _shouldLoadReadOnlyPlan =>
      _isWaitingApproval || (_canPrepare && !_canUpdate);

  List<StorageLocation> get _warehouseLocations {
    final warehouseId = _line.order.warehouseId;
    final needsQuarantine = _line.item.needsQuarantine;
    final list = _locations
        .where((location) =>
            (warehouseId == 0 || location.warehouseId == warehouseId) &&
            location.isActive &&
            !location.isOutboundStaging &&
            !location.isLockedForOutbound &&
            location.maxCapacity > location.currentOccupancy &&
            location.isQuarantine == needsQuarantine)
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    return list;
  }

  // ================= Tải dữ liệu =================

  Future<void> _reloadLine() async {
    if (_finished || !mounted) return;
    try {
      final lines = await _repository.getPutawayPending();
      final locations = await _repository.getLocations();
      if (!mounted || _finished) return;
      InboundPutawayLine? found;
      for (final line in lines) {
        if (line.item.id == _line.item.id) found = line;
      }
      final shouldPrepare = found != null && found.item.remainingKg > 0;
      setState(() {
        if (locations.isNotEmpty) _locations = locations;
        if (shouldPrepare) {
          _line = found!;
          _finished = false;
        } else {
          // Endpoint pending có thể còn trả về dòng vừa hoàn tất trong một
          // khoảng ngắn hoặc không còn dòng nào trong pending.
          _finished = true;
          _status = PutawayStatus.waiting;
          _message = 'Đã hoàn tất nhập kho lô hàng.';
        }
      });
      if (shouldPrepare && !_finished && mounted) {
        await _maybeAutoPrepare();
      }
    } catch (_) {
      // Reload im lặng thất bại thì giữ nguyên màn đang thao tác.
    }
  }

  /// Tự chạy chuỗi nhận hàng rồi lấy gợi ý vị trí — thay cho hai nút thủ công.
  /// Chạy đúng một lần cho mỗi lượt xếp; phiếu chưa được duyệt thì bỏ qua và sẽ
  /// tự chạy khi realtime báo phiếu đã duyệt trên web.
  Future<void> _maybeAutoPrepare() async {
    if (!mounted || _busy || _finished || _autoPrepared) return;
    if (_line.item.remainingKg <= 0) {
      if (!_finished && mounted) {
        setState(() {
          _finished = true;
          _status = PutawayStatus.waiting;
          _message = 'Đã hoàn tất nhập kho lô hàng.';
        });
      }
      return;
    }
    if (_suggestions.isNotEmpty || (_plan?.columns.isNotEmpty ?? false)) return;

    if (_shouldLoadReadOnlyPlan) {
      _autoPrepared = true;
      await _loadPlanPreview();
      return;
    }
    if (!_canEditPlan) return;
    _autoPrepared = true;
    await _prepare();
  }

  Future<void> _loadPlanPreview() async {
    if (_busy || _finished || !_shouldLoadReadOnlyPlan || !mounted) return;
    await _fetchSuggestions(readOnly: true);
  }

  Future<void> _fetchSuggestions({
    int? preferredLocationId,
    bool readOnly = false,
  }) async {
    if (_finished || !mounted) return;
    setState(() {
      _busy = true;
      if (_status == PutawayStatus.error || _status == PutawayStatus.conflict) {
        _status = PutawayStatus.waiting;
        _message = '';
      }
    });
    try {
      // Web luôn có danh sách vị trí hợp lệ của kho làm dữ liệu dự phòng.
      // Mobile cũng phải tải danh sách này; API gợi ý có thể trả rỗng hoặc lỗi
      // nhưng người có READ vẫn cần xem được các khu/cột còn sức chứa.
      if (_locations.isEmpty) {
        final locations = await _repository.getLocations();
        if (!mounted || _finished) return;
        _locations = List<StorageLocation>.unmodifiable(locations);
      }

      List<PutawaySuggestion> suggestions = const <PutawaySuggestion>[];
      Object? suggestionError;
      try {
        suggestions = await _repository.getPutawaySuggestions(
          _line.order.id,
          _line.item.id,
        );
      } catch (error) {
        suggestionError = error;
      }
      if (!mounted || _finished) return;

      // Với luồng thao tác, lỗi API gợi ý vẫn phải chặn nếu cả kho không có vị trí fallback.
      if (suggestionError != null &&
          (!readOnly || _warehouseLocations.isEmpty)) {
        throw suggestionError;
      }

      // Giống FE web: lấy phương án xếp nguyên bao nếu có. Nếu backend không có bao
      // (hoặc trả 403 do vai trò/lô không bao), FE web bắt lỗi và gán plan = null,
      // sau đó hiển thị danh sách vị trí đề xuất hoặc các khu/cột còn chỗ để xếp.
      BagPutawayPlan? plan;
      try {
        if (!readOnly) {
          plan = await _repository.getBagPutawayPlan(
            _line.order.id,
            _line.item.id,
          );
        }
      } catch (_) {
        plan = null;
      }
      if (!mounted || _finished) return;

      final ordered = (plan == null || plan.columns.isEmpty)
          ? List<PutawaySuggestion>.unmodifiable(suggestions)
          : BagPutawayPlanner.orderSuggestionsByPlan(suggestions, plan);
      PutawaySuggestion? selected;
      for (final suggestion in ordered) {
        if (suggestion.locationId == preferredLocationId) selected = suggestion;
      }
      selected ??= ordered.isEmpty ? null : ordered.first;

      if (!mounted || _finished) return;
      setState(() {
        _busy = false;
        _plan = plan;
        _expandedGroups.clear();
        _suggestions = ordered;
        _selectedLocationId = selected?.locationId ??
            (ordered.isEmpty && _warehouseLocations.isNotEmpty
                ? _warehouseLocations.first.id
                : null);
        if (readOnly) {
          _status = PutawayStatus.waiting;
          _message = _isWaitingApproval
              ? 'Phiếu đang chờ người khác phê duyệt. Phương án xếp kho bên dưới chỉ để xem.'
              : 'Bạn chỉ có quyền xem. Phương án xếp kho bên dưới không thể chỉnh sửa.';
        } else if (selected == null && _warehouseLocations.isEmpty) {
          _status = PutawayStatus.capacity;
          _message = 'Không còn vị trí phù hợp đủ sức chứa.';
        } else if (selected != null) {
          _placementWeightKg = selected.recommendedWeightKg;
          _status = selected.canFitWhole
              ? PutawayStatus.suggested
              : PutawayStatus.split;
          _message = preferredLocationId != null &&
                  selected.locationId != preferredLocationId
              ? 'Khu/cột vừa chọn không đạt đủ điều kiện. Hệ thống đã chọn vị trí phù hợp nhất.'
              : (selected.canFitWhole
                  ? 'Đã tìm thấy vị trí phù hợp.'
                  : 'Lô cần được tách qua nhiều vị trí.');
        } else {
          _placementWeightKg = math.min(
            _line.item.remainingKg,
            _warehouseLocations.first.freeCapacityKg,
          );
          _status = PutawayStatus.suggested;
          _message = 'Chọn một khu/cột bên dưới để xếp kho.';
        }
      });
    } catch (error) {
      if (!mounted || _finished) return;
      setState(() {
        _busy = false;
        _suggestions = const <PutawaySuggestion>[];
        _plan = null;
        _selectedLocationId = null;
        _status = PutawayStatus.error;
        _message = 'Không tải được vị trí gợi ý: $error';
      });
    }
  }

  // ================= Hành động =================

  /// Chỉ còn một bước thủ công: gửi phiếu nháp đi duyệt.
  Future<void> _advance() async {
    if (!_canUpdate || _finished || !mounted) return;
    if (_busy || _orderStatus != InboundOrderStatuses.draft) return;
    setState(() {
      _busy = true;
      if (_status == PutawayStatus.error || _status == PutawayStatus.conflict) {
        _status = PutawayStatus.waiting;
        _message = '';
      }
    });
    try {
      await _repository.submit(_line.order.id);
      _changed = true;
      if (!mounted || _finished) return;
      setState(() => _busy = false);
      await _reloadLine();
      _snack(
        'Đã gửi phiếu nhập kho để duyệt. Phê duyệt phiếu chỉ thực hiện trên web.',
      );
    } catch (error) {
      if (!mounted || _finished) return;
      setState(() => _busy = false);
      _snack('Không thể gửi duyệt phiếu nhập: $error');
    }
  }

  /// Nhận hàng cho phần còn lại rồi lấy gợi ý vị trí. Khối lượng lấy đúng phần
  /// còn phải nhập (giống web tự động ghi nhận `remaining` sau khi duyệt) nên
  /// không cần ô nhập tay.
  Future<void> _prepare({int? preferredLocationId}) async {
    if (!_canEditPlan || _finished || !mounted) return;
    if (_busy) return;
    final weight = _line.item.remainingKg;
    if (weight <= 0) {
      if (!_finished && mounted) {
        setState(() {
          _finished = true;
          _status = PutawayStatus.waiting;
          _message = 'Đã hoàn tất nhập kho lô hàng.';
        });
      }
      return;
    }

    setState(() {
      _busy = true;
      _status = PutawayStatus.waiting;
      _message = '';
    });
    try {
      if (_orderStatus == InboundOrderStatuses.approved) {
        await _repository.startReceipt(_line.order.id, _line.item.id);
      }
      if (!_line.item.quantityCaptured) {
        await _repository.recordQuantity(_line.order.id, _line.item.id, weight);
      }
      _changed = true;
      if (!mounted || _finished) return;
      _placementWeightKg = weight;
      // Nạp lại dòng để trạng thái phiếu / receiptStatus không còn cũ — lần
      // chạy sau (bấm Thử lại, chọn khu khác) mới không gọi lặp start-receipt.
      await _reloadLine();
      if (!mounted || _finished) return;
      await _fetchSuggestions(preferredLocationId: preferredLocationId);
    } catch (error) {
      if (!mounted || _finished) return;
      setState(() {
        _busy = false;
        _status = PutawayStatus.error;
        _message = 'Không nhận được hàng / tải được vị trí gợi ý: $error';
      });
    }
  }

  void _chooseSuggestion(PutawaySuggestion suggestion) {
    if (_finished || !mounted) return;
    setState(() {
      _selectedLocationId = suggestion.locationId;
      _placementWeightKg = suggestion.recommendedWeightKg;
      _manualOverride = false;
      _status = suggestion.canFitWhole
          ? PutawayStatus.suggested
          : PutawayStatus.split;
      _message = '';
    });
  }

  Future<void> _chooseWarehouseLocation(StorageLocation location) async {
    if (!_canUpdate || _finished || !mounted) return;
    if (_busy) return;
    if (_orderStatus == InboundOrderStatuses.draft ||
        _orderStatus == InboundOrderStatuses.submitted) {
      _snack(
        _orderStatus == InboundOrderStatuses.draft
            ? 'Cần gửi duyệt phiếu trước khi chọn khu/cột.'
            : 'Phiếu đang chờ phê duyệt trên web, chưa chọn được khu/cột.',
      );
      return;
    }
    setState(() {
      _selectedLocationId = location.id;
      _placementWeightKg =
          math.min(_line.item.remainingKg, location.freeCapacityKg);
      _status = PutawayStatus.suggested;
      _message = '';
    });
    if (_canPrepare && !_finished && mounted) {
      await _prepare(preferredLocationId: location.id);
    }
  }

  Future<void> _confirmPutaway() async {
    // Guard ba lớp cho mutation: quyền + trạng thái kế hoạch + cờ _busy + _finished.
    // UI có thể ẩn nút, nhưng function vẫn phải tự bảo vệ khi bị gọi trực tiếp.
    if (!_canEditPlan || _finished || !mounted) return;
    if (_busy) return;
    final plan = _plan;
    final hasPlan = plan != null && plan.columns.isNotEmpty;

    final locationId = hasPlan
        ? plan.columns.first.locationId
        : (_manualOverride ? _manualLocationId : _selectedLocationId);
    if (locationId == null || locationId <= 0) {
      _snack('Vui lòng chọn một vị trí đề xuất hoặc nhập vị trí ghi đè.');
      return;
    }
    if (!hasPlan &&
        _manualOverride &&
        _overrideReasonController.text.trim().isEmpty) {
      _snack('Vui lòng nhập lý do chọn vị trí ngoài danh sách đề xuất.');
      return;
    }
    if (hasPlan && plan.unplacedBagIds.isNotEmpty) {
      _snack('Còn ${plan.unplacedBagIds.length} bao chưa có vị trí.');
      return;
    }

    final weightKg = hasPlan ? plan.totalKg : _placementWeightKg;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận nhập kho?'),
        content: Text(
          hasPlan
              ? 'Hệ thống sẽ xếp ${plan.bagCount} bao (${formatKg(weightKg)}) theo phương án LIFO đã hiển thị.'
              : 'Hệ thống sẽ tăng tồn kho ${formatKg(weightKg)} tại vị trí đã chọn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _finished || _busy) return;

    final remainingBefore = _line.item.remainingKg;
    final isFullyReceived = weightKg >= remainingBefore - 0.0001;
    setState(() {
      _busy = true;
      _status = PutawayStatus.waiting;
      _message = '';
    });
    try {
      if (!hasPlan) {
        await _repository.selectPutaway(
          _line.order.id,
          _line.item.id,
          locationId: locationId,
          isOverride: _manualOverride,
          overrideReason:
              _manualOverride ? _overrideReasonController.text.trim() : null,
          weightKg: weightKg,
        );
      }
      await _repository.confirmReceipt(
        _line.order.id,
        _line.item.id,
        operationKey: _operationKey(),
        columns: hasPlan ? plan.columns : null,
      );
      _changed = true;
      if (!mounted) return;
      setState(() {
        _busy = false;
        _suggestions = const <PutawaySuggestion>[];
        _plan = null;
        _selectedLocationId = null;
        _manualOverride = false;
        _manualLocationId = null;
        _overrideReasonController.clear();
        _autoPrepared = isFullyReceived;
        if (isFullyReceived) {
          _finished = true;
          _status = PutawayStatus.waiting;
          _message = 'Đã hoàn tất nhập kho lô hàng.';
        } else {
          _finished = false;
          _status = PutawayStatus.waiting;
          _message = '';
        }
      });
      _snack(
        !isFullyReceived
            ? 'Đã nhập một phần lô. Chọn vị trí tiếp theo để nhập phần còn lại.'
            : 'Đã hoàn tất nhập kho lô hàng.',
      );
      if (!isFullyReceived && mounted && !_finished) {
        await _reloadLine();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = (error is InboundOrderException && error.statusCode == 409)
            ? PutawayStatus.conflict
            : PutawayStatus.error;
        _message = 'Không thể xác nhận vị trí nhập kho: $error';
      });
    }
  }

  String _operationKey() =>
      'inbound-${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(1 << 32)}';

  void _snack(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  // ================= Sửa phương án xếp bao =================

  void _applyPlanResult(BagPlanMoveResult result) {
    if (!_canEditPlan || _busy || _finished || !mounted) return;
    setState(() {
      if (result.error != null) {
        _status = PutawayStatus.capacity;
        _message = result.error!;
        return;
      }
      _plan = result.plan;
      _expandedGroups.clear();
      _suggestions =
          BagPutawayPlanner.orderSuggestionsByPlan(_suggestions, result.plan);
    });
  }

  // ================= Giao diện =================

  @override
  Widget build(BuildContext context) {
    final item = _line.item;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundFor(context),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppGradientHeader(
                overline: _line.order.poCode,
                title: item.paddyLotCode ?? _line.order.poCode,
                subtitle:
                    '${_line.order.warehouseName ?? 'Kho #${_line.order.warehouseId}'} · '
                    'còn ${formatKg(item.remainingKg)}',
                leading: IconButton(
                  color: Colors.white,
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.of(context).pop(_changed),
                ),
                trailing: IconButton(
                  color: Colors.white,
                  tooltip: 'Tải lại',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _busy || _finished ? null : _reloadLine,
                ),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
        bottomNavigationBar: _bottomBar(),
      ),
    );
  }

  Widget _body() {
    if (_finished) {
      return const HEmptyState(
        title: 'Đã hoàn tất nhập kho',
        description: 'Đã hoàn tất nhập kho lô hàng.',
        icon: Icons.done_all_rounded,
      );
    }

    final plan = _plan;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        _lifecycleCard(),
        if (_message.isNotEmpty && !_finished) ...[
          const SizedBox(height: 12),
          AppInfoBanner(message: _message, tone: _messageTone),
        ],
        const SizedBox(height: 12),
        if (plan != null && plan.columns.isNotEmpty)
          _bagPlanSection(plan)
        else if (_busy ||
            (_canPrepare &&
                _suggestions.isEmpty &&
                _warehouseLocations.isEmpty &&
                _status == PutawayStatus.waiting))
          _preparingCard()
        else if (_status == PutawayStatus.error)
          _retryCard()
        else
          _suggestionSection(),
      ],
    );
  }

  AppTone get _messageTone {
    switch (_status) {
      case PutawayStatus.error:
      case PutawayStatus.conflict:
        return AppTone.danger;
      case PutawayStatus.split:
      case PutawayStatus.capacity:
        return AppTone.warning;
      case PutawayStatus.suggested:
      case PutawayStatus.waiting:
        return AppTone.info;
    }
  }

  Widget _lifecycleCard() {
    final waitingApproval = _orderStatus == InboundOrderStatuses.submitted;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Phiếu ${_line.order.poCode}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              AppStatusChip(
                label: _line.order.statusName ?? _orderStatus,
                tone: waitingApproval ? AppTone.warning : AppTone.info,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_line.item.productVariantName ?? _line.item.sku ?? 'Lúa nguyên liệu'} · '
            '${_line.sourceLabel}',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondaryFor(context),
            ),
          ),
          if (_line.item.needsQuarantine) ...[
            const SizedBox(height: 10),
            const AppInfoBanner(
              message: 'Lô không đạt kiểm định — chỉ xếp được vào khu cách ly.',
            ),
          ],
          if (waitingApproval) ...[
            const SizedBox(height: 10),
            const AppInfoBanner(
              message:
                  'Phiếu đang chờ người khác phê duyệt. Bạn vẫn có thể xem phương án '
                  'xếp kho bên dưới, nhưng chưa thể thay đổi hoặc xác nhận nhập kho.',
            ),
          ],
          if (!waitingApproval && !_canUpdate) ...[
            const SizedBox(height: 10),
            const AppInfoBanner(
              message:
                  'Bạn chỉ có quyền xem phiếu và phương án xếp kho; các thao tác thay đổi đã bị khóa.',
            ),
          ],
          if (_canUpdate && _actionLabel.isNotEmpty) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _advance,
              icon: const Icon(Icons.play_arrow_rounded),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
              label: Text(_busy ? 'Đang xử lý...' : _actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  /// Đang tự nhận hàng + lấy gợi ý vị trí (thay cho 2 nút thủ công cũ).
  Widget _preparingCard() {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Đang nhận hàng và lấy vị trí gợi ý cho '
              '${formatKg(_line.item.remainingKg)}...',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// Chuỗi tự động thất bại thì cho thử lại — không quay về thao tác từng bước.
  Widget _retryCard() {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chưa lấy được vị trí gợi ý',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _busy || (!_canEditPlan && !_shouldLoadReadOnlyPlan)
                ? null
                : () {
                    _autoPrepared = true;
                    if (_shouldLoadReadOnlyPlan) {
                      _loadPlanPreview();
                    } else {
                      _prepare();
                    }
                  },
            icon: const Icon(Icons.refresh_rounded),
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _bagPlanSection(BagPutawayPlan plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSectionHeader(
                title: 'Phương án xếp nguyên bao',
                icon: Icons.layers_outlined,
              ),
              Text(
                '${plan.bagCount} bao · ${formatKg(plan.totalKg)} · ${plan.columns.length} cột',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const AppInfoBanner(
                message:
                    'LIFO cố định: nhập sau lên đỉnh, lấy trước. STT ưu tiên do hệ '
                    'thống tự tính từ đỉnh xuống đáy.',
                tone: AppTone.info,
              ),
              if (plan.unplacedBagIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                AppInfoBanner(
                  message:
                      'Còn ${plan.unplacedBagIds.length} bao chưa có vị trí. Không thể xác nhận.',
                  tone: AppTone.danger,
                ),
              ],
            ],
          ),
        ),
        for (final column in plan.columns) _bagColumnCard(plan, column),
      ],
    );
  }

  Widget _bagColumnCard(BagPutawayPlan plan, BagPutawayColumn column) {
    final groups = BagPutawayPlanner.columnGroups(column, plan);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ưu tiên ${column.priorityRank ?? plan.columns.indexOf(column) + 1} · ${column.slotCode}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${column.bags.length} bao · ${formatKg(column.totalKg)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Sức chứa: ${formatKg(column.totalKg + column.capacityRemainAfter)} → còn '
            '${formatKg(column.capacityRemainAfter)}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryFor(context),
            ),
          ),
          if ((column.reason ?? '').isNotEmpty)
            Text(
              column.reason!,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryFor(context),
              ),
            ),
          const Divider(height: 18),
          Text(
            '↑ Đỉnh cột · lấy trước',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondaryFor(context),
            ),
          ),
          for (final group in groups) _bagGroupTile(plan, column, group),
          Text(
            '↓ Đáy cột · lấy sau cùng',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondaryFor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bagGroupTile(
    BagPutawayPlan plan,
    BagPutawayColumn column,
    BagDisplayGroup group,
  ) {
    final expanded = _expandedGroups.contains(group.key);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.canvasAlt,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                padding: const EdgeInsets.symmetric(vertical: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brandTintStrong,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  group.priorityLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      group.kind,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondaryFor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: 'Đưa nhóm lên đỉnh',
                visualDensity: VisualDensity.compact,
                onPressed: !_canEditPlan || _busy || group.priorityStart == 1
                    ? null
                    : () => _applyPlanResult(
                          BagPutawayPlanner.moveGroupOrder(
                            plan,
                            column.locationId,
                            group.bagIds,
                            toTop: true,
                          ),
                        ),
                icon: const Icon(Icons.vertical_align_top_rounded, size: 20),
              ),
              IconButton(
                tooltip: 'Đưa nhóm xuống đáy',
                visualDensity: VisualDensity.compact,
                onPressed: !_canEditPlan ||
                        _busy ||
                        group.priorityEnd == column.bags.length
                    ? null
                    : () => _applyPlanResult(
                          BagPutawayPlanner.moveGroupOrder(
                            plan,
                            column.locationId,
                            group.bagIds,
                            toTop: false,
                          ),
                        ),
                icon: const Icon(Icons.vertical_align_bottom_rounded, size: 20),
              ),
              if (group.count > 1)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            if (expanded) {
                              _expandedGroups.remove(group.key);
                            } else {
                              _expandedGroups.add(group.key);
                            }
                          }),
                  child: Text(expanded ? 'Đóng nhóm' : 'Mở nhóm'),
                ),
              SizedBox(
                width: 210,
                child: _columnPicker(
                  plan: plan,
                  currentLocationId: column.locationId,
                  requiredKg: group.count * group.weightKg,
                  pickerKey: 'group-${group.key}',
                  onPick: (target) => _applyPlanResult(
                    BagPutawayPlanner.moveGroupToLocation(
                      plan,
                      group.bagIds,
                      target,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (expanded)
            for (final bag in group.bags.reversed)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 34,
                      child: Text(
                        '${column.bags.length - column.bags.indexWhere((x) => x.id == bag.id)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Bao #${bag.bagNo} · ${formatKg(bag.weightKg)}',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: _columnPicker(
                        plan: plan,
                        currentLocationId: column.locationId,
                        requiredKg: bag.weightKg,
                        pickerKey: 'bag-${bag.id}',
                        dense: true,
                        onPick: (target) => _applyPlanResult(
                          BagPutawayPlanner.moveGroupToLocation(
                            plan,
                            [bag.id],
                            target,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _columnPicker({
    required BagPutawayPlan plan,
    required int currentLocationId,
    required double requiredKg,
    required ValueChanged<int> onPick,
    required String pickerKey,
    bool dense = false,
  }) {
    return DropdownButtonFormField<int>(
      // Khóa theo cột hiện tại: sau khi chuyển bao sang cột khác, Flutter phải
      // dựng lại ô chọn thay vì giữ giá trị cũ của vị trí trong cây widget.
      key: ValueKey('putaway-col-$pickerKey-$currentLocationId'),
      initialValue: currentLocationId,
      isExpanded: true,
      isDense: true,
      decoration: InputDecoration(
        labelText: dense ? 'Cột' : 'Chia / đổi cột',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: [
        for (final candidate in plan.candidateLocations)
          DropdownMenuItem<int>(
            value: candidate.locationId,
            enabled: candidate.locationId == currentLocationId ||
                candidate.capacityAvailableKg >= requiredKg,
            child: Text(
              '${candidate.slotCode}'
              '${candidate.locationId == currentLocationId ? ' (hiện tại)' : ' · còn ${formatKg(candidate.capacityAvailableKg)}'}',
            ),
          ),
      ],
      onChanged: (target) {
        if (target != null && target != currentLocationId) onPick(target);
      },
    );
  }

  Widget _suggestionSection() {
    if (_suggestions.isNotEmpty) {
      final suggestions = _suggestions;
      final remainingLocations = _warehouseLocations
          .where((loc) => !suggestions.any((s) => s.locationId == loc.id))
          .toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionHeader(
            title: 'Vị trí đề xuất',
            icon: Icons.auto_awesome_rounded,
          ),
          for (var i = 0; i < suggestions.length; i++)
            _suggestionCard(suggestions[i], i),
          if (remainingLocations.isNotEmpty) ...[
            const SizedBox(height: 8),
            AppSectionHeader(
              title:
                  'Các khu/cột phù hợp khác trong ${_line.order.warehouseName ?? 'kho'}',
              icon: Icons.grid_view_rounded,
            ),
            for (final location in remainingLocations)
              _warehouseLocationCard(location),
          ],
        ],
      );
    }

    final locations = _warehouseLocations;
    if (locations.isEmpty) {
      return const HEmptyState(
        title: 'Không còn khu/cột phù hợp',
        description:
            'Kho này hiện không có vị trí còn sức chứa đúng điều kiện.',
        icon: Icons.location_off_outlined,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: 'Khu/cột còn chỗ trong ${_line.order.warehouseName ?? 'kho'}',
          icon: Icons.grid_view_rounded,
        ),
        for (final location in locations) _warehouseLocationCard(location),
      ],
    );
  }

  Widget _warehouseLocationCard(StorageLocation location) {
    final selected = location.id == _selectedLocationId && _plan == null;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      color: selected ? AppColors.brandTint : null,
      onTap: !_canEditPlan || _busy
          ? null
          : () => _chooseWarehouseLocation(location),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  location.label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.primary, size: 20),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${location.isQuarantine ? 'Khu cách ly' : 'Khu lưu trữ thường'} · '
            'còn ${formatKg(location.freeCapacityKg)}',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondaryFor(context),
            ),
          ),
          const SizedBox(height: 6),
          _capacityBar(
            location.maxCapacity <= 0
                ? 0
                : location.currentOccupancy / location.maxCapacity,
          ),
        ],
      ),
    );
  }

  Widget _suggestionCard(PutawaySuggestion suggestion, int index) {
    final selected = suggestion.locationId == _selectedLocationId;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      color: selected ? AppColors.brandTint : null,
      onTap:
          !_canEditPlan || _busy ? null : () => _chooseSuggestion(suggestion),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ưu tiên ${index + 1} · ${suggestion.label}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.primary, size: 20),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${suggestion.isQuarantine ? 'Khu cách ly phù hợp chất lượng lô' : (suggestion.categoryMatch ? 'Đúng nhóm hàng' : 'Vị trí dùng chung')}'
            ' · còn ${formatKg(suggestion.availableCapacity)}'
            '${suggestion.canFitWhole ? '' : ' · đề xuất xếp ${formatKg(suggestion.recommendedWeightKg)}'}',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondaryFor(context),
            ),
          ),
          const SizedBox(height: 6),
          _capacityBar(suggestion.occupancyPercent / 100),
          const SizedBox(height: 4),
          Text(
            '${suggestion.occupancyPercent}% đã dùng',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondaryFor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _capacityBar(double ratio) {
    final value = ratio.isNaN ? 0.0 : ratio.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: value.toDouble(),
        minHeight: 7,
        backgroundColor: AppColors.borderFor(context),
      ),
    );
  }

  Widget? _bottomBar() {
    if (_finished || !_canEditPlan) return null;
    final plan = _plan;
    final hasPlan = plan != null && plan.columns.isNotEmpty;
    final locationId = hasPlan
        ? plan.columns.first.locationId
        : (_manualOverride ? _manualLocationId : _selectedLocationId);

    if (!hasPlan && (locationId == null || locationId <= 0)) {
      return null;
    }

    final blocked = hasPlan && plan.unplacedBagIds.isNotEmpty;
    final weightKg = hasPlan ? plan.totalKg : _placementWeightKg;
    final label = hasPlan
        ? 'Xác nhận xếp ${plan.bagCount} bao · ${formatKg(weightKg)}'
        : 'Xác nhận xếp ${formatKg(weightKg)}';

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: FilledButton.icon(
        onPressed: _busy || blocked ? null : _confirmPutaway,
        icon: const Icon(Icons.check_circle_outline_rounded),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        label: Text(_busy ? 'Đang xác nhận...' : label),
      ),
    );
  }
}

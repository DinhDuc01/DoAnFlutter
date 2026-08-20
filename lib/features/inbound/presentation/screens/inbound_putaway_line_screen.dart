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
    if (!_busy) _reloadLine();
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiInboundOrderRepository();
    _line = widget.line;
    _locations = widget.locations;
    _placementWeightKg = _initialWeight();
    // Giống web: không bắt người dùng bấm "Bắt đầu nhận hàng" rồi "Tải vị trí".
    // Vào màn là tự nhận hàng và đẩy thẳng danh sách vị trí được gợi ý.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoPrepare());
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
  bool get _canUpdate =>
      AuthSessionStore.current?.hasPermission('INBOUND_ORDERS', 'UPDATE') ==
      true;

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

  List<StorageLocation> get _warehouseLocations {
    final warehouseId = _line.order.warehouseId;
    final needsQuarantine = _line.item.needsQuarantine;
    final list = _locations
        .where((location) =>
            location.warehouseId == warehouseId &&
            location.isActive &&
            !location.isOutboundStaging &&
            !location.isLockedForOutbound &&
            location.maxCapacity > location.currentOccupancy &&
            location.isQuarantine == needsQuarantine)
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    return list;
  }

  List<StorageLocation> get _manualLocations => _warehouseLocations
      .where((location) => location.id != _selectedLocationId)
      .toList();

  PutawaySuggestion? get _selectedSuggestion {
    for (final suggestion in _suggestions) {
      if (suggestion.locationId == _selectedLocationId) return suggestion;
    }
    return null;
  }

  // ================= Tải dữ liệu =================

  Future<void> _reloadLine() async {
    try {
      final lines = await _repository.getPutawayPending();
      final locations = await _repository.getLocations();
      if (!mounted) return;
      InboundPutawayLine? found;
      for (final line in lines) {
        if (line.item.id == _line.item.id) found = line;
      }
      setState(() {
        if (locations.isNotEmpty) _locations = locations;
        if (found != null) {
          _line = found;
        } else {
          // Dòng đã hoàn tất nhập kho nên không còn trong danh sách chờ.
          _finished = true;
          _status = PutawayStatus.waiting;
          _message = 'Lô này đã hoàn tất nhập kho.';
        }
      });
      await _maybeAutoPrepare();
    } catch (_) {
      // Reload im lặng thất bại thì giữ nguyên màn đang thao tác.
    }
  }

  /// Tự chạy chuỗi nhận hàng rồi lấy gợi ý vị trí — thay cho hai nút thủ công.
  /// Chạy đúng một lần cho mỗi lượt xếp; phiếu chưa được duyệt thì bỏ qua và sẽ
  /// tự chạy khi realtime báo phiếu đã duyệt trên web.
  Future<void> _maybeAutoPrepare() async {
    if (!_canUpdate) return;
    if (!mounted || _busy || _finished || _autoPrepared) return;
    if (!_canPrepare || _line.item.remainingKg <= 0) return;
    if (_suggestions.isNotEmpty || (_plan?.columns.isNotEmpty ?? false)) return;
    _autoPrepared = true;
    await _prepare();
  }

  Future<void> _fetchSuggestions({int? preferredLocationId}) async {
    setState(() => _busy = true);
    try {
      final suggestions = await _repository.getPutawaySuggestions(
        _line.order.id,
        _line.item.id,
      );
      final plan = await _repository.getBagPutawayPlan(
        _line.order.id,
        _line.item.id,
      );
      if (!mounted) return;
      final ordered =
          BagPutawayPlanner.orderSuggestionsByPlan(suggestions, plan);
      PutawaySuggestion? selected;
      for (final suggestion in ordered) {
        if (suggestion.locationId == preferredLocationId) selected = suggestion;
      }
      selected ??= ordered.isEmpty ? null : ordered.first;

      setState(() {
        _busy = false;
        _plan = plan;
        _expandedGroups.clear();
        _suggestions = ordered;
        _selectedLocationId = selected?.locationId;
        if (selected == null) {
          _status = PutawayStatus.capacity;
          _message = 'Không còn vị trí phù hợp đủ sức chứa.';
        } else {
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
        }
      });
    } catch (error) {
      if (!mounted) return;
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
    if (!_canUpdate) return;
    if (_busy || _orderStatus != InboundOrderStatuses.draft) return;
    setState(() => _busy = true);
    try {
      await _repository.submit(_line.order.id);
      _changed = true;
      if (!mounted) return;
      setState(() => _busy = false);
      await _reloadLine();
      _snack(
        'Đã gửi phiếu nhập kho để duyệt. Phê duyệt phiếu chỉ thực hiện trên web.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Không thể gửi duyệt phiếu nhập: $error');
    }
  }

  /// Nhận hàng cho phần còn lại rồi lấy gợi ý vị trí. Khối lượng lấy đúng phần
  /// còn phải nhập (giống web tự động ghi nhận `remaining` sau khi duyệt) nên
  /// không cần ô nhập tay.
  Future<void> _prepare({int? preferredLocationId}) async {
    if (!_canUpdate) return;
    if (_busy) return;
    final weight = _line.item.remainingKg;
    if (weight <= 0) return;

    setState(() => _busy = true);
    try {
      if (_orderStatus == InboundOrderStatuses.approved) {
        await _repository.startReceipt(_line.order.id, _line.item.id);
      }
      if (!_line.item.quantityCaptured) {
        await _repository.recordQuantity(_line.order.id, _line.item.id, weight);
      }
      _changed = true;
      if (!mounted) return;
      setState(() {
        _busy = false;
        _placementWeightKg = weight;
      });
      // Nạp lại dòng để trạng thái phiếu / receiptStatus không còn cũ — lần
      // chạy sau (bấm Thử lại, chọn khu khác) mới không gọi lặp start-receipt.
      await _reloadLine();
      if (!mounted || _finished) return;
      await _fetchSuggestions(preferredLocationId: preferredLocationId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = PutawayStatus.error;
        _message = 'Không nhận được hàng / tải được vị trí gợi ý: $error';
      });
    }
  }

  void _chooseSuggestion(PutawaySuggestion suggestion) {
    setState(() {
      _selectedLocationId = suggestion.locationId;
      _placementWeightKg = suggestion.recommendedWeightKg;
      _manualOverride = false;
      _status = suggestion.canFitWhole
          ? PutawayStatus.suggested
          : PutawayStatus.split;
    });
  }

  Future<void> _chooseWarehouseLocation(StorageLocation location) async {
    if (!_canUpdate) return;
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
    });
    if (_canPrepare) await _prepare(preferredLocationId: location.id);
  }

  void _selectManualLocation(int? locationId) {
    setState(() {
      _manualLocationId = locationId;
      if (locationId == null) return;
      for (final location in _manualLocations) {
        if (location.id == locationId) {
          _placementWeightKg =
              math.min(_line.item.remainingKg, location.freeCapacityKg);
        }
      }
    });
  }

  Future<void> _confirmPutaway() async {
    if (!_canUpdate) return;
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
    if (confirmed != true || !mounted) return;

    final remainingBefore = _line.item.remainingKg;
    setState(() => _busy = true);
    try {
      if (!hasPlan) {
        await _repository.selectPutaway(
          _line.order.id,
          _line.item.id,
          locationId: locationId,
          isOverride: _manualOverride,
          overrideReason: _manualOverride
              ? _overrideReasonController.text.trim()
              : null,
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
        // Còn hàng thì lượt xếp tiếp theo lại tự nhận hàng + lấy gợi ý.
        _autoPrepared = false;
      });
      _snack(
        weightKg < remainingBefore - 0.0001
            ? 'Đã nhập một phần lô. Chọn vị trí tiếp theo để nhập phần còn lại.'
            : 'Đã hoàn tất nhập kho lô hàng.',
      );
      await _reloadLine();
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ================= Sửa phương án xếp bao =================

  void _applyPlanResult(BagPlanMoveResult result) {
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
    return Scaffold(
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
                  onPressed: _busy ? null : _reloadLine,
                ),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
        bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _body() {
    if (_finished) {
      return const HEmptyState(
        title: 'Đã hoàn tất nhập kho',
        description: 'Lô này không còn phần nào chờ xếp vị trí.',
        icon: Icons.done_all_rounded,
      );
    }

    final plan = _plan;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        _lifecycleCard(),
        if (_message.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppInfoBanner(message: _message, tone: _messageTone),
        ],
        const SizedBox(height: 12),
        if (plan != null && plan.columns.isNotEmpty)
          _bagPlanSection(plan)
        else if (_busy && _suggestions.isEmpty)
          _preparingCard()
        else ...[
          if (_status == PutawayStatus.error && _canPrepare) _retryCard(),
          _suggestionSection(),
        ],
        if (_suggestions.isNotEmpty && (plan == null || plan.columns.isEmpty))
          _overrideSection(),
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
                  'Phiếu đang chờ phê duyệt. Việc phê duyệt phiếu nhập chỉ thực '
                  'hiện trên web; sau khi được duyệt, quay lại đây để nhận hàng.',
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
            onPressed: _busy || !_canUpdate
                ? null
                : () {
                    _autoPrepared = true;
                    _prepare();
                  },
            icon: const Icon(Icons.refresh_rounded),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
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
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
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
                onPressed: _busy || group.priorityStart == 1
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
                onPressed: _busy || group.priorityEnd == column.bags.length
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
                plan.capacityRemain(candidate.locationId) + 0.001 >= requiredKg,
            child: Text(
              '${candidate.slotCode} · còn ${formatKg(plan.capacityRemain(candidate.locationId))}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: dense ? 11.5 : 12.5,
                color: candidate.locationId == currentLocationId ||
                        plan.capacityRemain(candidate.locationId) + 0.001 >=
                            requiredKg
                    ? null
                    : AppColors.textTertiary,
              ),
            ),
          ),
      ],
      onChanged: _busy
          ? null
          : (value) {
              if (value == null || value == currentLocationId) return;
              if (plan.capacityRemain(value) + 0.001 < requiredKg) {
                _snack('Cột đã chọn không đủ sức chứa cho ${formatKg(requiredKg)}.');
                return;
              }
              onPick(value);
            },
    );
  }

  Widget _suggestionSection() {
    if (_suggestions.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionHeader(
            title: 'Vị trí đề xuất',
            icon: Icons.place_outlined,
          ),
          for (var index = 0; index < _suggestions.length; index++)
            _suggestionCard(_suggestions[index], index),
        ],
      );
    }

    final locations = _warehouseLocations;
    if (locations.isEmpty) {
      return const HEmptyState(
        title: 'Không còn khu/cột phù hợp',
        description: 'Kho này hiện không có vị trí còn sức chứa đúng điều kiện.',
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
        for (final location in locations)
          AppCard(
            margin: const EdgeInsets.only(bottom: 10),
            onTap: _busy ? null : () => _chooseWarehouseLocation(location),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
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
          ),
      ],
    );
  }

  Widget _suggestionCard(PutawaySuggestion suggestion, int index) {
    final selected = suggestion.locationId == _selectedLocationId;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      color: selected ? AppColors.brandTint : null,
      onTap: _busy ? null : () => _chooseSuggestion(suggestion),
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

  Widget _overrideSection() {
    return AppCard(
      margin: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _manualOverride ? 'Đang ghi đè vị trí' : 'Ghi đè thủ công',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Switch(
                value: _manualOverride,
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                          _manualOverride = value;
                          _manualLocationId = null;
                          _overrideReasonController.clear();
                        }),
              ),
            ],
          ),
          if (_manualOverride) ...[
            const SizedBox(height: 8),
            if (_manualLocations.isEmpty)
              Text(
                'Không còn vị trí khác phù hợp trong kho này.',
                style: TextStyle(color: AppColors.textSecondaryFor(context)),
              )
            else
              DropdownButtonFormField<int>(
                initialValue: _manualLocationId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Vị trí khác trong kho',
                ),
                items: [
                  for (final location in _manualLocations)
                    DropdownMenuItem<int>(
                      value: location.id,
                      child: Text(
                        '${location.label} · còn ${formatKg(location.freeCapacityKg)} · ưu tiên ${location.priority}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                ],
                onChanged: _busy ? null : _selectManualLocation,
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _overrideReasonController,
              enabled: !_busy,
              maxLength: 250,
              decoration: const InputDecoration(
                labelText: 'Lý do ghi đè',
                hintText: 'Nhập lý do chọn ngoài đề xuất',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _bottomBar() {
    if (_finished || !_canUpdate) return null;
    final plan = _plan;
    final hasPlan = plan != null && plan.columns.isNotEmpty;
    if (!hasPlan && _suggestions.isEmpty) return null;

    final label = hasPlan
        ? 'Xác nhận xếp ${plan.bagCount} bao · ${formatKg(plan.totalKg)}'
        : 'Xác nhận xếp ${formatKg(_placementWeightKg)}';
    final blocked = hasPlan && plan.unplacedBagIds.isNotEmpty;

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

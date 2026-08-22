import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../data/milling_repository.dart';
import '../../models/milling_order.dart';
import '../widgets/milling_widgets.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../auth/data/auth_session_store.dart';

/// Phân bổ nguồn lúa cho lệnh xay — bám đúng ma trận của web:
/// - `DRAFT`: giữ lúa lần đầu.
/// - `RESERVED`: phân bổ LẠI lúa (web gọi cùng API reserve).
/// - `IN_PROGRESS`: lệnh đã khóa nguồn, chỉ được XEM các bao đã giữ.
class MillingSourceSelectionScreen extends StatefulWidget {
  const MillingSourceSelectionScreen({
    required this.order,
    required this.repository,
    this.readOnly = false,
    super.key,
  });

  final MillingOrder order;
  final MillingRepository repository;

  /// Mở ở chế độ chỉ xem (màn chi tiết truyền vào khi lệnh đang xay).
  final bool readOnly;

  @override
  State<MillingSourceSelectionScreen> createState() =>
      _MillingSourceSelectionScreenState();
}

class _MillingSourceSelectionScreenState
    extends State<MillingSourceSelectionScreen> {
  bool get _hasUpdatePermission =>
      AuthSessionStore.current?.hasPermission('MILLING_ORDERS', 'UPDATE') ==
      true;

  late Future<MillingSourceSuggestion> _future;
  List<MillingSourceColumn> _columns = const [];
  bool _submitting = false;

  double get _selectedWeight => _columns.fold<double>(
        0,
        (sum, column) => sum + column.totalWeightKg,
      );

  String get _statusCode =>
      (widget.order.statusCode ?? '').trim().toUpperCase();

  bool get _isDraft => _statusCode == 'DRAFT';

  bool get _isReserved => _statusCode == 'RESERVED';

  /// Lệnh đang xay đã khóa nguồn nên luôn chỉ xem, kể cả khi gọi không kèm cờ.
  bool get _isLocked =>
      widget.readOnly ||
      _statusCode == 'IN_PROGRESS' ||
      _statusCode == 'MILLING';

  bool get _canEdit =>
      _hasUpdatePermission && !_isLocked && (_isDraft || _isReserved);

  String get _title {
    if (_isLocked) return 'Nguồn lúa đã giữ';
    return _isReserved ? 'Phân bổ lại lúa' : 'Giữ lúa cho lệnh xay';
  }

  String get _submitLabel =>
      _isReserved ? 'Phân bổ lại lúa' : 'Kiểm tra & giữ lúa';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<MillingSourceSuggestion> _load() async {
    // Lệnh đang xay đã khóa nguồn: đọc bao đã giữ từ chi tiết lệnh. Gọi
    // `source-suggestions` ở trạng thái này sẽ bị backend từ chối (422).
    final suggestion = _isLocked
        ? await widget.repository.getReservedSource(widget.order.id)
        : await widget.repository.getSourceSuggestion(widget.order.id);
    _columns = suggestion.columns;
    return suggestion;
  }

  void _refreshSuggestion() {
    if (_submitting) return;
    final future = _load();
    setState(() {
      _future = future;
    });
  }

  void _setColumn(int index, List<MillingSourceBag> bags) {
    setState(() {
      _columns = [
        for (var i = 0; i < _columns.length; i++)
          i == index
              ? MillingSourceColumn(
                  locationId: _columns[i].locationId,
                  locationCode: _columns[i].locationCode,
                  bags: bags,
                )
              : _columns[i],
      ];
    });
  }

  Future<void> _reserve(MillingSourceSuggestion suggestion) async {
    if (!_hasUpdatePermission ||
        _submitting ||
        _selectedWeight + 0.0005 < suggestion.requiredWeightKg) {
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.repository.reserveOrder(widget.order.id, _columns);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isReserved
                ? 'Đã phân bổ lại lúa cho lệnh xay.'
                : 'Đã giữ bao lúa cho lệnh xay.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      // Bao vừa bị thao tác khác chiếm: web hiện cảnh báo rồi TỰ tải lại nguồn
      // phù hợp — mobile làm y hệt thay vì bắt người dùng bấm lại.
      if (error is ApiException && error.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Một hoặc nhiều bao vừa được người khác giữ. Đang tải lại nguồn phù hợp...',
            ),
          ),
        );
        _refreshSuggestion();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không giữ được bao lúa: $error')),
      );
    } finally {
      if (mounted && _submitting) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Trạng thái ngoài Nháp / Đã giữ lúa / Đang xay thì không có gì để xem.
    if (!_canEdit && !_isLocked) {
      return Scaffold(
        backgroundColor: millingBackground,
        appBar: MillingAppBar(title: _title),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Chỉ phân bổ nguồn lúa được khi lệnh ở trạng thái Nháp hoặc Đã giữ lúa.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: millingBackground,
      appBar: MillingAppBar(title: _title),
      body: FutureBuilder<MillingSourceSuggestion>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const FormSkeleton();
          }
          if (snapshot.hasError) {
            return HErrorState(
              message: 'Không tải được nguồn lúa: ${snapshot.error}',
              onRetry: () {
                final future = _load();
                setState(() {
                  _future = future;
                });
              },
            );
          }
          final suggestion = snapshot.data;
          if (suggestion == null || _columns.isEmpty) {
            return HEmptyState(
              title: _isLocked
                  ? 'Chưa có bao lúa nào được giữ'
                  : 'Không có bao lúa phù hợp',
              description: _isLocked
                  ? 'Lệnh này chưa ghi nhận bao lúa nào ở nguồn.'
                  : 'Kiểm tra kho, giống lúa hoặc trạng thái bao.',
              icon: Icons.inventory_2_outlined,
            );
          }
          final missing = (suggestion.requiredWeightKg - _selectedWeight)
              .clamp(0, double.infinity)
              .toDouble();
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _SummaryCard(
                      order: widget.order,
                      requiredWeightKg: suggestion.requiredWeightKg,
                      selectedWeightKg: _selectedWeight,
                      missingWeightKg: missing,
                    ),
                    const SizedBox(height: 8),
                    if (!_isLocked && !suggestion.isComplete)
                      Card(
                        color: const Color(0xFFFEF3C7),
                        child: ListTile(
                          leading: const Icon(Icons.warning_amber_rounded,
                              color: Color(0xFF92400E)),
                          title: const Text('Nguồn lấy ngay chưa đủ'),
                          subtitle: Text(
                            'Đã gợi ý ${suggestion.suggestedWeightKg.toStringAsFixed(1)} kg, '
                            'còn thiếu ${suggestion.missingWeightKg.toStringAsFixed(1)} kg. '
                            'Hãy đảo bao hoặc bổ sung nguồn khác.',
                          ),
                        ),
                      ),
                    if (!_isLocked && !suggestion.isComplete)
                      const SizedBox(height: 8),
                    if (_isLocked)
                      const Card(
                        child: ListTile(
                          leading: Icon(Icons.lock_outline_rounded),
                          title: Text('Lệnh đang xay đã khóa nguồn lúa'),
                          subtitle: Text(
                            'Chỉ xem lại các bao đã giữ; muốn đổi nguồn thì xử lý trên web.',
                          ),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _submitting ? null : _refreshSuggestion,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Tự động chọn nguồn phù hợp'),
                      ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < _columns.length; i++)
                      _ColumnCard(
                        column: _columns[i],
                        enabled: _canEdit && !_submitting,
                        onChanged: (bags) => _setColumn(i, bags),
                      ),
                  ],
                ),
              ),
              if (_canEdit)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    child: FilledButton(
                      onPressed: _submitting || missing > 0
                          ? null
                          : () => _reserve(suggestion),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: _submitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(missing > 0
                              ? 'Còn thiếu ${missing.toStringAsFixed(1)} kg'
                              : _submitLabel),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(
      {required this.order,
      required this.requiredWeightKg,
      required this.selectedWeightKg,
      required this.missingWeightKg});
  final MillingOrder order;
  final double requiredWeightKg;
  final double selectedWeightKg;
  final double missingWeightKg;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(order.millingCode,
                style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(
                '${order.warehouseName ?? order.warehouseZone} · ${order.riceVarietyName ?? 'Chưa rõ giống'}'),
            const SizedBox(height: 8),
            Text(
                'Cần: ${requiredWeightKg.toStringAsFixed(1)} kg · Đã chọn: ${selectedWeightKg.toStringAsFixed(1)} kg'),
            if (missingWeightKg > 0)
              Text('Còn thiếu: ${missingWeightKg.toStringAsFixed(1)} kg',
                  style: const TextStyle(color: Colors.red)),
          ]),
        ),
      );
}

class _ColumnCard extends StatelessWidget {
  const _ColumnCard({
    required this.column,
    required this.onChanged,
    this.enabled = true,
  });

  final MillingSourceColumn column;
  final ValueChanged<List<MillingSourceBag>> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final selectable = column.bags.where((bag) => bag.selectable).toList();
    final allSelected =
        selectable.isNotEmpty && selectable.every((bag) => bag.selected);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('Cột ${column.locationCode ?? column.locationId}',
                    style: const TextStyle(fontWeight: FontWeight.w900))),
            Text('${column.totalWeightKg.toStringAsFixed(1)} kg'),
          ]),
          if (enabled)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: allSelected,
              title: const Text('Chọn tất cả bao hợp lệ'),
              onChanged: selectable.isEmpty
                  ? null
                  : (_) => onChanged([
                        for (final bag in column.bags)
                          bag.selectable
                              ? bag.copyWith(selected: !allSelected)
                              : bag,
                      ]),
            ),
          for (final bag in column.bags)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: bag.selected,
              title: Text(
                  'Bao #${bag.bagNo} · ${bag.weightKg.toStringAsFixed(1)} kg'),
              subtitle: Text(bag.selectable
                  ? 'Có thể giữ'
                  : 'Không khả dụng: ${bag.status}'),
              onChanged: enabled && bag.selectable
                  ? (_) => onChanged([
                        for (final item in column.bags)
                          item.id == bag.id
                              ? item.copyWith(selected: !item.selected)
                              : item,
                      ])
                  : null,
            ),
        ]),
      ),
    );
  }
}

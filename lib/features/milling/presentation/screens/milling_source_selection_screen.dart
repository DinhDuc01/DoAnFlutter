import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../data/milling_repository.dart';
import '../../models/milling_order.dart';
import '../widgets/milling_widgets.dart';
import '../../../../core/widgets/state_widgets.dart';

class MillingSourceSelectionScreen extends StatefulWidget {
  const MillingSourceSelectionScreen({
    required this.order,
    required this.repository,
    super.key,
  });

  final MillingOrder order;
  final MillingRepository repository;

  @override
  State<MillingSourceSelectionScreen> createState() =>
      _MillingSourceSelectionScreenState();
}

class _MillingSourceSelectionScreenState
    extends State<MillingSourceSelectionScreen> {
  late Future<MillingSourceSuggestion> _future;
  List<MillingSourceColumn> _columns = const [];
  bool _submitting = false;

  double get _selectedWeight => _columns.fold<double>(
        0,
        (sum, column) => sum + column.totalWeightKg,
      );

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<MillingSourceSuggestion> _load() async {
    final suggestion = await widget.repository.getSourceSuggestion(widget.order.id);
    _columns = suggestion.columns;
    return suggestion;
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
    if (_submitting || _selectedWeight + 0.0005 < suggestion.requiredWeightKg) {
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.repository.reserveOrder(widget.order.id, _columns);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã giữ bao lúa cho lệnh xay.')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        final message = error is ApiException && error.statusCode == 409
            ? 'Một hoặc nhiều bao vừa được người khác giữ. Hãy tải lại nguồn lúa.'
            : 'Không giữ được bao lúa: $error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: millingBackground,
      appBar: const MillingAppBar(title: 'Chọn nguồn lúa'),
      body: FutureBuilder<MillingSourceSuggestion>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const FormSkeleton();
          }
          if (snapshot.hasError) {
            return HErrorState(
              message: 'Không tải được nguồn lúa: ${snapshot.error}',
              onRetry: () => setState(() => _future = _load()),
            );
          }
          final suggestion = snapshot.data;
          if (suggestion == null || _columns.isEmpty) {
            return const HEmptyState(
              title: 'Không có bao lúa phù hợp',
              description: 'Kiểm tra kho, giống lúa hoặc trạng thái bao.',
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
                    const SizedBox(height: 12),
                    for (var i = 0; i < _columns.length; i++)
                      _ColumnCard(
                        column: _columns[i],
                        onChanged: (bags) => _setColumn(i, bags),
                      ),
                  ],
                ),
              ),
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
                            : 'Giữ lúa cho lệnh xay'),
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
  const _SummaryCard({required this.order, required this.requiredWeightKg, required this.selectedWeightKg, required this.missingWeightKg});
  final MillingOrder order;
  final double requiredWeightKg;
  final double selectedWeightKg;
  final double missingWeightKg;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(order.millingCode, style: const TextStyle(fontWeight: FontWeight.w900)),
            Text('${order.warehouseName ?? order.warehouseZone} · ${order.riceVarietyName ?? 'Chưa rõ giống'}'),
            const SizedBox(height: 8),
            Text('Cần: ${requiredWeightKg.toStringAsFixed(1)} kg · Đã chọn: ${selectedWeightKg.toStringAsFixed(1)} kg'),
            if (missingWeightKg > 0) Text('Còn thiếu: ${missingWeightKg.toStringAsFixed(1)} kg', style: const TextStyle(color: Colors.red)),
          ]),
        ),
      );
}

class _ColumnCard extends StatelessWidget {
  const _ColumnCard({required this.column, required this.onChanged});
  final MillingSourceColumn column;
  final ValueChanged<List<MillingSourceBag>> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectable = column.bags.where((bag) => bag.selectable).toList();
    final allSelected = selectable.isNotEmpty && selectable.every((bag) => bag.selected);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Cột ${column.locationCode ?? column.locationId}', style: const TextStyle(fontWeight: FontWeight.w900))),
            Text('${column.totalWeightKg.toStringAsFixed(1)} kg'),
          ]),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: allSelected,
            title: const Text('Chọn tất cả bao hợp lệ'),
            onChanged: selectable.isEmpty ? null : (_) => onChanged([
              for (final bag in column.bags)
                bag.selectable ? bag.copyWith(selected: !allSelected) : bag,
            ]),
          ),
          for (final bag in column.bags)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: bag.selected,
              title: Text('Bao #${bag.bagNo} · ${bag.weightKg.toStringAsFixed(1)} kg'),
              subtitle: Text(bag.selectable ? 'Có thể giữ' : 'Không khả dụng: ${bag.status}'),
              onChanged: bag.selectable ? (_) => onChanged([
                for (final item in column.bags)
                  item.id == bag.id ? item.copyWith(selected: !item.selected) : item,
              ]) : null,
            ),
        ]),
      ),
    );
  }
}

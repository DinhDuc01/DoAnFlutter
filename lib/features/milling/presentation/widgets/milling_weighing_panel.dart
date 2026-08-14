import 'package:flutter/material.dart';

import '../../../scale/models/weight_reading.dart';
import '../../../scale/presentation/screens/scale_screen.dart';
import 'milling_widgets.dart';

/// Reusable local weighing UI. It never calls the API or completes an order.
class MillingWeighingPanel extends StatefulWidget {
  const MillingWeighingPanel({
    required this.outputType,
    required this.scaleCode,
    required this.onWeightChanged,
    this.initialWeightKg,
    this.initialBagCount = 0,
    this.enabled = true,
    super.key,
  });

  final String outputType;
  final String scaleCode;
  final double? initialWeightKg;
  final int initialBagCount;
  final bool enabled;
  final ValueChanged<MillingWeighingDraft> onWeightChanged;

  @override
  State<MillingWeighingPanel> createState() => _MillingWeighingPanelState();
}

class _MillingWeighingPanelState extends State<MillingWeighingPanel> {
  late bool _manualMode;
  double? _latestWeightKg;
  int _bagCount = 0;

  @override
  void initState() {
    super.initState();
    _manualMode = true;
    _latestWeightKg = widget.initialWeightKg;
    _bagCount = widget.initialBagCount;
  }

  Future<void> _capture() async {
    final double? weight;
    if (_manualMode) {
      weight = await showManualWeightDialog(
        context,
        productLabel: _label,
      );
    } else {
      final reading = await Navigator.of(context).push<WeightReading>(
        MaterialPageRoute(builder: (_) => const ScaleScreen()),
      );
      if (reading == null || !reading.canApplyToWeighing) {
        return;
      }
      weight = reading.weight;
    }
    if (!mounted || weight == null || !weight.isFinite || weight <= 0) return;
    setState(() {
      _latestWeightKg = weight;
      _bagCount++;
    });
    widget.onWeightChanged(
      MillingWeighingDraft(weightKg: weight, bagCount: _bagCount),
    );
  }

  String get _label => switch (widget.outputType.toUpperCase()) {
        'RICE' => 'gạo',
        'BRAN' => 'cám',
        'BROKEN' => 'tấm',
        _ => 'sản phẩm',
      };

  @override
  Widget build(BuildContext context) => KeyedSubtree(
        key: Key('milling_inline_weighing_panel_${widget.outputType.toLowerCase()}'),
        child: Opacity(
        opacity: widget.enabled ? 1 : .55,
        child: IgnorePointer(
          ignoring: !widget.enabled,
          child: BleScaleCaptureCard(
            scaleCode: widget.scaleCode,
            latestWeightKg: _latestWeightKg,
            instruction: 'Chỉ lưu số cân cục bộ cho đến bước xác nhận kết quả.',
            onCapture: _capture,
            manualMode: _manualMode,
            onModeChanged: (manual) {
              if (mounted) setState(() => _manualMode = manual);
            },
          ),
        ),
        ),
      );
}

class MillingWeighingDraft {
  const MillingWeighingDraft({required this.weightKg, required this.bagCount});

  final double weightKg;
  final int bagCount;
}

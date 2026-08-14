import 'package:flutter/material.dart';

import '../../data/milling_repository.dart';
import '../../models/milling_order.dart';
import '../../models/milling_output_form.dart';
import '../../../scale/models/weight_reading.dart';
import '../../../scale/presentation/screens/scale_screen.dart';
import '../widgets/milling_widgets.dart';
import 'milling_result_confirmation_screen.dart';

class BrokenWeighingScreen extends StatefulWidget {
  const BrokenWeighingScreen({
    required this.order,
    required this.repository,
    this.initialOutputForms = const [],
    super.key,
  });

  final MillingOrder order;
  final MillingRepository repository;
  final List<MillingOutputFormValue> initialOutputForms;

  @override
  State<BrokenWeighingScreen> createState() => _BrokenWeighingScreenState();
}

class _BrokenWeighingScreenState extends State<BrokenWeighingScreen> {
  late List<MillingBag> _bags;
  double? _latestWeightKg;
  late MillingScaleMode _scaleMode;
  late List<MillingOutputFormValue> _outputForms;

  @override
  void initState() {
    super.initState();
    _bags = List.of(widget.order.brokenBags);
    _scaleMode = widget.order.scaleMode;
    _outputForms = List.unmodifiable(widget.initialOutputForms);
  }

  MillingOrder get _currentOrder => widget.order.copyWith(
        brokenBags: _bags,
        scaleMode: _scaleMode,
      );

  Future<void> _captureWeight() async {
    final double? weight;
    if (_scaleMode == MillingScaleMode.iot) {
      final reading = await Navigator.of(context).push<WeightReading>(
        MaterialPageRoute(builder: (_) => const ScaleScreen()),
      );
      weight = reading?.weight;
    } else {
      weight = await showManualWeightDialog(context, productLabel: 'tấm');
    }
    if (!mounted || weight == null || !weight.isFinite || weight <= 0) return;
    final capturedWeight = weight;
    setState(() {
      _latestWeightKg = capturedWeight;
      _bags = [
        ..._bags,
        MillingBag(index: _bags.length + 1, weightKg: capturedWeight),
      ];
    });
  }

  void _continue() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MillingResultConfirmationScreen(
          order: _currentOrder,
          repository: widget.repository,
          initialOutputForms: _nextOutputForms(),
        ),
      ),
    );
  }

  List<MillingOutputFormValue> _nextOutputForms() {
    final adapted = adaptLegacyMillingOutputs([
      LegacyMillingOutputInput(
        type: MillingOutputType.broken,
        productVariantId: _currentOrder.brokenProductVariantId,
        bagWeightsKg: _bags.map((bag) => bag.weightKg).toList(),
      ),
    ]);
    return adapted.isEmpty ? _outputForms : upsertMillingOutput(_outputForms, adapted.single);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: millingBackground,
      appBar: const MillingAppBar(title: 'Cân tấm sau xay'),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          BleScaleCaptureCard(
            scaleCode: widget.order.scaleCode,
            latestWeightKg: _latestWeightKg,
            instruction: 'Cân từng bao tấm. Có thể bỏ qua nếu không phát sinh.',
            onCapture: _captureWeight,
            color: const Color(0xFF7C3AED),
            manualMode: _scaleMode == MillingScaleMode.manual,
            onModeChanged: (manual) => setState(() {
              _scaleMode = manual ? MillingScaleMode.manual : MillingScaleMode.iot;
            }),
          ),
          const SizedBox(height: 10),
          WeighingSummary(
            bagCount: _bags.length,
            totalWeightKg: _currentOrder.totalBrokenKg,
            productLabel: 'tấm',
            color: const Color(0xFF7C3AED),
          ),
          const SizedBox(height: 10),
          BagListCard(
            bags: _bags,
            label: 'Bao tấm',
            color: const Color(0xFF7C3AED),
          ),
        ],
      ),
      bottomNavigationBar: MillingPrimaryButton(
        label: _bags.isEmpty ? 'Bỏ qua tấm' : 'Xác nhận kết quả xay',
        onPressed: _continue,
        color: const Color(0xFF7C3AED),
      ),
    );
  }
}

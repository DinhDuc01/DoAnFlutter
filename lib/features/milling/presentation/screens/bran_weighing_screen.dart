import 'package:flutter/material.dart';

import '../../data/milling_repository.dart';
import '../../models/milling_order.dart';
import '../../models/milling_output_form.dart';
import '../../../scale/models/weight_reading.dart';
import '../../../scale/presentation/screens/scale_screen.dart';
import '../widgets/milling_widgets.dart';
import 'milling_result_confirmation_screen.dart';
import 'broken_weighing_screen.dart';

/// Displays live scale data and the recorded bran by-product bags.
class BranWeighingScreen extends StatefulWidget {
  const BranWeighingScreen({
    required this.order,
    required this.repository,
    this.includeBroken = false,
    this.initialOutputForms = const [],
    super.key,
  });

  final MillingOrder order;
  final MillingRepository repository;
  final bool includeBroken;
  final List<MillingOutputFormValue> initialOutputForms;

  @override
  State<BranWeighingScreen> createState() => _BranWeighingScreenState();
}

class _BranWeighingScreenState extends State<BranWeighingScreen> {
  bool _isSaving = false;
  late List<MillingBag> _bags;
  double? _latestWeightKg;
  late MillingScaleMode _scaleMode;
  late List<MillingOutputFormValue> _outputForms;

  @override
  void initState() {
    super.initState();
    _bags = List<MillingBag>.of(widget.order.branBags);
    _scaleMode = widget.order.scaleMode;
    _outputForms = List.unmodifiable(widget.initialOutputForms);
  }

  MillingOrder get _currentOrder => widget.order.copyWith(
        branBags: _bags,
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
      weight = await showManualWeightDialog(context, productLabel: 'cám');
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

  Future<void> _confirm() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => widget.includeBroken
            ? BrokenWeighingScreen(
                order: _currentOrder,
                repository: widget.repository,
                initialOutputForms: _nextOutputForms(),
              )
            : MillingResultConfirmationScreen(
                order: _currentOrder,
                repository: widget.repository,
                initialOutputForms: _nextOutputForms(),
              ),
      ),
    );
    if (mounted) setState(() => _isSaving = false);
  }

  List<MillingOutputFormValue> _nextOutputForms() {
    final adapted = adaptLegacyMillingOutputs([
      LegacyMillingOutputInput(
        type: MillingOutputType.bran,
        productVariantId: _currentOrder.branProductVariantId,
        bagWeightsKg: _bags.map((bag) => bag.weightKg).toList(),
      ),
    ]);
    return adapted.isEmpty ? _outputForms : upsertMillingOutput(_outputForms, adapted.single);
  }

  @override
  Widget build(BuildContext context) {
    final bags = _bags;
    final order = _currentOrder;
    return Scaffold(
      backgroundColor: millingBackground,
      appBar: const MillingAppBar(title: 'Cân cám sau xay'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
        children: [
          BleScaleCaptureCard(
            scaleCode: widget.order.scaleCode,
            latestWeightKg: _latestWeightKg,
            instruction: 'Đặt bao cám lên cân rồi nhận số ổn định.',
            onCapture: _captureWeight,
            color: millingOrange,
            manualMode: _scaleMode == MillingScaleMode.manual,
            onModeChanged: (manual) => setState(() {
              _scaleMode = manual ? MillingScaleMode.manual : MillingScaleMode.iot;
            }),
          ),
          const SizedBox(height: 10),
          WeighingSummary(
            bagCount: bags.length,
            totalWeightKg: order.totalBranKg,
            productLabel: 'cám',
            color: millingOrange,
          ),
          const SizedBox(height: 10),
          BagListCard(
            bags: bags,
            label: 'Bao cám',
            color: millingOrange,
          ),
        ],
      ),
      bottomNavigationBar: MillingPrimaryButton(
        label:
            widget.includeBroken ? 'Tiếp tục cân tấm' : 'Xác nhận kết quả xay',
        color: millingOrange,
        isLoading: _isSaving,
        onPressed: bags.isEmpty ? null : _confirm,
      ),
    );
  }
}

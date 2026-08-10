import 'package:flutter/material.dart';

import '../../data/milling_repository.dart';
import '../../models/milling_order.dart';
import '../../../scale/models/weight_reading.dart';
import '../../../scale/presentation/screens/scale_screen.dart';
import '../widgets/milling_widgets.dart';
import 'milling_result_confirmation_screen.dart';

class BrokenWeighingScreen extends StatefulWidget {
  const BrokenWeighingScreen({
    required this.order,
    required this.repository,
    super.key,
  });

  final MillingOrder order;
  final MillingRepository repository;

  @override
  State<BrokenWeighingScreen> createState() => _BrokenWeighingScreenState();
}

class _BrokenWeighingScreenState extends State<BrokenWeighingScreen> {
  late List<MillingBag> _bags;
  double? _latestWeightKg;

  @override
  void initState() {
    super.initState();
    _bags = List.of(widget.order.brokenBags);
  }

  MillingOrder get _currentOrder => widget.order.copyWith(brokenBags: _bags);

  Future<void> _captureWeight() async {
    final double? weight;
    if (widget.order.scaleMode == MillingScaleMode.iot) {
      final reading = await Navigator.of(context).push<WeightReading>(
        MaterialPageRoute(builder: (_) => const ScaleScreen()),
      );
      weight = reading?.weight;
    } else {
      weight = await showManualWeightDialog(context, productLabel: 'tấm');
    }
    if (!mounted || weight == null) return;
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
        ),
      ),
    );
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
            manualMode: widget.order.scaleMode == MillingScaleMode.manual,
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

import 'package:flutter/material.dart';

import '../../data/milling_repository.dart';
import '../../models/milling_order.dart';
import '../../../scale/models/weight_reading.dart';
import '../../../scale/presentation/screens/scale_screen.dart';
import '../widgets/milling_widgets.dart';
import 'milling_result_confirmation_screen.dart';

/// Displays live scale data and the recorded bran by-product bags.
class BranWeighingScreen extends StatefulWidget {
  const BranWeighingScreen({
    required this.order,
    required this.repository,
    super.key,
  });

  final MillingOrder order;
  final MillingRepository repository;

  @override
  State<BranWeighingScreen> createState() => _BranWeighingScreenState();
}

class _BranWeighingScreenState extends State<BranWeighingScreen> {
  bool _isSaving = false;
  late List<MillingBag> _bags;
  double? _latestWeightKg;

  @override
  void initState() {
    super.initState();
    _bags = List<MillingBag>.of(widget.order.branBags);
  }

  MillingOrder get _currentOrder => widget.order.copyWith(branBags: _bags);

  Future<void> _captureWeight() async {
    final reading = await Navigator.of(context).push<WeightReading>(
      MaterialPageRoute(builder: (_) => const ScaleScreen()),
    );
    if (!mounted || reading == null) return;
    setState(() {
      _latestWeightKg = reading.weight;
      _bags = [
        ..._bags,
        MillingBag(index: _bags.length + 1, weightKg: reading.weight),
      ];
    });
  }

  Future<void> _confirm() async {
    setState(() => _isSaving = true);
    await widget.repository.saveBranBags(_currentOrder);
    if (!mounted) return;
    setState(() => _isSaving = false);
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
        label: 'Xác nhận kết quả xay',
        color: millingOrange,
        isLoading: _isSaving,
        onPressed: bags.isEmpty ? null : _confirm,
      ),
    );
  }
}

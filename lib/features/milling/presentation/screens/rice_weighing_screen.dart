import 'package:flutter/material.dart';

import '../../data/milling_repository.dart';
import '../../models/milling_order.dart';
import '../../../scale/models/weight_reading.dart';
import '../../../scale/presentation/screens/scale_screen.dart';
import '../widgets/milling_widgets.dart';
import 'bran_weighing_screen.dart';

/// Displays live scale data and the recorded finished-rice bags.
class RiceWeighingScreen extends StatefulWidget {
  const RiceWeighingScreen({
    required this.order,
    required this.repository,
    super.key,
  });

  final MillingOrder order;
  final MillingRepository repository;

  @override
  State<RiceWeighingScreen> createState() => _RiceWeighingScreenState();
}

class _RiceWeighingScreenState extends State<RiceWeighingScreen> {
  bool _isSaving = false;
  late List<MillingBag> _bags;
  double? _latestWeightKg;

  @override
  void initState() {
    super.initState();
    _bags = List<MillingBag>.of(widget.order.riceBags);
  }

  MillingOrder get _currentOrder => widget.order.copyWith(riceBags: _bags);

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

  Future<void> _continue() async {
    setState(() => _isSaving = true);
    await widget.repository.saveRiceBags(_currentOrder);
    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BranWeighingScreen(
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
      appBar: const MillingAppBar(title: 'Cân gạo sau xay'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
        children: [
          BleScaleCaptureCard(
            scaleCode: widget.order.scaleCode,
            latestWeightKg: _latestWeightKg,
            instruction: 'Đặt bao gạo thành phẩm lên cân rồi nhận số ổn định.',
            onCapture: _captureWeight,
          ),
          const SizedBox(height: 10),
          WeighingSummary(
            bagCount: bags.length,
            totalWeightKg: order.totalRiceKg,
            productLabel: 'gạo',
          ),
          const SizedBox(height: 10),
          BagListCard(bags: bags, label: 'Bao gạo'),
        ],
      ),
      bottomNavigationBar: MillingPrimaryButton(
        label: 'Tiếp tục cân cám',
        isLoading: _isSaving,
        onPressed: bags.isEmpty ? null : _continue,
      ),
    );
  }
}

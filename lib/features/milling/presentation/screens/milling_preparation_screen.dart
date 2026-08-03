import 'package:flutter/material.dart';

import '../../../../core/widgets/state_widgets.dart';
import '../../data/api_milling_repository.dart';
import '../../data/milling_repository.dart';
import '../../models/milling_order.dart';
import '../widgets/milling_widgets.dart';
import 'rice_weighing_screen.dart';

/// Loads the active milling order and validates that weighing can start.
class MillingPreparationScreen extends StatefulWidget {
  const MillingPreparationScreen({this.repository, super.key});

  final MillingRepository? repository;

  @override
  State<MillingPreparationScreen> createState() =>
      _MillingPreparationScreenState();
}

class _MillingPreparationScreenState extends State<MillingPreparationScreen> {
  late final MillingRepository _repository;
  late Future<MillingOrder> _orderFuture;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiMillingRepository();
    _orderFuture = _repository.getActiveOrder();
  }

  void _retry() {
    setState(() {
      _orderFuture = _repository.getActiveOrder();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: millingBackground,
      appBar: const MillingAppBar(title: 'Hoàn tất xay & đóng bao'),
      body: FutureBuilder<MillingOrder>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return HErrorState(
              message: 'Không thể tải lệnh xay: ${snapshot.error}',
              onRetry: _retry,
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const FormSkeleton();
          }

          final order = snapshot.data;
          if (order == null) {
            return HErrorState(
              message: 'Server không trả về lệnh xay.',
              onRetry: _retry,
            );
          }

          return Column(
            children: [
              Expanded(
                child: _buildBody(order),
              ),
              MillingPrimaryButton(
                label: 'Bắt đầu cân gạo',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RiceWeighingScreen(
                        order: order,
                        repository: _repository,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(MillingOrder order) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Sau khi xay xong, cân từng bao gạo trước; sau đó cân cám để chốt kết quả mẻ xay.',
            style: TextStyle(
              color: Color(0xFF166534),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _InfoRow(text: 'Lệnh: ${order.millingCode} · ${order.inputLotCode}'),
        const SizedBox(height: 8),
        _InfoRow(
          text:
              'Lúa đầu vào: ${order.inputWeightKg.toStringAsFixed(0)}kg · ${order.warehouseZone} / ${order.locationCode}',
        ),
        const SizedBox(height: 8),
        const _InfoRow(text: 'Cần cân riêng: gạo thành phẩm và cám'),
        const SizedBox(height: 8),
        _InfoRow(text: 'Thiết bị cân: ${order.scaleCode} · đang kết nối'),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8DEE8)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

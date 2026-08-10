import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../data/milling_repository.dart';
import '../../models/milling_order.dart';
import '../widgets/milling_widgets.dart';

/// Summarizes output weights and completes the milling order.
class MillingResultConfirmationScreen extends StatefulWidget {
  const MillingResultConfirmationScreen({
    required this.order,
    required this.repository,
    super.key,
  });

  final MillingOrder order;
  final MillingRepository repository;

  @override
  State<MillingResultConfirmationScreen> createState() =>
      _MillingResultConfirmationScreenState();
}

class _MillingResultConfirmationScreenState
    extends State<MillingResultConfirmationScreen> {
  bool _isCompleting = false;

  Future<void> _complete() async {
    setState(() => _isCompleting = true);
    await widget.repository.completeOrder(widget.order);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            color: millingGreen,
            size: 44,
          ),
          title: const Text('Mẻ xay đã hoàn tất'),
          content: Text(
            '${widget.order.millingCode} đã được chốt với '
            '${widget.order.totalRiceKg.toStringAsFixed(1)}kg gạo và '
            '${widget.order.totalBranKg.toStringAsFixed(1)}kg cám'
            '${widget.order.brokenBags.isEmpty ? '.' : ' và ${widget.order.totalBrokenKg.toStringAsFixed(1)}kg tấm.'}',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.home,
                  (route) => false,
                );
              },
              child: const Text('Về trang chủ'),
            ),
          ],
        );
      },
    );

    if (mounted) setState(() => _isCompleting = false);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Scaffold(
      backgroundColor: millingBackground,
      appBar: const MillingAppBar(title: 'Xác nhận kết quả xay'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: millingGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mẻ ${order.millingCode} đã đủ dữ liệu cân',
                        style: const TextStyle(
                          color: Color(0xFF166534),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Lúa ${order.inputLotCode} · đầu vào ${order.inputWeightKg.toStringAsFixed(0)}kg',
                        style: const TextStyle(
                          color: Color(0xFF15803D),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ResultStat(
                  label: 'Gạo',
                  value: '${order.totalRiceKg.toStringAsFixed(0)}kg',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ResultStat(
                  label: 'Cám',
                  value: '${order.totalBranKg.toStringAsFixed(1)}kg',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ResultStat(
                  label: 'Yield gạo',
                  value: '${order.riceYieldPercent.toStringAsFixed(1)}%',
                ),
              ),
            ],
          ),
          if (order.brokenBags.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ResultStat(
              label: 'Tấm (${order.brokenBags.length} bao)',
              value: '${order.totalBrokenKg.toStringAsFixed(1)}kg',
            ),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CompactBagColumn(
                  title: 'Bao gạo (${order.riceBags.length})',
                  bags: order.riceBags,
                  color: millingGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactBagColumn(
                  title: 'Bao cám (${order.branBags.length})',
                  bags: order.branBags,
                  color: millingOrange,
                ),
              ),
            ],
          ),
          if (order.brokenBags.isNotEmpty) ...[
            const SizedBox(height: 8),
            _CompactBagColumn(
              title: 'Bao tấm (${order.brokenBags.length})',
              bags: order.brokenBags,
              color: const Color(0xFF7C3AED),
            ),
          ],
        ],
      ),
      bottomNavigationBar: MillingPrimaryButton(
        label: 'Hoàn tất mẻ xay',
        isLoading: _isCompleting,
        onPressed: _complete,
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactBagColumn extends StatelessWidget {
  const _CompactBagColumn({
    required this.title,
    required this.bags,
    required this.color,
  });

  final String title;
  final List<MillingBag> bags;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          for (final bag in bags)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Bao ${bag.index}: ${bag.weightKg.toStringAsFixed(1)}kg',
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

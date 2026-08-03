import 'package:flutter/material.dart';

import '../../models/milling_order.dart';

const millingBackground = Color(0xFFF2FBF6);
const millingGreen = Color(0xFF159447);
const millingOrange = Color(0xFFD97706);

/// Shared compact app bar for every milling step.
class MillingAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MillingAppBar({required this.title, super.key});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      leadingWidth: 56,
      leading: Padding(
        padding: const EdgeInsets.all(10),
        child: OutlinedButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: const Icon(
            Icons.arrow_back,
            size: 18,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      titleSpacing: 2,
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
      ),
    );
  }
}

/// Bottom action used to move between milling steps or submit the result.
class MillingPrimaryButton extends StatelessWidget {
  const MillingPrimaryButton({
    required this.label,
    required this.onPressed,
    this.color = millingGreen,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: color,
            disabledBackgroundColor: const Color(0xFF9CA3AF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Opens the BLE scale and summarizes the most recently captured bag.
class BleScaleCaptureCard extends StatelessWidget {
  const BleScaleCaptureCard({
    required this.scaleCode,
    required this.instruction,
    required this.onCapture,
    this.latestWeightKg,
    this.color = millingGreen,
    super.key,
  });

  final String scaleCode;
  final String instruction;
  final VoidCallback onCapture;
  final double? latestWeightKg;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bluetooth_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$scaleCode · Cân Bluetooth',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            latestWeightKg == null
                ? 'Chưa nhận số cân mới'
                : '${latestWeightKg!.toStringAsFixed(3)} kg',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            instruction,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: color,
            ),
            onPressed: onCapture,
            icon: const Icon(Icons.scale_rounded),
            label: const Text('Kết nối cân và nhận số'),
          ),
        ],
      ),
    );
  }
}

/// Shows the number of recorded bags and their accumulated weight.
class WeighingSummary extends StatelessWidget {
  const WeighingSummary({
    required this.bagCount,
    required this.totalWeightKg,
    required this.productLabel,
    this.color = millingGreen,
    super.key,
  });

  final int bagCount;
  final double totalWeightKg;
  final String productLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryBox(
            label: 'Đã cân',
            value: '$bagCount bao',
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryBox(
            label: 'Tổng $productLabel',
            value: '${totalWeightKg.toStringAsFixed(1)} kg',
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lists every bag recorded for a milling output type.
class BagListCard extends StatelessWidget {
  const BagListCard({
    required this.bags,
    required this.label,
    this.color = millingGreen,
    super.key,
  });

  final List<MillingBag> bags;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: bags.length,
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          indent: 12,
          endIndent: 12,
          color: Color(0xFFF1F5F9),
        ),
        itemBuilder: (context, index) {
          final bag = bags[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$label ${bag.index}',
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${bag.weightKg.toStringAsFixed(1)} kg',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

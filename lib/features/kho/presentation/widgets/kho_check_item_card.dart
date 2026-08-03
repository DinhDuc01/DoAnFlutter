import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/kho_check.dart';

class KhoCheckItemCard extends StatelessWidget {
  const KhoCheckItemCard({
    required this.item,
    required this.onActualChanged,
    this.hasError = false,
    this.borderColor,
    super.key,
  });

  final KhoCheckItem item;
  final ValueChanged<String> onActualChanged;
  final bool hasError;
  final Color? borderColor;

  static const _defaultAccent = Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) {
    final activeBorderColor = hasError && item.actualQuantity == null
        ? const Color(0xFFEF4444)
        : borderColor ?? _defaultAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderFor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimaryFor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.sku,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondaryFor(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _QuantityBox(
            label: 'Hệ thống',
            value: item.systemQuantity.toString(),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 82,
            child: Column(
              children: [
                Text(
                  'Thực tế',
                  style: TextStyle(
                    color: AppColors.textSecondaryFor(context),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 32,
                  child: TextFormField(
                    key: ValueKey(
                      'actual_${item.productVariantId}_${item.locationId ?? 0}',
                    ),
                    initialValue: item.actualQuantity?.toString() ?? '',
                    onChanged: onActualChanged,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(
                      color: AppColors.textPrimaryFor(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      hintText: '-',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      filled: true,
                      fillColor: AppColors.surfaceFor(context),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: activeBorderColor,
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: activeBorderColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 42,
            child: hasError && item.actualQuantity == null
                ? const Icon(
                    Icons.error_outline,
                    color: Color(0xFFEF4444),
                    size: 24,
                  )
                : _DifferenceBadge(difference: item.difference),
          ),
        ],
      ),
    );
  }
}

class _QuantityBox extends StatelessWidget {
  const _QuantityBox({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondaryFor(context),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.isDark(context)
                  ? const Color(0xFF111827)
                  : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderFor(context)),
            ),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimaryFor(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DifferenceBadge extends StatelessWidget {
  const _DifferenceBadge({
    required this.difference,
  });

  final int? difference;

  @override
  Widget build(BuildContext context) {
    if (difference == null) {
      return const Text(
        '-',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFFD1D5DB),
          fontWeight: FontWeight.w700,
        ),
      );
    }

    final isNegative = difference! < 0;
    final isPositive = difference! > 0;
    final textColor = isNegative
        ? const Color(0xFFFB2C36)
        : isPositive
            ? AppColors.primaryDark
            : AppColors.textSecondaryFor(context);
    final backgroundColor = isNegative
        ? const Color(0xFFFEF2F2)
        : isPositive
            ? const Color(0xFFEFFDF4)
            : const Color(0xFFF3F4F6);
    final prefix = isPositive ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$prefix$difference',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

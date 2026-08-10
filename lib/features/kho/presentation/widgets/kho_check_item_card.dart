import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/kho_check.dart';

class KhoCheckItemCard extends StatefulWidget {
  const KhoCheckItemCard({
    required this.item,
    required this.onActualChanged,
    this.hasError = false,
    this.borderColor,
    this.selected = true,
    this.onSelectedChanged,
    super.key,
  });

  final KhoCheckItem item;
  final ValueChanged<String> onActualChanged;
  final bool hasError;
  final Color? borderColor;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;

  @override
  State<KhoCheckItemCard> createState() => _KhoCheckItemCardState();
}

class _KhoCheckItemCardState extends State<KhoCheckItemCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.item.actualQuantity?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant KhoCheckItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.item.actualQuantity?.toString() ?? '';
    if (!_controller.text.contains(next) && !_controller.selection.isValid) {
      _controller.text = next;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final accent =
        widget.hasError && widget.selected && item.actualQuantity == null
            ? const Color(0xFFEF4444)
            : widget.borderColor ?? const Color(0xFF8B5CF6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: widget.selected,
            onChanged: widget.onSelectedChanged == null
                ? null
                : (value) => widget.onSelectedChanged!(value ?? false),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimaryFor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.sku} • ${item.unitLabel}',
                  style: TextStyle(
                    color: AppColors.textSecondaryFor(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (widget.selected) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 105,
              child: TextFormField(
                key: ValueKey(
                  'actual_${item.productVariantId}_${item.locationId ?? 0}',
                ),
                controller: _controller,
                onChanged: widget.onActualChanged,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Thực tế',
                  suffixText: item.unitLabel,
                  errorText: widget.hasError && item.actualQuantity == null
                      ? 'Bắt buộc'
                      : null,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: accent, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: accent, width: 2),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

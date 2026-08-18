import 'package:flutter/material.dart';
import '../../../../core/utils/format.dart';
import 'package:stocklite/features/kho/models/stock_take.dart' as legacy;

/// A premium card widget displaying a single [StockTakeLine] in the Stock Take
/// detail screen. It follows the app's design system with subtle elevation,
/// rounded corners, and a responsive layout that adapts to both portrait and
/// landscape orientations.
class StockTakeItemCard extends StatelessWidget {
  const StockTakeItemCard({
    super.key,
    required this.item,
    this.onTap,
  });

  final legacy.StockTakeLine item;
  final VoidCallback? onTap;

  // Helper to format numbers with thousands separator and up to 2 decimals.
  String _formatNumber(num? value) {
    if (value == null) return '-';
    return formatNumber(value);
  }

  Color _severityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'HIGH':
        return Colors.redAccent;
      case 'MEDIUM':
        return Colors.orangeAccent;
      case 'LOW':
        return Colors.yellowAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Product name & QR status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.productVariantName ?? 'Unnamed item',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    item.bags.any((b) => b.scannedByQr) ? Icons.qr_code : Icons.qr_code_scanner,
                    color: item.bags.any((b) => b.scannedByQr) ? Colors.green : Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Body: Quantities & weights
              Row(
                children: [
                  _infoTile('System Qty', _formatNumber(item.systemQuantity)),
                  const VerticalDivider(width: 24),
                  _infoTile('Actual Qty', _formatNumber(item.actualQuantity)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _infoTile('System Bags', '${item.systemBagCount}'),
                  const VerticalDivider(width: 24),
                  _infoTile('Diff', '${(item.actualQuantity ?? 0.0) - item.systemQuantity} kg'),
                ],
              ),
              const SizedBox(height: 12),
              // Variance severity badge
              if (item.varianceSeverity.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _severityColor(item.varianceSeverity).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.varianceSeverity,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _severityColor(item.varianceSeverity),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (item.note != null && item.note!.isNotEmpty) ...[
                const Divider(height: 24),
                Text(
                  'Ghi chú: ${item.note}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Small tile used inside the card to display a label/value pair.
  Widget _infoTile(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

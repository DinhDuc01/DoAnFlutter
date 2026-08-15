import 'package:flutter/material.dart';
import '../../models/stock_take.dart';

class StockTakeCard extends StatelessWidget {
  final StockTakeSummary summary;
  final VoidCallback? onTap;

  const StockTakeCard({required this.summary, this.onTap, super.key});

  Color _statusColor() {
    final code = summary.stockTakeStatusCode?.toUpperCase() ?? '';
    switch (code) {
      case 'DRAFT':
        return const Color(0xFFA0A0A0);
      case 'COUNTING':
        return const Color(0xFF2196F3);
      case 'SUBMITTED':
        return const Color(0xFFFF9800);
      case 'APPROVED':
        return const Color(0xFF4CAF50);
      case 'REJECTED':
        return const Color(0xFFF44336);
      case 'CANCELLED':
        return const Color(0xFF9E9E9E);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(summary.stCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor().withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      summary.stockTakeStatusName ?? summary.stockTakeStatusCode ?? 'Unknown',
                      style: TextStyle(color: _statusColor()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${summary.warehouseName ?? "Kho"} · ${summary.scopeDisplay}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              Text('Ngày tạo: ${summary.createdDate?.toLocal().toString().split(' ').first ?? '-'}'),
              Text('Dòng chênh lệch: ${summary.varianceLineCount}'),
              Text('Tổng chênh lệch (kg): ${summary.netVarianceKg.toStringAsFixed(2)}'),
            ],
          ),
        ),
      ),
    );
  }
}

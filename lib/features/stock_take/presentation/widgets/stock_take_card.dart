import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../models/stock_take.dart';

/// Sắc thái chip trạng thái kiểm kê kho.
AppTone stockTakeTone(String? statusCode) =>
    switch (statusCode?.toUpperCase()) {
      'APPROVED' => AppTone.success,
      'COUNTING' => AppTone.info,
      'SUBMITTED' => AppTone.warning,
      'REJECTED' || 'CANCELLED' => AppTone.danger,
      'DRAFT' => AppTone.neutral,
      _ => AppTone.brand,
    };

/// Thẻ hiển thị một phiếu kiểm kê kho trong danh sách.
class StockTakeCard extends StatelessWidget {
  const StockTakeCard({required this.summary, this.onTap, super.key});

  final StockTakeSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondaryFor(context);
    final statusLabel = summary.stockTakeStatusName ??
        switch (summary.stockTakeStatusCode?.toUpperCase()) {
          'DRAFT' => 'Nháp',
          'COUNTING' => 'Đang đếm',
          'SUBMITTED' => 'Chờ duyệt',
          'APPROVED' => 'Đã duyệt',
          'REJECTED' => 'Từ chối',
          'CANCELLED' => 'Đã hủy',
          _ => summary.stockTakeStatusCode ?? 'Không rõ',
        };

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  summary.stCode,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              AppStatusChip(
                label: statusLabel,
                tone: stockTakeTone(summary.stockTakeStatusCode),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${summary.warehouseName ?? "Kho"} · ${summary.scopeDisplay}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ngày tạo: ${summary.createdDate != null ? formatDate(summary.createdDate) : '-'}'
            '${summary.createdByName?.isNotEmpty == true ? ' • bởi ${summary.createdByName}' : ''}',
            style: TextStyle(fontSize: 12, color: secondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.scale_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  summary.varianceLineCount > 0
                      ? 'Lệch ${summary.netVarianceKg >= 0 ? '+' : ''}${formatKg(summary.netVarianceKg)} • ${summary.varianceLineCount} dòng lệch'
                      : 'Khớp sổ sách (0 dòng lệch)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: summary.varianceLineCount > 0
                        ? (summary.netVarianceKg < 0
                            ? AppColors.danger
                            : AppColors.warning)
                        : AppColors.primary,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
          if (summary.note?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              'Ghi chú: ${summary.note!.trim()}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: secondary),
            ),
          ],
        ],
      ),
    );
  }
}

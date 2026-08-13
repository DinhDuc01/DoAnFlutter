import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_data_view.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/warehouse_report_repository.dart';
import '../../models/warehouse_report.dart';
import '../widgets/report_header.dart';
import '../widgets/report_summary_cards.dart';
import '../widgets/top_inbound_products_card.dart';
import '../widgets/weekly_activity_chart_card.dart';

/// Màn hình Báo cáo Thống kê Kho (Reports Screen).
/// Hiển thị thông số tổng lượng hàng nhập/xuất/tồn kho, biểu đồ cột biểu diễn biến động tuần và danh sách sản phẩm nhập kho nhiều nhất.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({this.repository, super.key});

  final WarehouseReportRepository? repository;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // Repository quản lý việc lấy dữ liệu báo cáo thống kê kho (hiện dùng dữ liệu mock)
  late final WarehouseReportRepository _repository;

  static const Set<String> _entities = {
    'Inventory',
    'InventoryTransaction',
    'InboundOrder',
    'OutboundOrder',
    'Product',
    'ProductVariant',
    'Warehouse',
    'Location',
    'Alert',
    'PaddyLot',
  };

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? MockWarehouseReportRepository();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        child: RealtimeDataView<WarehouseReport>(
          loader: _repository.getWarehouseReport,
          entities: _entities,
          errorBuilder: (context, error, retry) =>
              const Center(child: Text('Không tải được thống kê kho')),
          builder: (context, report) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  // Tiêu đề đầu trang hiển thị tên kho và ngày thống kê
                  ReportHeader(report: report),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Các thẻ tóm tắt (Tổng nhập, Tổng xuất, Tồn kho)
                        ReportSummaryCards(report: report),
                        const SizedBox(height: 12),
                        // Biểu đồ hoạt động theo tuần (Weekly Chart)
                        WeeklyActivityChartCard(
                            activities: report.weeklyActivities),
                        const SizedBox(height: 12),
                        // Danh sách sản phẩm nhập kho nhiều nhất (Top Products)
                        TopThuMuaProductsCard(
                            products: report.topThuMuaProducts),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

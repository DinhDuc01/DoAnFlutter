import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/warehouse_report_repository.dart';
import '../../models/warehouse_report.dart';
import '../widgets/report_bottom_bar.dart';
import '../widgets/report_header.dart';
import '../widgets/report_summary_cards.dart';
import '../widgets/top_inbound_products_card.dart';
import '../widgets/weekly_activity_chart_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final WarehouseReportRepository _repository = MockWarehouseReportRepository();

  late final Future<WarehouseReport> _reportFuture;

  @override
  void initState() {
    super.initState();
    // API_SWAP: This is where the screen requests warehouse report data.
    _reportFuture = _repository.getWarehouseReport();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundStart,
      body: SafeArea(
        child: FutureBuilder<WarehouseReport>(
          future: _reportFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text('Không tải được thống kê kho'));
            }

            final report = snapshot.data!;

            return SingleChildScrollView(
              child: Column(
                children: [
                  ReportHeader(report: report),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ReportSummaryCards(report: report),
                        const SizedBox(height: 12),
                        WeeklyActivityChartCard(activities: report.weeklyActivities),
                        const SizedBox(height: 12),
                        TopInboundProductsCard(products: report.topInboundProducts),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: const ReportBottomBar(),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/operation_history_repository.dart';
import '../../data/api_operation_history_repository.dart';
import '../../models/operation_history.dart';
import '../widgets/operation_history_bottom_bar.dart';
import '../widgets/operation_history_card.dart';
import '../widgets/operation_history_header.dart';

/// Màn hình Lịch sử hoạt động (Operation History Screen).
/// Hiển thị danh sách nhật ký ghi nhận các phiên Nhập kho, Xuất kho và Kiểm kho đã diễn ra trước đó.
class OperationHistoryScreen extends StatefulWidget {
  const OperationHistoryScreen({this.repository, super.key});

  final OperationHistoryRepository? repository;

  @override
  State<OperationHistoryScreen> createState() => _OperationHistoryScreenState();
}

class _OperationHistoryScreenState extends State<OperationHistoryScreen> {
  // Repository loads the signed-in user's activity log from the API.
  late final OperationHistoryRepository _repository;

  late final Future<List<OperationHistory>> _historiesFuture;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiOperationHistoryRepository();
    _historiesFuture = _repository.getHistories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        child: FutureBuilder<List<OperationHistory>>(
          future: _historiesFuture,
          builder: (context, snapshot) {
            final count = snapshot.data?.length ?? 0;

            return Column(
              children: [
                // Header lịch sử hiển thị kèm theo tổng số lượng bản ghi
                OperationHistoryHeader(count: count),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      // Hiển thị vòng xoay trong lúc tải dữ liệu lịch sử
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // Thông báo lỗi nếu thất bại
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text('Không tải được lịch sử thao tác'),
                        );
                      }

                      final histories =
                          snapshot.data ?? const <OperationHistory>[];

                      // Hiển thị nếu danh sách lịch sử trống
                      if (histories.isEmpty) {
                        return const Center(child: Text('Chưa có giao dịch'));
                      }

                      // Vẽ danh sách lịch sử sử dụng ListView.separated
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: histories.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return OperationHistoryCard(
                              history: histories[index]);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const OperationHistoryBottomBar(),
    );
  }
}

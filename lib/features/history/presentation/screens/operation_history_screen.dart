import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/operation_history_repository.dart';
import '../../models/operation_history.dart';
import '../widgets/operation_history_bottom_bar.dart';
import '../widgets/operation_history_card.dart';
import '../widgets/operation_history_header.dart';

class OperationHistoryScreen extends StatefulWidget {
  const OperationHistoryScreen({super.key});

  @override
  State<OperationHistoryScreen> createState() => _OperationHistoryScreenState();
}

class _OperationHistoryScreenState extends State<OperationHistoryScreen> {
  final OperationHistoryRepository _repository = MockOperationHistoryRepository();

  late final Future<List<OperationHistory>> _historiesFuture;

  @override
  void initState() {
    super.initState();
    // API_SWAP: This is where the screen requests operation history data.
    _historiesFuture = _repository.getHistories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundStart,
      body: SafeArea(
        child: FutureBuilder<List<OperationHistory>>(
          future: _historiesFuture,
          builder: (context, snapshot) {
            final count = snapshot.data?.length ?? 0;

            return Column(
              children: [
                OperationHistoryHeader(count: count),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return const Center(
                          child: Text('Không tải được lịch sử thao tác'),
                        );
                      }

                      final histories = snapshot.data ?? const <OperationHistory>[];
                      if (histories.isEmpty) {
                        return const Center(child: Text('Chưa có giao dịch'));
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: histories.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return OperationHistoryCard(history: histories[index]);
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

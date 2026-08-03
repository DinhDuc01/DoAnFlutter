import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_service.dart';
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

  List<OperationHistory>? _histories;
  Object? _error;
  bool _loading = true;
  int _generation = 0;
  StreamSubscription<Set<String>>? _realtimeSub;

  static const Set<String> _entities = {
    'InventoryTransaction',
    'ActivityLog',
    'AuditLog',
    'InboundOrder',
    'OutboundOrder',
  };

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiOperationHistoryRepository();
    _realtimeSub =
        RealtimeService.instance.onEntitiesChanged.listen(_onEntitiesChanged);
    // _loading mặc định true -> UI hiện loading ngay, không setState trong initState.
    _load(showLoading: false);
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  void _onEntitiesChanged(Set<String> changed) {
    if (!mounted) return;
    if (changed.any(_entities.contains)) _load(showLoading: false);
  }

  Future<void> _load({required bool showLoading}) async {
    final generation = ++_generation;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await _repository.getHistories();
      if (!mounted || generation != _generation) return;
      setState(() {
        _histories = data;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      // Chỉ hiện lỗi khi chưa có dữ liệu; reload im lặng lỗi thì giữ danh sách cũ.
      if (_histories == null) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _histories?.length ?? 0;
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        child: Column(
          children: [
            // Header lịch sử hiển thị kèm theo tổng số lượng bản ghi
            OperationHistoryHeader(count: count),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
      bottomNavigationBar: const OperationHistoryBottomBar(),
    );
  }

  Widget _buildContent() {
    // Hiển thị vòng xoay chỉ ở lần tải đầu tiên.
    if (_loading && _histories == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _histories == null) {
      return const Center(child: Text('Không tải được lịch sử thao tác'));
    }

    final histories = _histories ?? const <OperationHistory>[];
    if (histories.isEmpty) {
      return const Center(child: Text('Chưa có giao dịch'));
    }

    return RefreshIndicator(
      onRefresh: () => _load(showLoading: false),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: histories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return OperationHistoryCard(history: histories[index]);
        },
      ),
    );
  }
}

// Stock Take Detail Screen (Read‑Only)
import 'package:flutter/material.dart';
import '../../data/api_stock_take_repository.dart';
import '../../data/stock_take_repository.dart';
import '../../../../core/api/api_client.dart';

import '../widgets/stock_take_item_card.dart';

import 'package:stocklite/features/kho/models/stock_take.dart' as legacy;

class StockTakeDetailScreen extends StatefulWidget {
  const StockTakeDetailScreen({this.stockTakeId, this.repository, super.key});

  final int? stockTakeId;
  final StockTakeRepository? repository;

  @override
  State<StockTakeDetailScreen> createState() => _StockTakeDetailScreenState();
}

class _StockTakeDetailScreenState extends State<StockTakeDetailScreen> {
  late final int _id;
  late final StockTakeRepository _repo;
  legacy.StockTakeDetail? _detail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? ApiStockTakeRepository();
    // Expect the ID passed via route arguments
    final args = ModalRoute.of(context)!.settings.arguments;
    _id = args is int ? args : (args as Map)['id'];
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final d = await _repo.getStockTakeDetail(_id);
      setState(() {
        _detail = d;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${e.message} (code ${e.statusCode})')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết Kiểm kê kho'),
        backgroundColor: const Color(0xFF00A76F),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _detail == null
              ? const Center(child: Text('Không tìm thấy dữ liệu'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mã: ${_detail!.code}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Kho: ${_detail!.warehouseName}'),
                      Text('Phạm vi: ${_detail!.scopeDisplay}'),
                      Text('Trạng thái: ${_detail!.statusName}'),
                      Text('Ngày tạo: ${_detail!.createdDate != null ? _detail!.createdDate!.toLocal().toString().split(' ').first : '-'}'),
                      const SizedBox(height: 12),
                      Text('Tổng số bao: ${_detail!.totalBags}'),
                      Text('Đã đếm: ${_detail!.countedBags} / ${_detail!.totalBags} bao'),
                      const Divider(height: 24),
                      const Text('Các dòng chi tiết:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._detail!.lines.map((item) => StockTakeItemCard(item: item)).toList(),
                    ],
                  ),
                ),
    );
  }
}




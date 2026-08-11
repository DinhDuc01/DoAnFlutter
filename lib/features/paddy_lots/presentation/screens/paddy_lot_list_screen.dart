import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/paddy_lot_repository.dart';
import '../../models/paddy_lot.dart';
import 'paddy_lot_detail_screen.dart';

class PaddyLotListScreen extends StatefulWidget {
  const PaddyLotListScreen({this.repository, super.key});

  final PaddyLotRepository? repository;

  @override
  State<PaddyLotListScreen> createState() => _PaddyLotListScreenState();
}

class _PaddyLotListScreenState extends State<PaddyLotListScreen> {
  late final PaddyLotRepository _repository;
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<PaddyLotSummary>? _lots;
  Object? _error;
  String _query = '';
  String? _type;
  String? _warehouse;
  String? _status;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiPaddyLotRepository();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _lots = null;
      _error = null;
    });
    try {
      final lots = await _repository.getLots();
      if (!mounted) return;
      setState(() => _lots = lots);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = value.trim().toLowerCase());
    });
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _type = null;
      _warehouse = null;
      _status = null;
    });
  }

  List<PaddyLotSummary> get _filtered {
    final lots = _lots ?? const <PaddyLotSummary>[];
    return lots.where((lot) {
      final haystack = [
        lot.lotCode,
        lot.sku,
        lot.productName,
        lot.riceVarietyName,
      ].whereType<String>().join(' ').toLowerCase();
      return (_query.isEmpty || haystack.contains(_query)) &&
          (_type == null || lot.lotType == _type) &&
          (_warehouse == null || lot.warehouseName == _warehouse) &&
          (_status == null || lot.statusName == _status);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        child: Column(
          children: [
            AppGradientHeader(
              title: 'Lô & truy vết',
              subtitle: 'Theo dõi nguồn gốc lúa, gạo và phụ phẩm',
              leading: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                color: Colors.white,
                icon: const Icon(Icons.arrow_back),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pushNamed(
                      AppRoutes.scanQr,
                    ),
                    color: Colors.white,
                    tooltip: 'Quét QR lô',
                    icon: const Icon(Icons.qr_code_scanner),
                  ),
                  IconButton(
                    onPressed: _load,
                    color: Colors.white,
                    tooltip: 'Tải lại',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_lots == null && _error == null) return const ListSkeleton();
    if (_error != null) return _errorState(_error!);
    final lots = _lots!;
    if (lots.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            HEmptyState(
              title: 'Chưa có lô hàng',
              description: 'Backend chưa trả về lô lúa, gạo hoặc phụ phẩm nào.',
              icon: Icons.inventory_2_outlined,
            ),
          ],
        ),
      );
    }
    final filtered = _filtered;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          _Summary(lots: lots),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: _onSearch,
            decoration: const InputDecoration(
              labelText: 'Tìm mã lô, SKU hoặc giống lúa',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 10),
          _Filters(
            lots: lots,
            type: _type,
            warehouse: _warehouse,
            status: _status,
            onType: (value) => setState(() => _type = value),
            onWarehouse: (value) => setState(() => _warehouse = value),
            onStatus: (value) => setState(() => _status = value),
            onClear: _clearFilters,
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            const HEmptyState(
              title: 'Không tìm thấy lô phù hợp',
              description: 'Thử thay đổi từ khóa hoặc xóa bộ lọc.',
              icon: Icons.filter_alt_off_outlined,
            )
          else
            for (final lot in filtered)
              _LotCard(
                lot: lot,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PaddyLotDetailScreen(
                      lotId: lot.id,
                      repository: _repository,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _errorState(Object error) {
    if (error is PaddyLotException) {
      if (error.statusCode == 401) {
        return _AccessState(
          icon: Icons.lock_outline,
          title: 'Phiên đăng nhập không hợp lệ',
          message: error.message,
          onRetry: _load,
        );
      }
      if (error.statusCode == 403) {
        return _AccessState(
          icon: Icons.gpp_bad_outlined,
          title: 'Không có quyền xem lô',
          message: error.message,
          onRetry: _load,
        );
      }
      if (error.isTransient) {
        return HNetworkState(message: error.message, onRetry: _load);
      }
    }
    return HErrorState(
        message: 'Không tải được danh sách lô: $error', onRetry: _load);
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.lots});
  final List<PaddyLotSummary> lots;

  @override
  Widget build(BuildContext context) {
    final paddy = lots.where((lot) => lot.lotType.toUpperCase() == 'PADDY');
    final rice = lots.where((lot) => lot.lotType.toUpperCase() == 'RICE');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Số liệu từ danh sách đã tải',
          style: TextStyle(
              fontSize: 12, color: AppColors.textSecondaryFor(context)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _Metric(label: 'Tổng lô', value: '${lots.length}')),
            const SizedBox(width: 8),
            Expanded(
              child: _Metric(
                label: 'Lúa',
                value:
                    '${paddy.fold<double>(0, (sum, lot) => sum + lot.remainingWeightKg).toStringAsFixed(0)} kg',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Metric(
                label: 'Gạo',
                value:
                    '${rice.fold<double>(0, (sum, lot) => sum + lot.remainingWeightKg).toStringAsFixed(0)} kg',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondaryFor(context))),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.lots,
    required this.type,
    required this.warehouse,
    required this.status,
    required this.onType,
    required this.onWarehouse,
    required this.onStatus,
    required this.onClear,
  });
  final List<PaddyLotSummary> lots;
  final String? type;
  final String? warehouse;
  final String? status;
  final ValueChanged<String?> onType;
  final ValueChanged<String?> onWarehouse;
  final ValueChanged<String?> onStatus;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final types = lots.map((lot) => lot.lotType).toSet().toList()..sort();
    final warehouses = lots
        .map((lot) => lot.warehouseName)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    final statuses = lots
        .map((lot) => lot.statusName)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _Dropdown(
                    label: 'Loại lô',
                    value: type,
                    values: types,
                    onChanged: onType)),
            const SizedBox(width: 8),
            Expanded(
                child: _Dropdown(
                    label: 'Kho',
                    value: warehouse,
                    values: warehouses,
                    onChanged: onWarehouse)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _Dropdown(
                    label: 'Trạng thái',
                    value: status,
                    values: statuses,
                    onChanged: onStatus)),
            TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear_all),
                label: const Text('Xóa lọc')),
          ],
        ),
      ],
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown(
      {required this.label,
      required this.value,
      required this.values,
      required this.onChanged});
  final String label;
  final String? value;
  final List<String> values;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final item in values)
            DropdownMenuItem(
                value: item, child: Text(item, overflow: TextOverflow.ellipsis))
        ],
        onChanged: onChanged,
      );
}

class _LotCard extends StatelessWidget {
  const _LotCard({required this.lot, required this.onTap});
  final PaddyLotSummary lot;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final reference = lot.sourceReceiptId != null
        ? 'Phiếu mua #${lot.sourceReceiptId}'
        : lot.sourceMillingOrderId != null
            ? 'Lệnh xay #${lot.sourceMillingOrderId}'
            : 'Không có chứng từ nguồn';
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(lot.lotCode,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900))),
              AppStatusChip(
                  label: lot.statusName ?? 'Chưa rõ',
                  tone: lot.needsAttention ? AppTone.warning : AppTone.success),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              '${_lotType(lot.lotType)} • ${lot.sku ?? lot.productName ?? lot.riceVarietyName ?? 'Chưa có sản phẩm'}'),
          const SizedBox(height: 6),
          Text(reference,
              style: TextStyle(
                  color: AppColors.textSecondaryFor(context), fontSize: 12)),
          Text(
              '${lot.warehouseName ?? 'Chưa rõ kho'} • ${lot.locationCode ?? 'Chưa xếp vị trí'}',
              style: TextStyle(
                  color: AppColors.textSecondaryFor(context), fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.scale_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('${lot.remainingWeightKg.toStringAsFixed(1)} kg còn lại',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              if (lot.qualityStatus != null)
                AppStatusChip(
                    label: lot.qualityStatus!,
                    tone: lot.needsAttention ? AppTone.warning : AppTone.info),
              const Icon(Icons.chevron_right),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccessState extends StatelessWidget {
  const _AccessState(
      {required this.icon,
      required this.title,
      required this.message,
      required this.onRetry});
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: AppColors.warning),
              const SizedBox(height: 14),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
}

String _lotType(String value) => switch (value.toUpperCase()) {
      'PADDY' => 'Lúa',
      'RICE' => 'Gạo',
      'BYPRODUCT' => 'Phụ phẩm',
      _ => value,
    };

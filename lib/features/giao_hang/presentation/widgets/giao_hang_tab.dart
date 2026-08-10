import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_data_view.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/api_giao_hang_repository.dart';
import '../../models/giao_hang_receipt.dart';
import '../screens/giao_hang_screen.dart';

class GiaoHangTab extends StatefulWidget {
  const GiaoHangTab({super.key});

  @override
  State<GiaoHangTab> createState() => _GiaoHangTabState();
}

class _GiaoHangTabState extends State<GiaoHangTab> {
  final ApiGiaoHangRepository _repository = ApiGiaoHangRepository();
  final RealtimeDataController _controller = RealtimeDataController();
  Future<List<SalesOrderDraftSummary>>? _draftFuture;
  bool _showDrafts = false;

  static const Set<String> _entities = {
    'OutboundOrder',
    'SalesOrder',
    'Inventory',
    'InventoryTransaction',
  };

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.backgroundFor(context),
      child: Column(
        children: [
          AppGradientHeader(
            title: 'Bán hàng (xuất kho)',
            subtitle: 'Hàng có thể bán và phiếu bán nháp',
            trailing: IconButton(
              onPressed: _controller.reload,
              color: Colors.white,
              icon: const Icon(Icons.refresh),
              tooltip: 'Tải lại',
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.inventory_2_outlined),
                  label: Text('Hàng có thể bán'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.drafts_outlined),
                  label: Text('Phiếu bán nháp'),
                ),
              ],
              selected: {_showDrafts},
              onSelectionChanged: (value) {
                setState(() {
                  _showDrafts = value.first;
                  if (_showDrafts) {
                    _draftFuture = _repository.getDraftSalesOrders();
                  }
                });
              },
            ),
          ),
          Expanded(
            child: _showDrafts
                ? FutureBuilder<List<SalesOrderDraftSummary>>(
                    future: _draftFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const ListSkeleton();
                      }
                      if (snapshot.hasError) {
                        return HErrorState(
                          message:
                              'Không tải được phiếu bán nháp: ${snapshot.error}',
                          onRetry: () => setState(() {
                            _draftFuture = _repository.getDraftSalesOrders();
                          }),
                        );
                      }
                      final drafts = snapshot.data ?? const [];
                      if (drafts.isEmpty) {
                        return const HEmptyState(
                          title: 'Chưa có phiếu bán nháp',
                          description: 'Đơn bán mới tạo sẽ xuất hiện tại đây.',
                          icon: Icons.drafts_outlined,
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: drafts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final draft = drafts[index];
                          return AppCard(
                            padding: EdgeInsets.zero,
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.fromLTRB(14, 6, 14, 6),
                              title: Text(draft.code,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              subtitle: Text(
                                  '${draft.customerName}\n${draft.status}'),
                              isThreeLine: true,
                              trailing: Text(
                                '${draft.totalAmount.toStringAsFixed(0)} đ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryDark),
                              ),
                              onTap: () => showModalBottomSheet<void>(
                                context: context,
                                showDragHandle: true,
                                builder: (sheetContext) => SafeArea(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(draft.code,
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 8),
                                        Text(
                                            '${draft.customerName} • ${draft.status}'),
                                        const SizedBox(height: 16),
                                        FilledButton(
                                          onPressed: draft.id <= 0
                                              ? null
                                              : () async {
                                                  await _repository
                                                      .confirmSalesOrder(
                                                          draft.id);
                                                  if (sheetContext.mounted) {
                                                    Navigator.pop(sheetContext);
                                                  }
                                                  if (mounted) {
                                                    setState(() {
                                                      _draftFuture = _repository
                                                          .getDraftSalesOrders();
                                                    });
                                                  }
                                                },
                                          child: const Text('Chốt phiếu'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  )
                : RealtimeDataView<List<GiaoHangReceipt>>(
                    loader: _repository.getAvailableReceipts,
                    controller: _controller,
                    entities: _entities,
                    loadingBuilder: (_) => const ListSkeleton(),
                    errorBuilder: (context, error, retry) => HErrorState(
                      message: 'Không tải được hàng có thể bán: $error',
                      onRetry: retry,
                    ),
                    builder: (context, receipts) {
                      if (receipts.isEmpty) {
                        return const HEmptyState(
                          title: 'Không có hàng để bán',
                          description:
                              'Tất cả sản phẩm hiện có tồn khả dụng bằng 0.',
                          icon: Icons.local_shipping_outlined,
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: receipts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final receipt = receipts[index];
                          return AppCard(
                            padding: EdgeInsets.zero,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => GiaoHangScreen(
                                  initialReceipt: receipt,
                                ),
                              ),
                            ),
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.fromLTRB(12, 6, 12, 6),
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.infoTint,
                                child: Icon(
                                  Icons.point_of_sale_outlined,
                                  color: AppColors.info,
                                ),
                              ),
                              title: Text(
                                receipt.productName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                              subtitle: Text(
                                '${receipt.sku} • ${receipt.warehouseName}'
                                '${receipt.locationCode == null ? '' : ' / ${receipt.locationCode}'}',
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${receipt.currentStock}',
                                    style: const TextStyle(
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const Text('bao khả dụng',
                                      style: TextStyle(fontSize: 10)),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

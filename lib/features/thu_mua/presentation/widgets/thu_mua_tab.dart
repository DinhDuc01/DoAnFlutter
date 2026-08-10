import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_service.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/purchase_schedule_repository.dart';
import '../../data/api_thu_mua_repository.dart';
import '../../models/purchase_schedule.dart';
import '../../models/thu_mua_receipt.dart';
import '../screens/thu_mua_screen.dart';

enum _ThuMuaSection { schedules, receipts, drafts }

class ThuMuaTab extends StatefulWidget {
  const ThuMuaTab({super.key});

  @override
  State<ThuMuaTab> createState() => ThuMuaTabState();
}

class ThuMuaTabState extends State<ThuMuaTab> with WidgetsBindingObserver {
  final PurchaseScheduleRepository _repository = PurchaseScheduleRepository();
  final ApiThuMuaRepository _receiptRepository = ApiThuMuaRepository();
  Future<List<PurchaseSchedule>>? _schedulesFuture;
  List<ThuMuaDraftSummary> _drafts = const [];
  List<ThuMuaReceiptSummary> _receipts = const [];
  Object? _draftError;
  Object? _receiptError;
  bool _isLoadingDrafts = false;
  bool _isLoadingReceipts = false;
  StreamSubscription<Set<String>>? _entitySubscription;
  Timer? _entityRefreshTimer;
  _ThuMuaSection _section = _ThuMuaSection.schedules;

  static const _refreshEntities = {
    'PaddyPurchaseSchedule',
    'PaddyPurchaseReceipt',
    'InboundOrder',
    'PaddyLot',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedulesFuture = _loadSchedules();
    _entitySubscription = RealtimeService.instance.onEntitiesChanged.listen(
      (changed) {
        if (changed.any(_refreshEntities.contains)) {
          _entityRefreshTimer?.cancel();
          _entityRefreshTimer = Timer(
            const Duration(milliseconds: 350),
            _reload,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entityRefreshTimer?.cancel();
    _entitySubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _reload();
    }
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _schedulesFuture = _loadSchedules();
    });
    if (_section == _ThuMuaSection.drafts) _refreshDrafts();
    if (_section == _ThuMuaSection.receipts) _refreshReceipts();
  }

  Future<List<PurchaseSchedule>> _loadSchedules() =>
      _repository.getSchedules().timeout(const Duration(seconds: 12));

  Future<List<ThuMuaDraftSummary>> _loadDrafts() async {
    debugPrint('[ThuMua] _loadDrafts start');
    try {
      final rows = await _receiptRepository
          .getDraftReceipts()
          .timeout(const Duration(seconds: 12));
      debugPrint('[ThuMua] _loadDrafts success count=${rows.length}');
      return rows;
    } catch (error, stack) {
      debugPrint('[ThuMua] _loadDrafts error=$error');
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }

  Future<void> _refreshReceipts() async {
    if (!mounted) return;
    setState(() {
      _isLoadingReceipts = true;
      _receiptError = null;
    });
    try {
      final rows = await _receiptRepository
          .getReceiptSummaries()
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _receipts = rows.where((item) => !item.isDraft).toList();
        _isLoadingReceipts = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _receiptError = error;
        _isLoadingReceipts = false;
      });
    }
  }

  Future<void> _refreshDrafts() async {
    if (!mounted) return;
    setState(() {
      _isLoadingDrafts = true;
      _draftError = null;
    });
    debugPrint('[ThuMua] draft state loading=true');
    try {
      final rows = await _loadDrafts();
      if (!mounted) return;
      setState(() {
        _drafts = rows;
        _isLoadingDrafts = false;
      });
      WidgetsBinding.instance.scheduleFrame();
      debugPrint('[ThuMua] draft state loading=false rows=${rows.length}');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _draftError = error;
        _isLoadingDrafts = false;
      });
    }
  }

  void refreshLatest() => _reload();

  Future<void> _showDraftDetails(ThuMuaDraftSummary draft) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(draft.code,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text('${draft.farmerName} • ${draft.riceVarietyName}'),
              const SizedBox(height: 6),
              Text(
                  '${draft.actualWeightKg.toStringAsFixed(1)} kg • ${draft.bagCount} bao'),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _editDraft(draft);
                },
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Tiếp tục chỉnh sửa'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editDraft(ThuMuaDraftSummary draft) async {
    try {
      final detail = await _receiptRepository
          .getDraftReceiptDetail(draft.id)
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ThuMuaScreen(
            repository: _receiptRepository,
            draft: detail,
          ),
        ),
      );
      if (mounted) _refreshDrafts();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không mở được phiếu nháp: $error')),
      );
    }
  }

  Widget _buildReceiptHistory() {
    if (_isLoadingReceipts) {
      return const _LoadingState(label: 'Đang tải phiếu nhập...');
    }
    if (_receiptError != null) {
      return HErrorState(
        message: 'Không tải được phiếu nhập: $_receiptError',
        onRetry: _refreshReceipts,
      );
    }
    if (_receipts.isEmpty) {
      return const HEmptyState(
        title: 'Chưa có phiếu đã chốt',
        description: 'Phiếu nháp được hiển thị riêng ở mục Phiếu nháp.',
        icon: Icons.inventory_2_outlined,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        for (final receipt in _receipts) ...[
          Card(
            child: ListTile(
              leading: Icon(
                receipt.isFullyStored
                    ? Icons.check_circle_outline
                    : Icons.pending_actions_outlined,
                color: receipt.status.toLowerCase().contains('hủy')
                    ? Colors.red
                    : receipt.isFullyStored
                        ? Colors.green
                        : Colors.orange,
              ),
              title: Text(
                receipt.code,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${receipt.farmerName} • ${receipt.riceVarietyName}\n'
                '${receipt.actualWeightKg.toStringAsFixed(1)} kg • ${receipt.status}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '[ThuMua] build section=$_section loading=$_isLoadingDrafts rows=${_drafts.length}',
    );
    return ColoredBox(
      color: const Color(0xFFF4FBF7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Thu mua lúa',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tải lại',
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton.filled(
                  tooltip: 'Tạo phiếu mua lúa',
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.inbound),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<_ThuMuaSection>(
              segments: const [
                ButtonSegment(
                  value: _ThuMuaSection.schedules,
                  icon: Icon(Icons.event_note_outlined),
                  label: Text('Lịch thu mua'),
                ),
                ButtonSegment(
                  value: _ThuMuaSection.receipts,
                  icon: Icon(Icons.inventory_2_outlined),
                  label: Text('Phiếu nhập'),
                ),
                ButtonSegment(
                  value: _ThuMuaSection.drafts,
                  icon: Icon(Icons.drafts_outlined),
                  label: Text('Phiếu nháp'),
                ),
              ],
              selected: {_section},
              onSelectionChanged: (values) {
                setState(() {
                  _section = values.first;
                });
                if (_section == _ThuMuaSection.drafts) _refreshDrafts();
                if (_section == _ThuMuaSection.receipts) _refreshReceipts();
              },
            ),
          ),
          Expanded(
            child: _section == _ThuMuaSection.drafts
                ? _isLoadingDrafts
                    ? const _LoadingState(label: 'Đang tải...')
                    : _draftError != null
                        ? HErrorState(
                            message: 'Không tải được phiếu nháp: $_draftError',
                            onRetry: _refreshDrafts,
                          )
                        : _drafts.isEmpty
                            ? const HEmptyState(
                                title: 'Chưa có phiếu nháp',
                                description:
                                    'Phiếu vừa tạo nhưng chưa chốt sẽ xuất hiện tại đây.',
                                icon: Icons.drafts_outlined,
                              )
                            : ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                children: [
                                  for (final draft in _drafts) ...[
                                    Card(
                                      clipBehavior: Clip.antiAlias,
                                      child: InkWell(
                                        onTap: () => _showDraftDetails(draft),
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                draft.code,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                '${draft.farmerName} • ${draft.riceVarietyName}',
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${draft.actualWeightKg.toStringAsFixed(1)} kg • ${draft.bagCount} bao',
                                              ),
                                              if (draft.debtAmount > 0) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Công nợ: ${draft.debtAmount.toStringAsFixed(0)} đ',
                                                ),
                                              ],
                                              const SizedBox(height: 10),
                                              Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: FilledButton(
                                                  onPressed: () => _editDraft(draft),
                                                  child: const Text(
                                                      'Tiếp tục chỉnh sửa'),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ],
                              )
                : _section == _ThuMuaSection.receipts
                    ? _buildReceiptHistory()
                    : FutureBuilder<List<PurchaseSchedule>>(
                        future: _schedulesFuture,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData &&
                              snapshot.connectionState !=
                                  ConnectionState.done) {
                            return const _LoadingState(label: 'Đang tải...');
                          }
                          if (snapshot.hasError) {
                            return HErrorState(
                              message:
                                  'Không tải được lịch thu mua: ${snapshot.error}',
                              onRetry: _reload,
                            );
                          }
                          final schedules = snapshot.data ?? const [];
                          if (schedules.isEmpty) {
                            return const HEmptyState(
                              title: 'Chưa có lịch thu mua',
                              description: 'Server chưa có lịch thu mua nào.',
                              icon: Icons.shopping_cart_outlined,
                            );
                          }
                          return _ScheduleList(schedules: schedules);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleList extends StatelessWidget {
  const _ScheduleList({required this.schedules});

  final List<PurchaseSchedule> schedules;

  @override
  Widget build(BuildContext context) {
    final active = schedules.where((item) => !item.isCancelled).length;
    final totalKg = schedules
        .where((item) => !item.isCancelled)
        .fold<double>(0, (sum, item) => sum + item.estimatedWeightKg);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Expanded(child: _Metric(label: '${schedules.length} lịch')),
            const SizedBox(width: 8),
            Expanded(
                child: _Metric(
                    label: '${(totalKg / 1000).toStringAsFixed(1)} tấn')),
            const SizedBox(width: 8),
            Expanded(child: _Metric(label: '$active còn hiệu lực')),
          ],
        ),
        const SizedBox(height: 16),
        for (final item in schedules) ...[
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).pushNamed(
                AppRoutes.purchaseScheduleDetail,
                arguments: item,
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: item.isCancelled
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  child: Icon(
                    item.isCancelled ? Icons.event_busy : Icons.agriculture,
                    color: item.isCancelled ? Colors.red : AppColors.primary,
                  ),
                ),
                title: Text(
                  item.code.isEmpty ? 'Lịch chưa có mã' : item.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${item.farmerName} • '
                  '${item.scheduledAt.day.toString().padLeft(2, '0')}/'
                  '${item.scheduledAt.month.toString().padLeft(2, '0')}/'
                  '${item.scheduledAt.year}\n'
                  '${item.riceVariety} • '
                  '${item.estimatedWeightKg.toStringAsFixed(0)} kg • '
                  '${item.status}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: 'Nhập kho theo lịch này',
                  onPressed: item.canCreateReceipt
                      ? () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.inbound,
                            arguments: item,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.add_circle_outline, size: 30),
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(label),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

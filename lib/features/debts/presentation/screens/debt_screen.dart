import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_reload_mixin.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/debt_repository.dart';
import '../../models/debt_models.dart';

enum DebtView { overview, payable, receivable, transactions, overdue }

class DebtScreen extends StatefulWidget {
  const DebtScreen({this.repository, super.key});
  final DebtRepository? repository;
  @override
  State<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends State<DebtScreen> with RealtimeReloadMixin {
  /// Công nợ phát sinh từ chốt phiếu mua, giao hàng, trả hàng và các lần thu/chi
  /// ở máy khác — số dư phải tự cập nhật, không chờ kéo làm mới.
  @override
  Set<String> get realtimeEntities => const {
        'PartyDebt',
        'DebtTransaction',
        'PaddyPurchaseReceipt',
        'OutboundOrder',
        'CustomerReturnOrder',
        'ReturnToSupplierOrder',
      };

  @override
  void onRealtimeChanged() => _load();

  late final DebtRepository _repository;
  DebtDashboard? _data;
  Object? _error;
  DebtView _view = DebtView.overview;
  bool _refreshing = false;
  bool _loadingMore = false;
  int _start = 0;
  static const _pageSize = 20;
  String _search = '';
  String? _status;
  String? _transactionType;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiDebtRepository();
    _load(initial: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    setState(() {
      if (initial) {
        _data = null;
        _error = null;
      } else {
        _refreshing = true;
      }
    });
    try {
      _start = 0;
      final result = await _repository.loadDashboardPage(query: _query);
      if (!mounted) return;
      setState(() {
        _data = result;
        _error = null;
        _refreshing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _refreshing = false;
      });
    }
  }

  DebtQuery get _query => DebtQuery(
      start: _start,
      length: _pageSize,
      search: _search,
      status: _status,
      transactionType: _transactionType);

  Future<void> _loadMore() async {
    if (_loadingMore || _data == null || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = await _repository.loadDashboardPage(
          query: DebtQuery(
              start: _start + _pageSize,
              length: _pageSize,
              search: _search,
              status: _status,
              transactionType: _transactionType));
      if (!mounted) return;
      setState(() {
        final old = _data!;
        _data = DebtDashboard(
            summary: next.summary,
            payables: [...old.payables, ...next.payables],
            receivables: [...old.receivables, ...next.receivables],
            transactions: [...old.transactions, ...next.transactions],
            overdue: [...old.overdue, ...next.overdue],
            payablesTotal: next.payablesTotal,
            payablesFiltered: next.payablesFiltered,
            receivablesTotal: next.receivablesTotal,
            receivablesFiltered: next.receivablesFiltered,
            transactionsTotal: next.transactionsTotal,
            transactionsFiltered: next.transactionsFiltered,
            overdueTotal: next.overdueTotal,
            overdueFiltered: next.overdueFiltered);
        _start += _pageSize;
        _loadingMore = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loadingMore = false;
        });
      }
    }
  }

  bool get _hasMore {
    final data = _data!;
    final total = switch (_view) {
      DebtView.payable => data.payablesFiltered,
      DebtView.receivable => data.receivablesFiltered,
      DebtView.transactions => data.transactionsFiltered,
      DebtView.overdue => data.overdueFiltered,
      DebtView.overview => 0
    };
    return _view != DebtView.overview && _start + _pageSize < total;
  }

  void _applySearch(String value) {
    if (value == _search) return;
    setState(() {
      _search = value.trim();
    });
    _load(initial: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.backgroundFor(context),
        body: SafeArea(
            child: Column(children: [
          AppGradientHeader(
            title: 'Công nợ',
            subtitle: 'Theo dõi phải trả, phải thu và lịch sử giao dịch',
            leading: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white)),
            trailing: IconButton(
              key: const ValueKey('debt_refresh'),
              onPressed:
                  _refreshing ? null : () => _load(initial: _data == null),
              tooltip: 'Làm mới',
              icon: _refreshing
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.refresh, color: Colors.white),
            ),
          ),
          Expanded(child: _content()),
        ])),
      );

  Widget _content() {
    if (_data == null && _error == null) return const ListSkeleton();
    if (_data == null) return _errorContent(_error!);
    final data = _data!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          _SummaryGrid(data.summary),
          const SizedBox(height: 14),
          _Tabs(
              value: _view,
              onChanged: (value) => setState(() {
                    _view = value;
                    _start = 0;
                  })),
          if (_view != DebtView.overview) ...[
            const SizedBox(height: 10),
            TextField(
                controller: _searchController,
                onSubmitted: _applySearch,
                decoration: InputDecoration(
                    labelText: 'Tìm đối tác hoặc mã chứng từ',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _applySearch('');
                            }))),
            const SizedBox(height: 8),
            if (_view == DebtView.payable ||
                _view == DebtView.receivable ||
                _view == DebtView.overdue)
              Wrap(spacing: 8, children: [
                for (final item in <String?>[null, 'UNPAID', 'PARTIAL', 'PAID'])
                  FilterChip(
                      label: Text(item ?? 'Tất cả trạng thái'),
                      selected: _status == item,
                      onSelected: (_) {
                        setState(() => _status = item);
                        _load(initial: true);
                      })
              ]),
          ],
          const SizedBox(height: 14),
          ..._widgets(data),
          if (_hasMore)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                    onPressed: _loadingMore ? null : _loadMore,
                    icon: _loadingMore
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.expand_more),
                    label:
                        Text(_loadingMore ? 'Đang tải thêm...' : 'Tải thêm'))),
        ],
      ),
    );
  }

  Widget _errorContent(Object error) {
    final known = error is DebtException ? error : null;
    final message = switch (known?.statusCode) {
      401 => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      403 => 'Bạn không có quyền xem dữ liệu công nợ.',
      _ when known?.isTransient == true =>
        'Không kết nối được Backend. Vui lòng kiểm tra mạng.',
      _ => known?.message ?? 'Không tải được dữ liệu công nợ.',
    };
    return HErrorState(message: message, onRetry: () => _load(initial: true));
  }

  List<Widget> _widgets(DebtDashboard data) => switch (_view) {
        DebtView.overview => [
            _Counts(data.summary),
            const SizedBox(height: 16),
            const _Title('Phải trả nổi bật'),
            ..._documentList(
                data.payables.take(3).toList(), 'Không có khoản phải trả'),
            const SizedBox(height: 12),
            const _Title('Phải thu nổi bật'),
            ..._documentList(
                data.receivables.take(3).toList(), 'Không có khoản phải thu'),
          ],
        DebtView.payable =>
          _documentList(data.payables, 'Không có khoản phải trả'),
        DebtView.receivable =>
          _documentList(data.receivables, 'Không có khoản phải thu'),
        DebtView.transactions => data.transactions.isEmpty
            ? const [
                HEmptyState(
                    title: 'Chưa có giao dịch',
                    description: 'Backend chưa trả lịch sử giao dịch.',
                    icon: Icons.history)
              ]
            : [
                for (final item in data.transactions) ...[
                  _TransactionCard(item),
                  const SizedBox(height: 10)
                ]
              ],
        DebtView.overdue =>
          _documentList(data.overdue, 'Không có khoản quá hạn'),
      };

  List<Widget> _documentList(List<DebtDocument> items, String empty) =>
      items.isEmpty
          ? [
              HEmptyState(
                  title: empty,
                  description: 'Backend chưa trả dữ liệu phù hợp.',
                  icon: Icons.receipt_long_outlined)
            ]
          : [
              for (final item in items) ...[
                _DocumentCard(item),
                const SizedBox(height: 10)
              ]
            ];
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid(this.value);
  final DebtSummary value;
  @override
  Widget build(BuildContext context) {
    final items = [
      ('Phải trả nông dân', value.totalPayable, const Color(0xFFD97706)),
      ('Phải trả quá hạn', value.overduePayable, const Color(0xFFDC2626)),
      ('Phải thu khách hàng', value.totalReceivable, const Color(0xFF2563EB)),
      ('Phải thu quá hạn', value.overdueReceivable, const Color(0xFFBE123C))
    ];
    return LayoutBuilder(
        builder: (_, box) => Wrap(spacing: 10, runSpacing: 10, children: [
              for (final item in items)
                SizedBox(
                    width: (box.maxWidth - 10) / 2,
                    child: AppCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(item.$1,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondaryFor(context))),
                          const SizedBox(height: 7),
                          FittedBox(
                              child: Text(_money(item.$2),
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: item.$3))),
                        ]))),
            ]));
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.value, required this.onChanged});
  final DebtView value;
  final ValueChanged<DebtView> onChanged;
  @override
  Widget build(BuildContext context) {
    const labels = {
      DebtView.overview: 'Tổng quan',
      DebtView.payable: 'Phải trả',
      DebtView.receivable: 'Phải thu',
      DebtView.transactions: 'Giao dịch',
      DebtView.overdue: 'Quá hạn'
    };
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final view in DebtView.values) ...[
            ChoiceChip(
                key: ValueKey('debt_${view.name}'),
                label: Text(labels[view]!),
                selected: value == view,
                onSelected: (_) => onChanged(view)),
            const SizedBox(width: 8),
          ]
        ]));
  }
}

class _Counts extends StatelessWidget {
  const _Counts(this.value);
  final DebtSummary value;
  @override
  Widget build(BuildContext context) => AppCard(
          child: Row(children: [
        Expanded(child: _Count('Chứng từ còn mở', value.openDocumentCount)),
        const SizedBox(height: 42, child: VerticalDivider()),
        Expanded(child: _Count('Khoản quá hạn', value.overdueDocumentCount)),
      ]));
}

class _Count extends StatelessWidget {
  const _Count(this.label, this.value);
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text('$value',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11, color: AppColors.textSecondaryFor(context)))
      ]);
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)));
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard(this.value);
  final DebtDocument value;
  @override
  Widget build(BuildContext context) => AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(value.partyName,
                  style: const TextStyle(fontWeight: FontWeight.w900))),
          AppStatusChip(
              label: _status(value.status),
              tone: value.isOverdue ? AppTone.danger : AppTone.brand,
              dense: true)
        ]),
        if (value.partyCode.isNotEmpty || value.partyPhone != null)
          Text(
              [value.partyCode, value.partyPhone]
                  .where((x) => x?.isNotEmpty == true)
                  .join(' • '),
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondaryFor(context))),
        const Divider(height: 22),
        _Line('Chứng từ', value.documentCode),
        _Line('Ngày chứng từ', _date(value.transactionDate)),
        _Line('Tổng tiền', _money(value.totalAmount)),
        _Line('Đã thanh toán', _money(value.paidAmount)),
        _Line('Còn lại', _money(value.outstandingAmount), strong: true),
        _Line('Hạn thanh toán', _date(value.dueDate)),
        if (value.isOverdue)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Quá hạn ${value.daysOverdue} ngày',
                  style: const TextStyle(
                      color: AppColors.danger, fontWeight: FontWeight.w800))),
      ]));
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard(this.value);
  final DebtTransaction value;
  @override
  Widget build(BuildContext context) => AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(value.partyName,
                  style: const TextStyle(fontWeight: FontWeight.w900))),
          Text(_money(value.amount),
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w900))
        ]),
        const SizedBox(height: 8),
        _Line('Loại giao dịch', _tx(value.transactionType)),
        _Line('Chứng từ', value.documentCode),
        _Line('Thời gian', _date(value.transactionDate)),
        _Line('Dư nợ sau giao dịch', _money(value.balanceAfter)),
        if (value.createdByName?.isNotEmpty == true)
          _Line('Người ghi nhận', value.createdByName!),
      ]));
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.strong = false});
  final String label;
  final String value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondaryFor(context)))),
        const SizedBox(width: 10),
        Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: strong ? FontWeight.w900 : FontWeight.w700)))
      ]));
}

String _money(double value) {
  final raw = value.round().abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) out.write('.');
    out.write(raw[i]);
  }
  return '${value < 0 ? '-' : ''}$out ₫';
}

String _date(DateTime? value) => value == null
    ? 'Chưa có'
    : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
String _status(String value) => switch (value.toUpperCase()) {
      'UNPAID' => 'Chưa thanh toán',
      'PARTIAL' || 'PARTIALLY_PAID' => 'Thanh toán một phần',
      'PAID' => 'Đã thanh toán',
      'OVERDUE' => 'Quá hạn',
      _ => value
    };
String _tx(String value) => switch (value.toUpperCase()) {
      'CHARGE' => 'Phát sinh nợ',
      'PAYMENT' => 'Thanh toán',
      'ADJUSTMENT' => 'Điều chỉnh',
      _ => value
    };

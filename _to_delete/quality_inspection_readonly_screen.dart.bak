import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/quality_inspection_readonly_repository.dart';
import '../../models/quality_inspection_readonly.dart';
import 'quality_inspection_detail_screen.dart';

class QualityInspectionReadOnlyScreen extends StatefulWidget {
  const QualityInspectionReadOnlyScreen({this.repository, super.key});
  final QualityInspectionReadOnlyRepository? repository;
  @override
  State<QualityInspectionReadOnlyScreen> createState() => _QualityInspectionReadOnlyScreenState();
}

class _QualityInspectionReadOnlyScreenState extends State<QualityInspectionReadOnlyScreen> {
  static const _pageSize = 20;
  late final QualityInspectionReadOnlyRepository _repo;
  final _search = TextEditingController();
  Timer? _debounce;
  QualityInspectionPage? _page;
  Object? _error;
  bool _loading = true;
  int _start = 0;
  bool? _passed;

  @override
  void initState() { super.initState(); _repo = widget.repository ?? ApiQualityInspectionReadOnlyRepository(); _load(); }
  @override
  void dispose() { _debounce?.cancel(); _search.dispose(); super.dispose(); }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() { _loading = true; _error = null; });
    try {
      final page = await _repo.loadPage(start: _start, length: _pageSize, search: _search.text.trim(), passedInspection: _passed);
      if (!mounted) return;
      setState(() { _page = page; _error = null; _loading = false; });
    } catch (error) { if (mounted) setState(() { _error = error; _loading = false; }); }
  }
  void _searchChanged(String value) { _debounce?.cancel(); _debounce = Timer(const Duration(milliseconds: 450), () { _start = 0; _load(); }); }
  void _filter(bool? value) { setState(() { _passed = value; _start = 0; }); _load(); }
  int get _pages => (_page?.recordsFiltered ?? 0) == 0 ? 1 : (((_page!.recordsFiltered) + _pageSize - 1) ~/ _pageSize);
  int get _currentPage => (_start ~/ _pageSize) + 1;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.backgroundFor(context),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppGradientHeader(
                title: 'Chất lượng & cách ly',
                subtitle: 'Kiểm định và quản lý lô cách ly',
                trailing: IconButton(
                  onPressed: () => _load(showLoading: false),
                  color: Colors.white,
                  icon: const Icon(Icons.refresh),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: _searchChanged,
                        decoration: InputDecoration(
                          hintText: 'Tìm mã lô, người kiểm...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _search.clear();
                                    _start = 0;
                                    _load();
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 108,
                      child: OutlinedButton.icon(
                        onPressed: _showFilters,
                        icon: const Icon(Icons.tune, size: 18),
                        label: const Text('Bộ lọc'),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      );

  Widget _body() {
    if (_loading && _page == null) return const ListSkeleton();
    if (_error != null && _page == null) return HErrorState(message: 'Không tải được dữ liệu: $_error', onRetry: _load);
    final items = _page?.items ?? const <QualityInspectionReadOnly>[];
    if (items.isEmpty) return const HEmptyState(title: 'Chưa có kết quả kiểm định', description: 'Không có phiếu phù hợp với điều kiện hiện tại.', icon: Icons.science_outlined);
    return RefreshIndicator(onRefresh: () => _load(showLoading: false), child: ListView.separated(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), itemCount: items.length + 2, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (_, index) {
      if (index == 0) return Text('Hiển thị ${_start + 1}-${_start + items.length} / ${_page!.recordsFiltered}', style: const TextStyle(fontWeight: FontWeight.w700));
      if (index == items.length + 1) return _pager();
      return _InspectionCard(item: items[index - 1], onTap: () => _openDetail(items[index - 1]));
    }));
  }
  Widget _pager() => Row(mainAxisAlignment: MainAxisAlignment.center, children: [IconButton(onPressed: _currentPage > 1 ? () { _start -= _pageSize; _load(); } : null, icon: const Icon(Icons.chevron_left)), Text('Trang $_currentPage/$_pages'), IconButton(onPressed: _currentPage < _pages ? () { _start += _pageSize; _load(); } : null, icon: const Icon(Icons.chevron_right))]);
  Future<void> _showFilters() async {
    final result = await showModalBottomSheet<bool?>(
      context: context,
      builder: (context) => SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Bộ lọc kết quả', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              ListTile(
                title: const Text('Tất cả kết quả'),
                trailing: _passed == null ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, null),
              ),
              ListTile(
                title: const Text('Đạt'),
                trailing: _passed == true ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, true),
              ),
              ListTile(
                title: const Text('Không đạt'),
                trailing: _passed == false ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, false),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
    if (result != null || _passed != null) _filter(result);
  }
  Future<void> _openDetail(QualityInspectionReadOnly item) async {
    if (item.inspectionId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QualityInspectionDetailScreen(
          repository: _repo,
          item: item,
        ),
      ),
    );
  }
}

class _InspectionCard extends StatelessWidget {
  const _InspectionCard({required this.item, required this.onTap});
  final QualityInspectionReadOnly item; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) { final passed = item.passedInspection; final color = passed == true ? Colors.green : passed == false ? Colors.red : Colors.orange; return AppCard(onTap: onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(item.lotCode ?? 'Lô chưa xác định', style: const TextStyle(fontWeight: FontWeight.w900))), _Badge(text: passed == true ? 'Đạt' : passed == false ? 'Không đạt' : 'Chờ kiểm định', color: color)]), const SizedBox(height: 8), Text('Người kiểm: ${item.inspectorName ?? 'Chưa ghi nhận'}'), Text('Kiểm định: ${_date(item.inspectedAt)}'), if (item.affectedWeightKg != null) Text('Ảnh hưởng: ${item.affectedWeightKg} kg'), if (item.moisturePercent != null || item.impurityPercent != null) Text('Ẩm: ${item.moisturePercent ?? '-'}%  •  Tạp chất: ${item.impurityPercent ?? '-'}%'), if (item.handling?.isNotEmpty == true) Text('Xử lý: ${item.handling}') ])); }
}
class _Badge extends StatelessWidget { const _Badge({required this.text, required this.color}); final String text; final Color color; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)), child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800))); }

String _date(DateTime? value) => value == null ? '-' : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

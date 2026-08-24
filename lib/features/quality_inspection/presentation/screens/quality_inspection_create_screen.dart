import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../auth/data/auth_session_store.dart';
import '../../data/quality_inspection_repository.dart';
import '../../models/quality_inspection.dart';

class QualityInspectionCreateScreen extends StatefulWidget {
  const QualityInspectionCreateScreen({required this.repository, super.key});

  final QualityInspectionRepository repository;

  @override
  State<QualityInspectionCreateScreen> createState() =>
      _QualityInspectionCreateScreenState();
}

class _QualityInspectionCreateScreenState
    extends State<QualityInspectionCreateScreen> {
  final _moisture = TextEditingController();
  final _impurity = TextEditingController();
  final _note = TextEditingController();
  Map<int, QualityLot> _lots = const {};
  QualityLot? _lot;
  Set<int> _bagIds = const {};
  String? _mold;
  String? _pest;
  String? _packaging;
  String? _handling;
  Object? _loadError;
  bool _loading = true;
  bool _loadingLot = false;
  bool _busy = false;

  bool get _canCreate =>
      AuthSessionStore.current?.user.hasRole('PURCHASING') == true &&
      AuthSessionStore.current
              ?.hasPermission('QUALITY_INSPECTIONS', 'CREATE') ==
      true;

  bool get _hasSelectedBags => _bagIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadLots();
  }

  @override
  void dispose() {
    _moisture.dispose();
    _impurity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadLots() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final lots = await widget.repository.loadAwaitingPaddyLots();
      if (!mounted) return;
      setState(() {
        _lots = lots;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _selectLot(int? id) async {
    if (id == null || _loadingLot) return;
    setState(() {
      _lot = _lots[id];
      _bagIds = const {};
      _loadingLot = true;
    });
    try {
      // `awaiting-qc` đã trả đầy đủ danh sách bao. Không gọi GET chi tiết lô
      // vì endpoint đó yêu cầu PADDY_LOTS/READ, trong khi form này thuộc quyền
      // QUALITY_INSPECTIONS và người dùng có thể không có quyền xem module lô.
      final detail = _lots[id];
      if (!mounted) return;
      setState(() {
        _lot = detail;
        _loadingLot = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingLot = false);
      _message('Không tải được chi tiết lô: $error', error: true);
    }
  }

  double get _selectedWeight =>
      _lot?.bags
          .where((bag) => _bagIds.contains(bag.id))
          .fold<double>(0, (sum, bag) => sum + bag.weightKg) ??
      0;

  double? _number(TextEditingController controller) {
    final text = controller.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  Future<void> _submit({required bool passed}) async {
    if (_busy || !_canCreate) {
      if (!_canCreate) {
        _message('Bạn không có quyền tạo phiếu kiểm tra.', error: true);
      }
      return;
    }
    // Một hay nhiều bao được chọn đồng nghĩa với quyết định tách phần tồn đó
    // sang cách ly. Chặn cả callback trực tiếp để không thể gửi kết quả đạt và
    // vô tình làm mất danh sách bao đã chọn.
    if (passed && _hasSelectedBags) {
      _message(
        'Đã chọn bao cần cách ly. Vui lòng dùng "Lưu & cách ly lô".',
        error: true,
      );
      return;
    }
    final lot = _lot;
    if (lot == null) {
      _message('Vui lòng chọn mã lô.', error: true);
      return;
    }
    final moisture = _number(_moisture);
    final impurity = _number(_impurity);
    if ((_moisture.text.trim().isNotEmpty && moisture == null) ||
        (_impurity.text.trim().isNotEmpty && impurity == null)) {
      _message('Độ ẩm và tạp chất phải là số hợp lệ.', error: true);
      return;
    }
    if ((moisture != null && (moisture < 0 || moisture > 100)) ||
        (impurity != null && (impurity < 0 || impurity > 100))) {
      _message('Độ ẩm và tạp chất phải từ 0 đến 100%.', error: true);
      return;
    }
    if (!passed && _bagIds.isNotEmpty) {
      final basis = lot.basisWeightKg;
      if (basis != null && _selectedWeight >= basis) {
        _message(
          'Để cách ly toàn bộ lô, hãy bỏ chọn tất cả bao.',
          error: true,
        );
        return;
      }
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(passed ? 'Duyệt đạt chất lượng?' : 'Xác nhận cách ly?'),
        content: Text(
          passed
              ? 'Lô ${lot.lotCode} sẽ được ghi nhận đạt chất lượng.'
              : _bagIds.isEmpty
                  ? 'Toàn bộ lô ${lot.lotCode} sẽ được chuyển cách ly.'
                  : '${_bagIds.length} bao (${formatKg(_selectedWeight)}) sẽ được tách sang cách ly.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (widget.repository is! QualityInspectionCreateRepository) {
      _message('Nguồn dữ liệu hiện tại không hỗ trợ tạo phiếu.', error: true);
      return;
    }
    final createRepository =
        widget.repository as QualityInspectionCreateRepository;
    setState(() => _busy = true);
    try {
      await createRepository.create(
        QualityInspectionCreate(
          paddyLotId: lot.id,
          inspectorId: AuthSessionStore.current?.user.id,
          inspectedAt: DateTime.now(),
          moisturePercent: moisture,
          impurityPercent: impurity,
          moldLevel: _mold,
          pestLevel: _pest,
          packagingStatus: _packaging,
          passedInspection: passed,
          handling: _handling,
          note: _note.text,
          affectedBagIds: passed ? const [] : _bagIds.toList(growable: false),
          affectedWeightKg: passed || _bagIds.isEmpty ? null : _selectedWeight,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _message('Không tạo được phiếu: $error', error: true);
    }
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.danger : AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppGradientHeader(
              overline: 'Lô + Chỉ số + Quyết định',
              title: 'Tạo phiếu kiểm tra',
              subtitle: 'Chọn lô và phạm vi tồn bị ảnh hưởng',
              leading: IconButton(
                color: Colors.white,
                onPressed: _busy ? null : () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
      bottomNavigationBar: _canCreate ? _bottomActions() : null,
    );
  }

  Widget _body() {
    if (!_canCreate) {
      return const Center(
          child: Text('Bạn không có quyền tạo phiếu kiểm tra.'));
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _loadLots,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tải lại danh sách lô'),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
      children: [
        _section(
          '1. Lô được kiểm tra & phạm vi ảnh hưởng',
          [
            DropdownButtonFormField<int>(
              initialValue:
                  _lot != null && _lots.containsKey(_lot!.id) ? _lot!.id : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Mã lô *'),
              hint: const Text('Chọn mã lô'),
              items: _lots.values
                  .where((lot) =>
                      lot.id > 0 && lot.lotCode.isNotEmpty && lot.isPaddy)
                  .map(
                    (lot) => DropdownMenuItem(
                      value: lot.id,
                      child: Text(
                          '${lot.lotCode} · ${lot.productVariantName ?? '—'}'),
                    ),
                  )
                  .toList(),
              onChanged: _loadingLot ? null : _selectLot,
            ),
            if (_loadingLot) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_lot != null && !_loadingLot) ...[
              const SizedBox(height: 14),
              _lotSummary(_lot!),
              const SizedBox(height: 12),
              _bagSelector(_lot!),
            ],
          ],
        ),
        const SizedBox(height: 14),
        _section('2. Chỉ số kiểm định', [
          Row(children: [
            Expanded(child: _decimalField(_moisture, 'Độ ẩm (%)')),
            const SizedBox(width: 10),
            Expanded(child: _decimalField(_impurity, 'Tạp chất (%)')),
          ]),
          const SizedBox(height: 12),
          _dropdown('Tình trạng đóng gói', QualityVocab.packaging, _packaging,
              (value) => setState(() => _packaging = value)),
        ]),
        const SizedBox(height: 14),
        _section('3. Đánh giá & quyết định', [
          _dropdown('Mức độ mốc', QualityVocab.mold, _mold,
              (value) => setState(() => _mold = value)),
          const SizedBox(height: 12),
          _dropdown('Mức độ sâu mọt', QualityVocab.pest, _pest,
              (value) => setState(() => _pest = value)),
          const SizedBox(height: 12),
          _dropdown('Hướng xử lý', QualityVocab.handling, _handling,
              (value) => setState(() => _handling = value)),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: AuthSessionStore.current?.user.fullName ?? '—',
            readOnly: true,
            decoration: const InputDecoration(labelText: 'Người kiểm'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Ghi chú'),
          ),
        ]),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      );

  Widget _lotSummary(QualityLot lot) => Column(
        children: [
          Row(children: [
            Expanded(
                child: _readOnly('Loại hàng', lot.productVariantName ?? '—')),
            const SizedBox(width: 10),
            Expanded(child: _readOnly('Vị trí', lot.locationLabel)),
          ]),
          const SizedBox(height: 10),
          _readOnly('Tổng tồn của lô', formatKg(lot.basisWeightKg ?? 0)),
        ],
      );

  Widget _readOnly(String label, String value) => InputDecorator(
        decoration: InputDecoration(labelText: label, filled: true),
        child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  Widget _bagSelector(QualityLot lot) {
    if (lot.bags.isEmpty) {
      return const AppInfoBanner(
        message:
            'Lô không có danh sách bao. Không chọn bao để xử lý toàn bộ lô.',
        tone: AppTone.info,
      );
    }
    final total = lot.bags.fold<double>(0, (sum, bag) => sum + bag.weightKg);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Chọn bao cần tách sang cách ly',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                )),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Chip(
              label:
                  Text('Toàn lô: ${lot.bags.length} bao / ${formatKg(total)}')),
          Chip(
              label: Text(
                  'Cách ly: ${_bagIds.length} bao / ${formatKg(_selectedWeight)}')),
          Chip(label: Text('Còn lại: ${lot.bags.length - _bagIds.length} bao')),
        ]),
        const SizedBox(height: 6),
        for (final bag in lot.bags)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _bagIds.contains(bag.id),
            title: Text('Bao #${bag.bagNo}'),
            secondary: Text(formatKg(bag.weightKg)),
            onChanged: _busy
                ? null
                : (checked) => setState(() {
                      final next = {..._bagIds};
                      checked == true ? next.add(bag.id) : next.remove(bag.id);
                      _bagIds = next;
                    }),
          ),
        const Text(
          'Không chọn bao nếu muốn cách ly toàn bộ lô.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _decimalField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
      );

  Widget _dropdown(String label, List<String> values, String? value,
          ValueChanged<String?> changed) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        hint: const Text('Không đánh giá'),
        items: values
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: changed,
      );

  Widget _bottomActions() => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('quality_create_cancel'),
                    onPressed: _busy ? null : () => Navigator.maybePop(context),
                    child: const Text('Hủy'),
                  ),
                ),
                if (!_hasSelectedBags) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const Key('quality_create_save_passed'),
                      onPressed: _busy ? null : () => _submit(passed: true),
                      child: const Text('Lưu & duyệt đạt'),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  key: const Key('quality_create_save_quarantine'),
                  onPressed: _busy ? null : () => _submit(passed: false),
                  child: Text(_busy ? 'Đang lưu...' : 'Lưu & cách ly lô'),
                ),
              ),
            ],
          ),
        ),
      );
}

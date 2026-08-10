import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/api_kho_check_repository.dart';
import '../../data/kho_check_repository.dart';
import '../../models/kho_check.dart';
import '../widgets/kho_bottom_action.dart';
import '../../../home/presentation/widgets/main_bottom_navigation.dart';
import '../widgets/kho_check_header.dart';
import '../widgets/kho_check_hint.dart';
import '../widgets/kho_check_item_card.dart';
import '../widgets/kho_note_field.dart';
import '../widgets/kho_summary_fields.dart';

class KhoScreen extends StatefulWidget {
  const KhoScreen({this.repository, super.key});

  final KhoCheckRepository? repository;

  @override
  State<KhoScreen> createState() => _KhoScreenState();
}

class _KhoScreenState extends State<KhoScreen> {
  late final KhoCheckRepository _repository;
  final TextEditingController _noteController = TextEditingController();

  late final Future<KhoCheck> _checkFuture;
  KhoCheck? _check;
  List<KhoCheckItem> _items = const [];
  bool _initialized = false;
  bool _isSubmitting = false;
  final Set<int> _selectedProductIds = {};

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiKhoCheckRepository();
    _checkFuture = _repository.getDraftCheck();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _initializeCheck(KhoCheck check) {
    if (_initialized) return;
    _check = check;
    _items = List.from(check.items);
    if (check.note?.trim().isNotEmpty == true) {
      _noteController.text = check.note!;
    }
    _selectedProductIds.addAll(
      _items
          .where((item) => item.actualQuantity != null)
          .map((item) => item.productVariantId),
    );
    _initialized = true;
  }

  void _updateActualQuantity(int index, String value) {
    final parsed = int.tryParse(value);
    setState(() {
      _items = [
        for (var i = 0; i < _items.length; i++)
          if (i == index)
            _items[i].copyWith(
              actualQuantity: parsed,
              clearActualQuantity: value.trim().isEmpty,
            )
          else
            _items[i],
      ];
    });
  }

  Future<void> _confirmKhoCheck() async {
    final check = _check;
    if (check == null || _isSubmitting) return;
    final selectedItems = _items
        .where((item) => _selectedProductIds.contains(item.productVariantId))
        .toList();
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một sản phẩm cần kiểm kê.'),
        ),
      );
      return;
    }
    if (selectedItems.any((item) => item.actualQuantity == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số lượng thực tế cho tất cả sản phẩm.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      var id = check.id;
      if (id <= 0) {
        // Persist a Draft first; submitting only changes it to waiting approval.
        id = await _repository.createStockTake(
          check: check,
          items: selectedItems,
          note: _noteController.text,
        );
      }
      if (_repository is StockTakeSubmitRepository) {
        final submitRepository = _repository as StockTakeSubmitRepository;
        await submitRepository.submitStockTake(
          stockTakeId: id,
          check: check,
          items: selectedItems,
          note: _noteController.text,
        );
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Color(0xFF16A34A)),
          title: const Text('Đã tạo phiếu kiểm kê'),
          content: Text(id > 0 ? 'Mã phiếu backend: #$id' : check.checkCode),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } on KhoCheckException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
          ),
          const SizedBox(height: 16),
          Text(
            'Đang tải phiếu kiểm kê...',
            style: TextStyle(
              color: AppColors.textSecondaryFor(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object? error) {
    final message = error is KhoCheckException
        ? error.message
        : 'Không tải được dữ liệu tồn kho';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimaryFor(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCheckForm(KhoCheck check) {
    _initializeCheck(check);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KhoSummaryFields(check: check),
          const SizedBox(height: 12),
          const KhoCheckHint(),
          const SizedBox(height: 12),
          Text(
            'Chọn sản phẩm cần tạo phiếu kiểm kê',
            style: TextStyle(
              color: AppColors.textPrimaryFor(context),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('Chưa có sản phẩm trong kho')),
            ),
          for (var index = 0; index < _items.length; index++) ...[
            KhoCheckItemCard(
              item: _items[index],
              selected: _selectedProductIds.contains(
                _items[index].productVariantId,
              ),
              onSelectedChanged: (selected) {
                setState(() {
                  final id = _items[index].productVariantId;
                  if (selected) {
                    _selectedProductIds.add(id);
                  } else {
                    _selectedProductIds.remove(id);
                  }
                });
              },
              onActualChanged: (value) => _updateActualQuantity(index, value),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          KhoNoteField(
            controller: _noteController,
            labelText: 'Ghi chú',
            hintText: check.noteHint,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        child: FutureBuilder<KhoCheck>(
          future: _checkFuture,
          builder: (context, snapshot) {
            final check = snapshot.data;

            return Column(
              children: [
                KhoCheckHeader(status: _check?.status ?? 'Phiáº¿u nhÃ¡p'),
                Expanded(
                  child: switch (snapshot.connectionState) {
                    ConnectionState.done when snapshot.hasData =>
                      _buildCheckForm(check!),
                    ConnectionState.done => _buildErrorState(
                        context,
                        snapshot.error,
                      ),
                    _ => _buildLoadingState(context),
                  },
                ),
                KhoBottomAction(
                  onConfirm: _isSubmitting ? null : _confirmKhoCheck,
                  isLoading: _isSubmitting,
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: MainBottomNavigation(
        currentIndex: 2,
        onTap: (index) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/home',
            (route) => false,
            arguments: index,
          );
        },
      ),
    );
  }
}

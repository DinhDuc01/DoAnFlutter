import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/inventory_check_repository.dart';
import '../../models/inventory_check.dart';
import '../widgets/inventory_bottom_action.dart';
import '../widgets/inventory_bottom_bar.dart';
import '../widgets/inventory_check_header.dart';
import '../widgets/inventory_check_hint.dart';
import '../widgets/inventory_check_item_card.dart';
import '../widgets/inventory_note_field.dart';
import '../widgets/inventory_summary_fields.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final InventoryCheckRepository _repository = MockInventoryCheckRepository();
  final TextEditingController _noteController = TextEditingController();

  late final Future<InventoryCheck> _checkFuture;
  InventoryCheck? _check;
  List<InventoryCheckItem> _items = const [];
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // API_SWAP: This is where the screen requests inventory-check data.
    _checkFuture = _repository.getDraftCheck();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _initializeCheck(InventoryCheck check) {
    if (_initialized) return;
    _check = check;
    _items = check.items;
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

  void _confirmInventoryCheck() {
    final check = _check;
    if (check == null) return;

    // API_SWAP: Send checkCode, note and item actual quantities to POST /inventory-check/confirm.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã xác nhận kiểm kho ${check.checkCode}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundStart,
      body: SafeArea(
        child: FutureBuilder<InventoryCheck>(
          future: _checkFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text('Không tải được phiếu kiểm kho'));
            }

            final check = snapshot.data!;
            _initializeCheck(check);

            return Column(
              children: [
                const InventoryCheckHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InventorySummaryFields(check: check),
                        const SizedBox(height: 12),
                        const InventoryCheckHint(),
                        const SizedBox(height: 12),
                        for (var index = 0; index < _items.length; index++) ...[
                          InventoryCheckItemCard(
                            item: _items[index],
                            onActualChanged: (value) {
                              _updateActualQuantity(index, value);
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 24),
                        InventoryNoteField(
                          controller: _noteController,
                          hintText: check.noteHint,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                InventoryBottomAction(onConfirm: _confirmInventoryCheck),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const InventoryBottomBar(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/kho/models/kho_check.dart';
import 'package:stocklite/features/kho/presentation/widgets/kho_check_item_card.dart';

void main() {
  testWidgets('stocktake actual quantity accepts multiple digits',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _StocktakeInputHarness()));

    final field = find.byType(TextFormField);
    await tester.tap(field);
    tester.testTextInput.enterText('1');
    await tester.pump();

    // The field must keep its input connection after the parent rebuilds.
    tester.testTextInput.enterText('1250');
    await tester.pump();

    expect(find.text('1250'), findsOneWidget);
    expect(find.text('+1240'), findsNothing);
  });
}

class _StocktakeInputHarness extends StatefulWidget {
  const _StocktakeInputHarness();

  @override
  State<_StocktakeInputHarness> createState() => _StocktakeInputHarnessState();
}

class _StocktakeInputHarnessState extends State<_StocktakeInputHarness> {
  KhoCheckItem _item = const KhoCheckItem(
    productVariantId: 1,
    productName: 'Gạo ST25',
    sku: 'ST25',
    systemQuantity: 10,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: KhoCheckItemCard(
          item: _item,
          onActualChanged: (value) {
            setState(() {
              _item = _item.copyWith(
                actualQuantity: int.tryParse(value),
                clearActualQuantity: value.isEmpty,
              );
            });
          },
        ),
      ),
    );
  }
}

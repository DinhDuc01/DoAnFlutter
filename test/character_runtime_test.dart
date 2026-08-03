import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/character/data/character_registry.dart';
import 'package:stocklite/features/character/models/character_appearance.dart';
import 'package:stocklite/features/character/models/character_manifest.dart';
import 'package:stocklite/features/character/runtime/character_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CharacterRegistry registry;

  setUpAll(() async {
    registry = await CharacterRegistry.load();
  });

  testWidgets('runtime renders body when every optional layer is hidden',
      (tester) async {
    final appearance = CharacterAppearance.defaults(registry.manifest);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 240,
          height: 280,
          child: CharacterStage(
            registry: registry,
            appearance: appearance,
            action: CharacterAction.walk,
            direction: CharacterDirection.left,
            hiddenSlots: CharacterSlot.values.toSet(),
            showGuides: true,
            showSockets: true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one-shot action reaches its final frame without looping',
      (tester) async {
    final appearance = CharacterAppearance.defaults(registry.manifest);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 240,
          height: 280,
          child: CharacterStage(
            registry: registry,
            appearance: appearance,
            action: CharacterAction.scan,
            direction: CharacterDirection.front,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));

    expect(tester.takeException(), isNull);
  });
}

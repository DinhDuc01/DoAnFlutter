import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/character/data/character_appearance_store.dart';
import 'package:stocklite/features/character/data/character_registry.dart';
import 'package:stocklite/features/character/models/character_appearance.dart';
import 'package:stocklite/features/character/models/character_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CharacterRegistry registry;

  setUpAll(() async {
    registry = await CharacterRegistry.load();
  });

  test('character manifest passes the production registry audit', () {
    final report = registry.audit();

    expect(
      report.issues.map((issue) => '${issue.code}:${issue.target}'),
      isEmpty,
    );
    expect(registry.manifest.bodies, hasLength(2));
    expect(registry.manifest.layers, hasLength(8));
  });

  test('left direction mirrors the right source socket consistently', () {
    final body = registry.body('worker_standard');
    final right = registry.resolveSocket(
      body: body,
      socket: 'mainHand',
      action: CharacterAction.walk,
      frame: 3,
      direction: CharacterDirection.right,
    );
    final left = registry.resolveSocket(
      body: body,
      socket: 'mainHand',
      action: CharacterAction.walk,
      frame: 3,
      direction: CharacterDirection.left,
    );

    expect(left.dx, closeTo(-right.dx, 0.001));
    expect(left.dy, closeTo(right.dy, 0.001));
  });

  test('legacy composite style migrates to slots and persists once', () async {
    final storage = MemoryCharacterStorage(
      jsonEncode({'styleKey': 'uniform_navy', 'body': 'worker_compact'}),
    );
    final controller = CharacterAppearanceController(storage: storage);

    await controller.load(registry: registry);

    expect(controller.value?.schemaVersion,
        CharacterAppearance.currentSchemaVersion);
    expect(controller.value?.bodyId, 'worker_compact');
    expect(controller.value?.layers[CharacterSlot.outfit], 'uniform_navy');
    expect(jsonDecode(storage.value!)['schemaVersion'], 2);
  });

  test('invalid body and incompatible style keys fall back safely', () {
    final appearance = CharacterAppearance.fromJson(
      {
        'schemaVersion': 2,
        'bodyId': 'missing-body',
        'layers': {
          'outfit': 'missing-outfit',
          'tool': 'scanner_blue',
          'unknown': 'ignored',
        },
      },
      registry.manifest,
    );

    expect(appearance.bodyId, registry.manifest.defaultBody);
    expect(
      appearance.layers[CharacterSlot.outfit],
      registry.manifest.defaultLayers[CharacterSlot.outfit],
    );
    expect(appearance.layers[CharacterSlot.tool], 'scanner_blue');
  });
}

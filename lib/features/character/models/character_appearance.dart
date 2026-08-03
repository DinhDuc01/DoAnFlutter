import 'character_manifest.dart';

class CharacterAppearance {
  const CharacterAppearance({
    required this.schemaVersion,
    required this.bodyId,
    required this.layers,
  });

  factory CharacterAppearance.defaults(CharacterManifest manifest) {
    return CharacterAppearance(
      schemaVersion: currentSchemaVersion,
      bodyId: manifest.defaultBody,
      layers: Map<CharacterSlot, String>.from(manifest.defaultLayers),
    );
  }

  factory CharacterAppearance.fromJson(
    Map<String, dynamic> json,
    CharacterManifest manifest,
  ) {
    final migrated = migrateJson(json);
    final rawLayers = migrated['layers'] as Map<String, dynamic>? ?? const {};
    return CharacterAppearance(
      schemaVersion: currentSchemaVersion,
      bodyId: migrated['bodyId'] as String? ?? manifest.defaultBody,
      layers: {
        for (final entry in rawLayers.entries)
          for (final slot in CharacterSlot.values)
            if (slot.name == entry.key && entry.value is String)
              slot: entry.value as String,
      },
    ).sanitize(manifest);
  }

  static const currentSchemaVersion = 2;

  final int schemaVersion;
  final String bodyId;
  final Map<CharacterSlot, String> layers;

  CharacterAppearance copyWith({
    String? bodyId,
    Map<CharacterSlot, String>? layers,
  }) {
    return CharacterAppearance(
      schemaVersion: currentSchemaVersion,
      bodyId: bodyId ?? this.bodyId,
      layers: layers ?? this.layers,
    );
  }

  CharacterAppearance withLayer(CharacterSlot slot, String? layerId) {
    final next = Map<CharacterSlot, String>.from(layers);
    if (layerId == null) {
      next.remove(slot);
    } else {
      next[slot] = layerId;
    }
    return copyWith(layers: next);
  }

  CharacterAppearance sanitize(CharacterManifest manifest) {
    final body = manifest.bodies
            .where((item) => item.id == bodyId)
            .firstOrNull ??
        manifest.bodies.firstWhere((item) => item.id == manifest.defaultBody);
    final cleanLayers = <CharacterSlot, String>{};
    for (final entry in layers.entries) {
      final matches = manifest.layers.where(
        (layer) =>
            layer.id == entry.value &&
            layer.slot == entry.key &&
            layer.rig == body.rig,
      );
      if (matches.isNotEmpty) cleanLayers[entry.key] = matches.first.id;
    }
    cleanLayers.putIfAbsent(
      CharacterSlot.outfit,
      () => manifest.defaultLayers[CharacterSlot.outfit]!,
    );
    return CharacterAppearance(
      schemaVersion: currentSchemaVersion,
      bodyId: body.id,
      layers: cleanLayers,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': currentSchemaVersion,
        'bodyId': bodyId,
        'layers': {
          for (final entry in layers.entries) entry.key.name: entry.value
        },
      };

  static Map<String, dynamic> migrateJson(Map<String, dynamic> source) {
    final migrated = Map<String, dynamic>.from(source);
    final version = migrated['schemaVersion'] as int? ?? 0;
    if (version < 1 && migrated['styleKey'] is String) {
      migrated['layers'] = {'outfit': migrated['styleKey']};
      migrated.remove('styleKey');
    }
    if (version < 2 && migrated['body'] is String) {
      migrated['bodyId'] = migrated.remove('body');
    }
    migrated['schemaVersion'] = currentSchemaVersion;
    return migrated;
  }
}

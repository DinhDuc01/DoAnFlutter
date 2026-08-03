import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/character_appearance.dart';
import 'character_registry.dart';

abstract interface class CharacterAppearanceStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesCharacterStorage implements CharacterAppearanceStorage {
  static const storageKey = 'stocklite.character.appearance.v2';
  static const legacyStorageKey = 'stocklite.avatar.style';

  @override
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(storageKey) ??
        _legacyPayload(preferences.getString(legacyStorageKey));
  }

  String? _legacyPayload(String? styleKey) {
    if (styleKey == null || styleKey.isEmpty) return null;
    return jsonEncode({'styleKey': styleKey});
  }

  @override
  Future<void> write(String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(storageKey, value);
  }
}

class MemoryCharacterStorage implements CharacterAppearanceStorage {
  MemoryCharacterStorage([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}

class CharacterAppearanceController
    extends ValueNotifier<CharacterAppearance?> {
  CharacterAppearanceController({CharacterAppearanceStorage? storage})
      : storage = storage ?? SharedPreferencesCharacterStorage(),
        super(null);

  static final instance = CharacterAppearanceController();

  final CharacterAppearanceStorage storage;
  CharacterRegistry? _registry;

  CharacterRegistry? get registry => _registry;

  Future<void> load({CharacterRegistry? registry}) async {
    _registry = registry ?? await CharacterRegistry.load();
    final raw = await storage.read();
    if (raw == null) {
      value = CharacterAppearance.defaults(_registry!.manifest);
      return;
    }
    try {
      value = CharacterAppearance.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
        _registry!.manifest,
      );
      await _persist();
    } on FormatException {
      value = CharacterAppearance.defaults(_registry!.manifest);
    }
  }

  Future<void> update(CharacterAppearance appearance) async {
    final registry = _registry ?? await CharacterRegistry.load();
    _registry = registry;
    value = appearance.sanitize(registry.manifest);
    await _persist();
  }

  Future<void> _persist() async {
    final appearance = value;
    if (appearance != null) {
      await storage.write(jsonEncode(appearance.toJson()));
    }
  }
}

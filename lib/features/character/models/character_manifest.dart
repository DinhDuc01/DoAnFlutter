import 'dart:ui';

enum CharacterAction { idle, walk, scan, lift, celebrate }

enum CharacterDirection { front, right, back, left }

enum CharacterSlot { outfit, headwear, tool, offhand, effect }

T _enumByName<T extends Enum>(Iterable<T> values, String name) {
  return values.firstWhere((value) => value.name == name);
}

Color characterColor(String hex) {
  final value = hex.replaceFirst('#', '');
  return Color(int.parse(value.length == 6 ? 'FF$value' : value, radix: 16));
}

class CharacterAnimationDescriptor {
  const CharacterAnimationDescriptor({
    required this.frames,
    required this.fps,
    required this.loop,
    required this.bob,
    required this.sway,
    required this.stride,
    this.impactFrame,
    this.holdLast = false,
  });

  factory CharacterAnimationDescriptor.fromJson(Map<String, dynamic> json) {
    return CharacterAnimationDescriptor(
      frames: json['frames'] as int,
      fps: (json['fps'] as num).toDouble(),
      loop: json['loop'] as bool,
      bob: (json['bob'] as num? ?? 0).toDouble(),
      sway: (json['sway'] as num? ?? 0).toDouble(),
      stride: (json['stride'] as num? ?? 0).toDouble(),
      impactFrame: json['impactFrame'] as int?,
      holdLast: json['holdLast'] as bool? ?? false,
    );
  }

  final int frames;
  final double fps;
  final bool loop;
  final int? impactFrame;
  final bool holdLast;
  final double bob;
  final double sway;
  final double stride;

  Duration get duration => Duration(
        milliseconds: ((frames / fps) * 1000).round(),
      );
}

class CharacterSocketDescriptor {
  const CharacterSocketDescriptor({
    required this.x,
    required this.y,
    this.xWave = 0,
    this.yWave = 0,
    this.phase = 0,
  });

  factory CharacterSocketDescriptor.fromJson(Map<String, dynamic> json) {
    return CharacterSocketDescriptor(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      xWave: (json['xWave'] as num? ?? 0).toDouble(),
      yWave: (json['yWave'] as num? ?? 0).toDouble(),
      phase: (json['phase'] as num? ?? 0).toDouble(),
    );
  }

  final double x;
  final double y;
  final double xWave;
  final double yWave;
  final double phase;
}

class CharacterBodyDescriptor {
  const CharacterBodyDescriptor({
    required this.id,
    required this.label,
    required this.rig,
    required this.assetKey,
    required this.sourceDirections,
    required this.mirrorDirections,
    required this.skinColor,
    required this.hairColor,
    required this.actions,
    required this.sockets,
    required this.scale,
  });

  factory CharacterBodyDescriptor.fromJson(Map<String, dynamic> json) {
    return CharacterBodyDescriptor(
      id: json['id'] as String,
      label: json['label'] as String,
      rig: json['rig'] as String,
      assetKey: json['assetKey'] as String,
      sourceDirections: (json['sourceDirections'] as List<dynamic>)
          .cast<String>()
          .map((name) => _enumByName(CharacterDirection.values, name))
          .toSet(),
      mirrorDirections: (json['mirrorDirections'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(
                _enumByName(CharacterDirection.values, key),
                _enumByName(CharacterDirection.values, value as String),
              )),
      skinColor: characterColor(json['skinColor'] as String),
      hairColor: characterColor(json['hairColor'] as String),
      actions: (json['actions'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          _enumByName(CharacterAction.values, key),
          CharacterAnimationDescriptor.fromJson(value as Map<String, dynamic>),
        ),
      ),
      sockets: (json['sockets'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          CharacterSocketDescriptor.fromJson(value as Map<String, dynamic>),
        ),
      ),
      scale: (json['scale'] as num? ?? 1).toDouble(),
    );
  }

  final String id;
  final String label;
  final String rig;
  final String assetKey;
  final Set<CharacterDirection> sourceDirections;
  final Map<CharacterDirection, CharacterDirection> mirrorDirections;
  final Color skinColor;
  final Color hairColor;
  final Map<CharacterAction, CharacterAnimationDescriptor> actions;
  final Map<String, CharacterSocketDescriptor> sockets;
  final double scale;

  bool shouldMirror(CharacterDirection direction) =>
      mirrorDirections.containsKey(direction);
}

class CharacterLayerDescriptor {
  const CharacterLayerDescriptor({
    required this.id,
    required this.label,
    required this.slot,
    required this.rig,
    required this.assetKey,
    required this.visual,
    required this.color,
    required this.accentColor,
    required this.painterOrder,
    required this.actions,
    this.socket,
  });

  factory CharacterLayerDescriptor.fromJson(Map<String, dynamic> json) {
    return CharacterLayerDescriptor(
      id: json['id'] as String,
      label: json['label'] as String,
      slot: _enumByName(CharacterSlot.values, json['slot'] as String),
      rig: json['rig'] as String,
      assetKey: json['assetKey'] as String,
      visual: json['visual'] as String,
      socket: json['socket'] as String?,
      color: characterColor(json['color'] as String),
      accentColor: characterColor(json['accentColor'] as String),
      painterOrder: json['painterOrder'] as int,
      actions: (json['actions'] as List<dynamic>?)
              ?.cast<String>()
              .map((name) => _enumByName(CharacterAction.values, name))
              .toSet() ??
          CharacterAction.values.toSet(),
    );
  }

  final String id;
  final String label;
  final CharacterSlot slot;
  final String rig;
  final String assetKey;
  final String visual;
  final String? socket;
  final Color color;
  final Color accentColor;
  final int painterOrder;
  final Set<CharacterAction> actions;
}

class CharacterManifest {
  const CharacterManifest({
    required this.schemaVersion,
    required this.defaultBody,
    required this.defaultLayers,
    required this.bodies,
    required this.layers,
  });

  factory CharacterManifest.fromJson(Map<String, dynamic> json) {
    return CharacterManifest(
      schemaVersion: json['schemaVersion'] as int,
      defaultBody: json['defaultBody'] as String,
      defaultLayers: (json['defaultLayers'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          _enumByName(CharacterSlot.values, key),
          value as String,
        ),
      ),
      bodies: (json['bodies'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(CharacterBodyDescriptor.fromJson)
          .toList(growable: false),
      layers: (json['layers'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(CharacterLayerDescriptor.fromJson)
          .toList(growable: false),
    );
  }

  final int schemaVersion;
  final String defaultBody;
  final Map<CharacterSlot, String> defaultLayers;
  final List<CharacterBodyDescriptor> bodies;
  final List<CharacterLayerDescriptor> layers;
}

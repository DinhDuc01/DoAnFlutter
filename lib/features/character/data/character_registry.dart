import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../models/character_appearance.dart';
import '../models/character_manifest.dart';

class CharacterRegistry {
  CharacterRegistry._(this.manifest)
      : _bodies = {for (final body in manifest.bodies) body.id: body},
        _layers = {for (final layer in manifest.layers) layer.id: layer};

  static const manifestAsset = 'assets/characters/character_manifest.json';
  static CharacterRegistry? _cached;

  final CharacterManifest manifest;
  final Map<String, CharacterBodyDescriptor> _bodies;
  final Map<String, CharacterLayerDescriptor> _layers;

  static Future<CharacterRegistry> load({AssetBundle? bundle}) async {
    if (bundle == null && _cached != null) return _cached!;
    final source = await (bundle ?? rootBundle).loadString(manifestAsset);
    final registry = CharacterRegistry._(
      CharacterManifest.fromJson(jsonDecode(source) as Map<String, dynamic>),
    );
    if (bundle == null) _cached = registry;
    return registry;
  }

  CharacterBodyDescriptor body(String id) =>
      _bodies[id] ?? _bodies[manifest.defaultBody]!;

  CharacterLayerDescriptor? layer(String id) => _layers[id];

  List<CharacterLayerDescriptor> layersFor(
    CharacterAppearance appearance,
    CharacterAction action,
  ) {
    final rig = body(appearance.bodyId).rig;
    return appearance.layers.values
        .map(layer)
        .whereType<CharacterLayerDescriptor>()
        .where((item) => item.rig == rig && item.actions.contains(action))
        .toList(growable: false)
      ..sort((a, b) => a.painterOrder.compareTo(b.painterOrder));
  }

  List<CharacterLayerDescriptor> optionsFor(
    CharacterSlot slot,
    String bodyId,
  ) {
    final rig = body(bodyId).rig;
    return manifest.layers
        .where((layer) => layer.slot == slot && layer.rig == rig)
        .toList(growable: false);
  }

  Offset resolveSocket({
    required CharacterBodyDescriptor body,
    required String socket,
    required CharacterAction action,
    required int frame,
    required CharacterDirection direction,
  }) {
    final descriptor = body.sockets[socket] ?? body.sockets['root']!;
    final animation = body.actions[action]!;
    final phase = frame / animation.frames;
    final angle = (phase + descriptor.phase) * math.pi * 2;
    final mirrored = body.shouldMirror(direction);
    final x = descriptor.x + math.sin(angle) * descriptor.xWave;
    final y = descriptor.y + math.cos(angle) * descriptor.yWave;
    return Offset(mirrored ? -x : x, y);
  }

  CharacterAuditReport audit() {
    final issues = <CharacterAuditIssue>[];
    final bodyIds = <String>{};
    final layerIds = <String>{};
    for (final body in manifest.bodies) {
      if (!bodyIds.add(body.id)) {
        issues.add(CharacterAuditIssue('duplicate_body', body.id));
      }
      if (body.assetKey.isEmpty || body.actions.isEmpty) {
        issues.add(CharacterAuditIssue('incomplete_body', body.id));
      }
      for (final action in CharacterAction.values) {
        final animation = body.actions[action];
        if (animation == null || animation.frames < 2 || animation.fps <= 0) {
          issues.add(CharacterAuditIssue(
            'invalid_action',
            '${body.id}:${action.name}',
          ));
        }
        final impact = animation?.impactFrame;
        if (impact != null && impact >= animation!.frames) {
          issues.add(CharacterAuditIssue(
            'invalid_impact_frame',
            '${body.id}:${action.name}',
          ));
        }
      }
      for (final requiredSocket in const [
        'root',
        'ground',
        'mainHand',
        'offHand',
        'back',
        'title',
      ]) {
        if (!body.sockets.containsKey(requiredSocket)) {
          issues.add(CharacterAuditIssue(
            'missing_socket',
            '${body.id}:$requiredSocket',
          ));
        }
      }
    }
    for (final layer in manifest.layers) {
      if (!layerIds.add(layer.id)) {
        issues.add(CharacterAuditIssue('duplicate_layer', layer.id));
      }
      if (layer.assetKey.isEmpty ||
          !manifest.bodies.any((body) => body.rig == layer.rig)) {
        issues.add(CharacterAuditIssue('invalid_layer', layer.id));
      }
      if (layer.socket != null &&
          !manifest.bodies
              .where((body) => body.rig == layer.rig)
              .every((body) => body.sockets.containsKey(layer.socket))) {
        issues.add(CharacterAuditIssue('invalid_socket', layer.id));
      }
    }
    if (!_bodies.containsKey(manifest.defaultBody)) {
      issues.add(
          CharacterAuditIssue('invalid_default_body', manifest.defaultBody));
    }
    return CharacterAuditReport(issues);
  }
}

class CharacterAuditIssue {
  const CharacterAuditIssue(this.code, this.target);

  final String code;
  final String target;
}

class CharacterAuditReport {
  const CharacterAuditReport(this.issues);

  final List<CharacterAuditIssue> issues;
  bool get passed => issues.isEmpty;
}

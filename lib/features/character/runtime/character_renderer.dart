import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/character_appearance_store.dart';
import '../data/character_registry.dart';
import '../models/character_appearance.dart';
import '../models/character_manifest.dart';

class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({
    this.size = 88,
    this.action = CharacterAction.idle,
    this.direction = CharacterDirection.front,
    this.backgroundColor,
    super.key,
  });

  final double size;
  final CharacterAction action;
  final CharacterDirection direction;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: ColoredBox(
          color: backgroundColor ?? Colors.white.withValues(alpha: 0.16),
          child: CharacterStage(
            action: action,
            direction: direction,
            padding: const EdgeInsets.fromLTRB(5, 8, 5, 2),
          ),
        ),
      ),
    );
  }
}

class CharacterStage extends StatefulWidget {
  const CharacterStage({
    required this.action,
    required this.direction,
    this.appearance,
    this.registry,
    this.playing = true,
    this.manualFrame,
    this.showSockets = false,
    this.showGuides = false,
    this.hiddenSlots = const {},
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final CharacterAction action;
  final CharacterDirection direction;
  final CharacterAppearance? appearance;
  final CharacterRegistry? registry;
  final bool playing;
  final int? manualFrame;
  final bool showSockets;
  final bool showGuides;
  final Set<CharacterSlot> hiddenSlots;
  final EdgeInsets padding;

  @override
  State<CharacterStage> createState() => _CharacterStageState();
}

class _CharacterStageState extends State<CharacterStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;
  Future<CharacterRegistry>? _registryFuture;
  CharacterAction? _clockAction;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this);
    _registryFuture = widget.registry == null ? CharacterRegistry.load() : null;
  }

  @override
  void didUpdateWidget(CharacterStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registry != widget.registry) {
      _registryFuture =
          widget.registry == null ? CharacterRegistry.load() : null;
    }
  }

  void _syncClock(CharacterAnimationDescriptor animation) {
    final actionChanged = _clockAction != widget.action;
    _clockAction = widget.action;
    final changedDuration = _clock.duration != animation.duration;
    if (changedDuration) _clock.duration = animation.duration;
    if (!widget.playing || widget.manualFrame != null) {
      if (_clock.isAnimating) _clock.stop();
      return;
    }
    if (_clock.isAnimating && !changedDuration && !actionChanged) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.playing || widget.manualFrame != null) return;
      if (animation.loop) {
        _clock.repeat(min: 0, max: 1, period: animation.duration);
      } else {
        _clock.forward(from: 0).then((_) {
          if (mounted && _clockAction == widget.action && !animation.holdLast) {
            _clock.value = 0;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registry = widget.registry;
    if (registry != null) return _buildWithRegistry(registry);
    return FutureBuilder<CharacterRegistry>(
      future: _registryFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        return _buildWithRegistry(snapshot.data!);
      },
    );
  }

  Widget _buildWithRegistry(CharacterRegistry registry) {
    final explicitAppearance = widget.appearance;
    if (explicitAppearance != null) {
      return _buildPainter(registry, explicitAppearance);
    }
    return ValueListenableBuilder<CharacterAppearance?>(
      valueListenable: CharacterAppearanceController.instance,
      builder: (context, appearance, _) {
        return _buildPainter(
          registry,
          appearance ?? CharacterAppearance.defaults(registry.manifest),
        );
      },
    );
  }

  Widget _buildPainter(
    CharacterRegistry registry,
    CharacterAppearance appearance,
  ) {
    final body = registry.body(appearance.bodyId);
    final animation = body.actions[widget.action] ?? body.actions.values.first;
    _syncClock(animation);
    return Padding(
      padding: widget.padding,
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          final frame = widget.manualFrame?.clamp(0, animation.frames - 1) ??
              (_clock.value * animation.frames).floor().clamp(
                    0,
                    animation.frames - 1,
                  );
          return CustomPaint(
            painter: CharacterPainter(
              registry: registry,
              appearance: appearance,
              action: widget.action,
              direction: widget.direction,
              frame: frame,
              showSockets: widget.showSockets,
              showGuides: widget.showGuides,
              hiddenSlots: widget.hiddenSlots,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class CharacterPainter extends CustomPainter {
  CharacterPainter({
    required this.registry,
    required this.appearance,
    required this.action,
    required this.direction,
    required this.frame,
    required this.showSockets,
    required this.showGuides,
    required this.hiddenSlots,
  });

  final CharacterRegistry registry;
  final CharacterAppearance appearance;
  final CharacterAction action;
  final CharacterDirection direction;
  final int frame;
  final bool showSockets;
  final bool showGuides;
  final Set<CharacterSlot> hiddenSlots;

  @override
  void paint(Canvas canvas, Size size) {
    final body = registry.body(appearance.bodyId);
    final animation = body.actions[action]!;
    final phase = frame / animation.frames;
    final cycle = math.sin(phase * math.pi * 2);
    final bob = -cycle.abs() * animation.bob;
    final fit = math.min(size.width / 118, size.height / 146) * body.scale;
    final sourceDirection = body.mirrorDirections[direction] ?? direction;
    final mirrored = body.shouldMirror(direction);

    canvas.save();
    canvas.translate(size.width / 2, size.height - 4);
    canvas.scale(fit * (mirrored ? -1 : 1), fit);

    if (showGuides) _drawGuides(canvas, mirrored);
    _drawShadow(canvas, cycle);
    canvas.translate(0, bob);

    final sockets = <String, Offset>{
      for (final name in body.sockets.keys)
        name: registry.resolveSocket(
          body: body,
          socket: name,
          action: action,
          frame: frame,
          direction: sourceDirection,
        ),
    };
    final layers = registry
        .layersFor(appearance, action)
        .where((layer) => !hiddenSlots.contains(layer.slot))
        .toList(growable: false);
    final outfit = layers.where((layer) => layer.slot == CharacterSlot.outfit);
    final stride = cycle * animation.stride;

    _drawLegs(canvas, body, outfit.firstOrNull, stride);
    _drawTorso(canvas, body, outfit.firstOrNull, cycle * animation.sway);
    _drawArms(canvas, body, sockets, outfit.firstOrNull);
    _drawHead(canvas, body, sourceDirection);

    for (final layer
        in layers.where((item) => item.slot != CharacterSlot.outfit)) {
      _drawLayer(canvas, layer, sockets, phase, sourceDirection);
    }
    if (showSockets) _drawSockets(canvas, sockets);
    canvas.restore();
  }

  void _drawGuides(Canvas canvas, bool mirrored) {
    final guide = Paint()
      ..color = const Color(0x6650E3C2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(-55, 0), const Offset(55, 0), guide);
    canvas.drawLine(const Offset(0, 5), const Offset(0, -140), guide);
    canvas.drawCircle(Offset(mirrored ? -1 : 1, 0), 3, guide);
  }

  void _drawShadow(Canvas canvas, double cycle) {
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, -1),
        width: 52 - cycle.abs() * 3,
        height: 10,
      ),
      Paint()..color = const Color(0x330B1F16),
    );
  }

  void _drawLegs(
    Canvas canvas,
    CharacterBodyDescriptor body,
    CharacterLayerDescriptor? outfit,
    double stride,
  ) {
    final uniform = outfit?.color ?? const Color(0xFF475569);
    final boot = Paint()..color = const Color(0xFF2B3037);
    final leg = Paint()
      ..color = Color.lerp(uniform, Colors.black, 0.18)!
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-11, -43), Offset(-12 + stride, -10), leg);
    canvas.drawLine(const Offset(11, -43), Offset(12 - stride, -10), leg);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(-9 + stride, -5), width: 20, height: 9),
        const Radius.circular(4),
      ),
      boot,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(9 - stride, -5), width: 20, height: 9),
        const Radius.circular(4),
      ),
      boot,
    );
  }

  void _drawTorso(
    Canvas canvas,
    CharacterBodyDescriptor body,
    CharacterLayerDescriptor? outfit,
    double sway,
  ) {
    final color = outfit?.color ?? const Color(0xFF64748B);
    final accent = outfit?.accentColor ?? const Color(0xFFE2E8F0);
    canvas.save();
    canvas.rotate(sway * 0.006);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-25, -88, 50, 51),
        const Radius.circular(13),
      ),
      Paint()..color = color,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-22, -83, 44, 7),
        const Radius.circular(3),
      ),
      Paint()..color = accent.withValues(alpha: 0.9),
    );
    canvas.drawRect(
      const Rect.fromLTWH(-3, -76, 6, 37),
      Paint()..color = accent.withValues(alpha: 0.32),
    );
    canvas.restore();
  }

  void _drawArms(
    Canvas canvas,
    CharacterBodyDescriptor body,
    Map<String, Offset> sockets,
    CharacterLayerDescriptor? outfit,
  ) {
    final sleeve = Paint()
      ..color = outfit?.color ?? const Color(0xFF64748B)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final skin = Paint()
      ..color = body.skinColor
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final mainHand = sockets['mainHand']!;
    final offHand = sockets['offHand']!;
    canvas.drawLine(const Offset(20, -78), mainHand * 0.86, sleeve);
    canvas.drawLine(mainHand * 0.86, mainHand, skin);
    canvas.drawLine(const Offset(-20, -78), offHand * 0.86, sleeve);
    canvas.drawLine(offHand * 0.86, offHand, skin);
  }

  void _drawHead(
    Canvas canvas,
    CharacterBodyDescriptor body,
    CharacterDirection sourceDirection,
  ) {
    canvas.drawCircle(
        const Offset(0, -108), 21, Paint()..color = body.skinColor);
    final hair = Paint()..color = body.hairColor;
    canvas.drawArc(
      const Rect.fromLTWH(-21, -132, 42, 35),
      math.pi,
      math.pi,
      true,
      hair,
    );
    if (sourceDirection != CharacterDirection.back) {
      final eye = Paint()..color = const Color(0xFF211B18);
      final eyeShift = sourceDirection == CharacterDirection.right ? 4.0 : 0.0;
      canvas.drawCircle(Offset(-7 + eyeShift, -109), 1.8, eye);
      canvas.drawCircle(Offset(7 + eyeShift, -109), 1.8, eye);
      canvas.drawArc(
        Rect.fromCenter(center: Offset(eyeShift, -100), width: 12, height: 7),
        0,
        math.pi,
        false,
        Paint()
          ..color = const Color(0xFF7F3E32)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _drawLayer(
    Canvas canvas,
    CharacterLayerDescriptor layer,
    Map<String, Offset> sockets,
    double phase,
    CharacterDirection direction,
  ) {
    switch (layer.visual) {
      case 'helmet':
        canvas.drawArc(
          const Rect.fromLTWH(-24, -135, 48, 28),
          math.pi,
          math.pi,
          true,
          Paint()..color = layer.color,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-28, -116, 56, 6),
            const Radius.circular(3),
          ),
          Paint()..color = layer.accentColor,
        );
        break;
      case 'cap':
        canvas.drawArc(
          const Rect.fromLTWH(-23, -132, 46, 27),
          math.pi,
          math.pi,
          true,
          Paint()..color = layer.color,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, -116, 28, 6),
            const Radius.circular(3),
          ),
          Paint()..color = layer.accentColor,
        );
        break;
      case 'scanner':
        final socket = sockets[layer.socket]!;
        canvas.save();
        canvas.translate(socket.dx, socket.dy);
        canvas.rotate(-0.2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-5, -12, 13, 20),
            const Radius.circular(3),
          ),
          Paint()..color = layer.color,
        );
        canvas.drawRect(
          const Rect.fromLTWH(-3, -9, 9, 5),
          Paint()..color = layer.accentColor,
        );
        canvas.restore();
        break;
      case 'clipboard':
        final socket = sockets[layer.socket]!;
        canvas.save();
        canvas.translate(socket.dx, socket.dy);
        canvas.rotate(0.12);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-13, -16, 24, 31),
            const Radius.circular(3),
          ),
          Paint()..color = layer.color,
        );
        canvas.drawRect(
          const Rect.fromLTWH(-10, -12, 18, 23),
          Paint()..color = layer.accentColor,
        );
        canvas.restore();
        break;
      case 'sparkle':
        final socket = sockets[layer.socket]!;
        for (var index = 0; index < 5; index++) {
          final angle = phase * math.pi * 2 + index * math.pi * 0.4;
          final center =
              socket + Offset(math.cos(angle) * 28, math.sin(angle) * 12);
          _drawStar(canvas, center, 4.0 + index.isEven.toInt(), layer.color);
        }
        break;
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    for (var index = 0; index < 8; index++) {
      final angle = -math.pi / 2 + index * math.pi / 4;
      final currentRadius = index.isEven ? radius : radius * 0.35;
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * currentRadius;
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawSockets(Canvas canvas, Map<String, Offset> sockets) {
    final paint = Paint()..color = const Color(0xFFFF3B6A);
    final label = TextPainter(textDirection: TextDirection.ltr);
    for (final entry in sockets.entries) {
      canvas.drawCircle(entry.value, 2.6, paint);
      label.text = TextSpan(
        text: entry.key,
        style: const TextStyle(color: Color(0xFFFF3B6A), fontSize: 5),
      );
      label.layout();
      label.paint(canvas, entry.value + const Offset(4, -3));
    }
  }

  @override
  bool shouldRepaint(CharacterPainter oldDelegate) {
    return oldDelegate.appearance != appearance ||
        oldDelegate.action != action ||
        oldDelegate.direction != direction ||
        oldDelegate.frame != frame ||
        oldDelegate.showSockets != showSockets ||
        oldDelegate.showGuides != showGuides ||
        oldDelegate.hiddenSlots != hiddenSlots;
  }
}

extension on bool {
  int toInt() => this ? 1 : 0;
}

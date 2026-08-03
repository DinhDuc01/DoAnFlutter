import 'package:flutter/material.dart';

import '../../data/character_appearance_store.dart';
import '../../data/character_registry.dart';
import '../../models/character_appearance.dart';
import '../../models/character_manifest.dart';
import '../../runtime/character_renderer.dart';

class CharacterLabScreen extends StatefulWidget {
  const CharacterLabScreen({super.key});

  @override
  State<CharacterLabScreen> createState() => _CharacterLabScreenState();
}

class _CharacterLabScreenState extends State<CharacterLabScreen> {
  late final Future<CharacterRegistry> _future = CharacterRegistry.load();
  CharacterAction _action = CharacterAction.walk;
  CharacterDirection _direction = CharacterDirection.front;
  bool _playing = true;
  bool _showSockets = true;
  bool _showGuides = true;
  int _frame = 0;
  final Set<CharacterSlot> _hiddenSlots = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF4F0),
      appBar: AppBar(title: const Text('Character Development Lab')),
      body: FutureBuilder<CharacterRegistry>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final registry = snapshot.data!;
          final appearance = CharacterAppearanceController.instance.value ??
              CharacterAppearance.defaults(registry.manifest);
          final animation = registry.body(appearance.bodyId).actions[_action]!;
          final report = registry.audit();
          final frame = _frame.clamp(0, animation.frames - 1);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                height: 360,
                decoration: BoxDecoration(
                  color: const Color(0xFF10251D),
                  borderRadius: BorderRadius.circular(24),
                  backgroundBlendMode: BlendMode.srcOver,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF244D3D), Color(0xFF10251D)],
                  ),
                ),
                child: CharacterStage(
                  registry: registry,
                  appearance: appearance,
                  action: _action,
                  direction: _direction,
                  playing: _playing,
                  manualFrame: _playing ? null : frame,
                  showSockets: _showSockets,
                  showGuides: _showGuides,
                  hiddenSlots: _hiddenSlots,
                  padding: const EdgeInsets.fromLTRB(70, 38, 70, 12),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _AuditBadge(report: report),
                  const Spacer(),
                  Text(
                    '${_action.name} · ${_direction.name} · frame $frame/${animation.frames - 1}',
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CharacterAction.values.map((action) {
                  return ChoiceChip(
                    selected: action == _action,
                    label: Text(action.name),
                    onSelected: (_) => setState(() {
                      _action = action;
                      _frame = 0;
                    }),
                  );
                }).toList(growable: false),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: CharacterDirection.values.map((direction) {
                  return ChoiceChip(
                    selected: direction == _direction,
                    label: Text(direction.name),
                    onSelected: (_) => setState(() => _direction = direction),
                  );
                }).toList(growable: false),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => setState(() => _playing = !_playing),
                    icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                  ),
                  Expanded(
                    child: Slider(
                      value: frame.toDouble(),
                      max: (animation.frames - 1).toDouble(),
                      divisions: animation.frames - 1,
                      label: '$frame',
                      onChanged: (value) => setState(() {
                        _playing = false;
                        _frame = value.round();
                      }),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                value: _showSockets,
                title: const Text('Hiển thị socket'),
                onChanged: (value) => setState(() => _showSockets = value),
              ),
              SwitchListTile(
                value: _showGuides,
                title: const Text('Hiển thị root và ground'),
                onChanged: (value) => setState(() => _showGuides = value),
              ),
              const Divider(),
              const Text(
                'Visual layers',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              ...CharacterSlot.values.map((slot) {
                return CheckboxListTile(
                  value: !_hiddenSlots.contains(slot),
                  title: Text(slot.name),
                  onChanged: (value) => setState(() {
                    if (value ?? false) {
                      _hiddenSlots.remove(slot);
                    } else {
                      _hiddenSlots.add(slot);
                    }
                  }),
                );
              }),
              if (!report.passed) ...[
                const Divider(),
                ...report.issues.map(
                  (issue) => Text('FAIL ${issue.code}: ${issue.target}'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AuditBadge extends StatelessWidget {
  const _AuditBadge({required this.report});

  final CharacterAuditReport report;

  @override
  Widget build(BuildContext context) {
    final passed = report.passed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: passed ? const Color(0xFFDDFBE7) : const Color(0xFFFFE4E6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        passed ? 'AUDIT PASS' : 'AUDIT FAIL (${report.issues.length})',
        style: TextStyle(
          color: passed ? const Color(0xFF08783D) : const Color(0xFFBE123C),
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}
